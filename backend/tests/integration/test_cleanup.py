"""The daily cleanup (T30b) against real Postgres and RustFS (test buckets): old LLM fallback
requests, photos of old rejections, uploads never submitted. Also the worker job, its lock
and the CLI.

Storage sets `LastModified` itself, so objects are always fresh here: the cleanup's clock
is moved forward instead (`now=`) to make them old."""

import json
import secrets
import uuid
from collections.abc import AsyncIterator, Callable
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.core.config import Settings
from app.core.storage import Bucket, Storage, StorageError, open_storage
from app.modules.contributions.cleanup import Cleanup, CleanupSettings, CleanupStats
from app.modules.contributions.models import (
    Contribution,
    ContributionStatus,
    FallbackReason,
    FallbackStatus,
    LabelFallback,
)
from app.modules.contributions.schemas import PhotoContentType, PhotoKind
from app.modules.contributions.uploads import upload_key
from app.worker import cli, jobs
from tests.factories import ContributionFactory, LabelFallbackFactory, UserFactory

Sessions = async_sessionmaker[AsyncSession]
RETENTION = CleanupSettings(
    unsubmitted_upload_days=7, rejected_photo_days=30, label_fallback_days=7
)


def days_from_now(days: float) -> datetime:
    return datetime.now(UTC) + timedelta(days=days)


@pytest.fixture
async def sessions(db_engine: AsyncEngine) -> AsyncIterator[Sessions]:
    async def clear() -> None:
        async with db_engine.begin() as connection:
            await connection.execute(text("TRUNCATE users, contributions CASCADE"))

    await clear()
    yield async_sessionmaker(db_engine, expire_on_commit=False)
    await clear()


@pytest.fixture
async def user_id(sessions: Sessions) -> uuid.UUID:
    async with sessions() as session:
        user = await UserFactory.create(session)
        await session.commit()
        return user.id


def cleanup(
    sessions: Sessions,
    storage: Storage,
    *,
    now: datetime | None = None,
    bucket: Bucket | None = None,
) -> Cleanup:
    moment = now or datetime.now(UTC)
    return Cleanup(sessions, bucket or storage.uploads, RETENTION, now=lambda: moment)


async def upload(
    storage: Storage, user_id: uuid.UUID, client_id: uuid.UUID, kind: PhotoKind = PhotoKind.FRONT
) -> str:
    key = upload_key(user_id, client_id, kind, PhotoContentType.JPEG, secrets.token_hex(8))
    await storage.uploads.put(key, b"\xff\xd8\xff photo", content_type="image/jpeg")
    return key


async def stored_keys(storage: Storage) -> set[str]:
    return {item.key async for page in storage.uploads.pages("") for item in page}


async def contribute(sessions: Sessions, user_id: uuid.UUID | None, **values: Any) -> Contribution:
    async with sessions() as session:
        contribution = await ContributionFactory.create(session, user_id=user_id, **values)
        await session.commit()
        return contribution


async def reload(sessions: Sessions, contribution_id: uuid.UUID) -> Contribution:
    async with sessions() as session:
        contribution = await session.get(Contribution, contribution_id)
        assert contribution is not None
        return contribution


async def rejected_with_photos(
    sessions: Sessions, storage: Storage, user_id: uuid.UUID, *, rejected_days_ago: float
) -> tuple[Contribution, set[str]]:
    client_id = uuid.uuid4()
    photos = {
        "front": await upload(storage, user_id, client_id),
        "nutrition": await upload(storage, user_id, client_id, PhotoKind.NUTRITION),
    }
    contribution = await contribute(
        sessions,
        user_id,
        client_id=client_id,
        photos=photos,
        status=ContributionStatus.REJECTED,
        reviewed_at=days_from_now(-rejected_days_ago),
    )
    return contribution, set(photos.values())


# ---------------------------------------------------------------- LLM fallback requests


async def test_old_fallback_requests_are_deleted_whatever_their_status(
    sessions: Sessions, storage: Storage, user_id: uuid.UUID
) -> None:
    old = days_from_now(-7.01)
    async with sessions() as session:
        for values in (
            {},
            {"status": FallbackStatus.DONE, "result": {"values": {}}, "completed_at": old},
            {
                "status": FallbackStatus.NEEDS_MANUAL_ENTRY,
                "reason": FallbackReason.TIMEOUT,
                "completed_at": old,
            },
        ):
            await LabelFallbackFactory.create(session, user_id=user_id, created_at=old, **values)
        recent = await LabelFallbackFactory.create(
            session, user_id=user_id, created_at=days_from_now(-6.9)
        )
        await session.commit()

    stats = await cleanup(sessions, storage).run()

    assert stats == CleanupStats(label_fallbacks_deleted=3)
    async with sessions() as session:
        assert (await session.scalars(select(LabelFallback.id))).all() == [recent.id]


# ---------------------------------------------------------------- rejected contributions


async def test_photos_of_old_rejections_are_deleted(
    sessions: Sessions, storage: Storage, user_id: uuid.UUID
) -> None:
    old, old_keys = await rejected_with_photos(sessions, storage, user_id, rejected_days_ago=31)
    recent, recent_keys = await rejected_with_photos(
        sessions, storage, user_id, rejected_days_ago=29
    )
    pending_client = uuid.uuid4()
    pending_key = await upload(storage, user_id, pending_client)
    await contribute(sessions, user_id, client_id=pending_client, photos={"front": pending_key})
    approved_client = uuid.uuid4()
    approved_key = await upload(storage, user_id, approved_client)
    await contribute(
        sessions,
        user_id,
        client_id=approved_client,
        photos={"front": approved_key},
        status=ContributionStatus.APPROVED,
        reviewed_at=days_from_now(-100),
    )
    # Photos already gone from storage count as deleted.
    gone = await contribute(
        sessions,
        user_id,
        photos={"front": f"contributions/{user_id}/{uuid.uuid4()}/front-0123456789abcdef.jpg"},
        status=ContributionStatus.REJECTED,
        reviewed_at=days_from_now(-40),
    )

    stats = await cleanup(sessions, storage).run()

    assert stats == CleanupStats(rejected_contributions_cleared=2, rejected_photos_deleted=3)
    assert await stored_keys(storage) == recent_keys | {pending_key, approved_key}
    cleared = await reload(sessions, old.id)
    assert cleared.photos_deleted_at is not None
    assert set(cleared.photos.values()) == old_keys  # kept as history
    assert (await reload(sessions, gone.id)).photos_deleted_at is not None
    assert (await reload(sessions, recent.id)).photos_deleted_at is None

    assert await cleanup(sessions, storage).run() == CleanupStats()  # nothing left to do


async def test_a_failed_delete_is_tried_again_on_the_next_run(
    sessions: Sessions, storage: Storage, user_id: uuid.UUID, monkeypatch: pytest.MonkeyPatch
) -> None:
    contribution, keys = await rejected_with_photos(
        sessions, storage, user_id, rejected_days_ago=31
    )
    stuck = sorted(keys)[0]
    real_delete = Bucket.delete

    async def failing_delete(bucket: Bucket, key: str) -> None:
        if key == stuck:
            raise StorageError("storage hiccup")
        await real_delete(bucket, key)

    monkeypatch.setattr(Bucket, "delete", failing_delete)
    stats = await cleanup(sessions, storage).run()

    assert stats == CleanupStats(failed=1)
    assert await stored_keys(storage) == {stuck}
    assert (await reload(sessions, contribution.id)).photos_deleted_at is None

    monkeypatch.setattr(Bucket, "delete", real_delete)
    stats = await cleanup(sessions, storage).run()

    assert stats == CleanupStats(rejected_contributions_cleared=1, rejected_photos_deleted=2)
    assert await stored_keys(storage) == set()


# ---------------------------------------------------------------- uploads never submitted


async def test_uploads_no_contribution_refers_to_are_deleted_once_old(
    sessions: Sessions, storage: Storage, user_id: uuid.UUID
) -> None:
    submitted_client = uuid.uuid4()
    front = await upload(storage, user_id, submitted_client)
    nutrition = await upload(storage, user_id, submitted_client, PhotoKind.NUTRITION)
    await contribute(
        sessions,
        user_id,
        client_id=submitted_client,
        photos={"front": front, "nutrition": nutrition},
    )
    retaken = await upload(storage, user_id, submitted_client)  # replaced before submitting
    never_submitted = await upload(storage, user_id, uuid.uuid4())
    # The contributor's account was deleted after submitting: the photos are still used.
    gone_user = uuid.uuid4()
    orphan_client = uuid.uuid4()
    orphan = await upload(storage, gone_user, orphan_client)
    await contribute(sessions, None, client_id=orphan_client, photos={"front": orphan})
    stray = "contributions/stray.jpg"
    await storage.uploads.put(stray, b"x", content_type="image/jpeg")
    elsewhere = "imports/not-a-contribution.jpg"
    await storage.uploads.put(elsewhere, b"x", content_type="image/jpeg")
    everything = await stored_keys(storage)

    assert await cleanup(sessions, storage, now=days_from_now(6.9)).run() == CleanupStats()
    assert await stored_keys(storage) == everything

    stats = await cleanup(sessions, storage, now=days_from_now(7.1)).run()

    assert stats == CleanupStats(uploads_deleted=3)
    assert await stored_keys(storage) == {front, nutrition, orphan, elsewhere}
    assert {retaken, never_submitted, stray}.isdisjoint(await stored_keys(storage))


async def test_storage_down_still_deletes_old_fallback_requests(
    sessions: Sessions,
    storage: Storage,
    user_id: uuid.UUID,
    make_settings: Callable[..., Settings],
) -> None:
    await rejected_with_photos(sessions, storage, user_id, rejected_days_ago=31)
    async with sessions() as session:
        await LabelFallbackFactory.create(session, user_id=user_id, created_at=days_from_now(-8))
        await session.commit()

    async with open_storage(make_settings(s3_endpoint_url="http://127.0.0.1:9")) as down:
        stats = await cleanup(sessions, storage, bucket=down.uploads).run()

    # Two photos not deleted, then listing the uploads failed.
    assert stats == CleanupStats(label_fallbacks_deleted=1, failed=3)
    assert len(await stored_keys(storage)) == 2


# ---------------------------------------------------------------- worker job and CLI


@pytest.fixture
async def ctx(make_settings: Callable[..., Settings]) -> AsyncIterator[jobs.Context]:
    context: jobs.Context = {"settings": make_settings()}
    await jobs.startup(context)
    yield context
    await jobs.shutdown(context)


async def test_cleanup_job(
    ctx: jobs.Context, sessions: Sessions, storage: Storage, user_id: uuid.UUID
) -> None:
    await rejected_with_photos(sessions, storage, user_id, rejected_days_ago=31)

    assert await jobs.clean_up(ctx) == {
        "label_fallbacks_deleted": 0,
        "rejected_contributions_cleared": 1,
        "rejected_photos_deleted": 2,
        "uploads_deleted": 0,
        "failed": 0,
    }


async def test_cleanup_job_is_skipped_while_another_runs(
    ctx: jobs.Context, sessions: Sessions, storage: Storage, db_engine: AsyncEngine
) -> None:
    async with db_engine.connect() as connection:
        key = {"k": jobs.CLEANUP_LOCK_KEY}
        await connection.execute(text("SELECT pg_advisory_lock(:k)"), key)
        try:
            assert await jobs.clean_up(ctx) is None
        finally:
            await connection.execute(text("SELECT pg_advisory_unlock(:k)"), key)


async def test_cli_runs_the_cleanup_now(
    make_settings: Callable[..., Settings],
    sessions: Sessions,
    storage: Storage,
    capsys: pytest.CaptureFixture[str],
) -> None:
    assert await cli.amain(["run", "cleanup"], settings=make_settings()) == 0
    assert json.loads(capsys.readouterr().out.splitlines()[-1]) == {
        "label_fallbacks_deleted": 0,
        "rejected_contributions_cleared": 0,
        "rejected_photos_deleted": 0,
        "uploads_deleted": 0,
        "failed": 0,
    }
