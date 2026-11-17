"""Daily cleanup of what contributions leave behind (worker job `clean_up`).

Three steps, each on its own (a failing one doesn't stop the others):

1. LLM fallback requests (`label_fallbacks`, they hold the label's OCR text) are deleted
   some days after they were asked for, whatever their status. Needs no storage, so it
   runs first.
2. Photos of rejected contributions are deleted from the private bucket some days after
   the rejection. The contribution keeps its keys as history and gets `photos_deleted_at`;
   one whose photos couldn't all be deleted is tried again on the next run.
3. Uploads never submitted: objects under `contributions/` older than a few days that no
   contribution refers to (the app was closed for good before submitting, a photo was
   retaken, the outbox entry was refused or deleted, the account was deleted before
   submitting). Contributions are found by the id in the key, then their `photos` are
   checked, so a key is kept only if a contribution really uses it.

Ages are compared with `now` (injectable: tests make fresh objects look old). Something
exactly as old as the limit is kept until the next run.
"""

import logging
import uuid
from collections.abc import Callable, Iterable
from dataclasses import asdict, dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import delete, func, select, tuple_, update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.config import Settings
from app.core.storage import Bucket, ListedObject, StorageError
from app.modules.contributions.models import Contribution, ContributionStatus, LabelFallback
from app.modules.contributions.uploads import KEY_PREFIX

logger = logging.getLogger(__name__)

REJECTED_BATCH_SIZE = 100


@dataclass(frozen=True)
class CleanupSettings:
    unsubmitted_upload_days: int
    rejected_photo_days: int
    label_fallback_days: int

    @classmethod
    def from_settings(cls, settings: Settings) -> "CleanupSettings":
        return cls(
            unsubmitted_upload_days=settings.unsubmitted_upload_retention_days,
            rejected_photo_days=settings.rejected_photo_retention_days,
            label_fallback_days=settings.label_fallback_retention_days,
        )


@dataclass
class CleanupStats:
    label_fallbacks_deleted: int = 0
    rejected_contributions_cleared: int = 0
    """Rejected contributions whose photos are now all deleted."""
    rejected_photos_deleted: int = 0
    uploads_deleted: int = 0
    """Uploads no contribution refers to."""
    failed: int = 0
    """Deletes that failed, plus steps that stopped on an error: tried again next run."""


def cutoff(now: datetime, days: int) -> datetime:
    return now - timedelta(days=days)


def is_old_enough(moment: datetime, limit: datetime) -> bool:
    """Strictly before the cutoff."""
    return moment < limit


def contribution_id_of(key: str) -> uuid.UUID | None:
    """The contribution id in an upload key (`contributions/{user}/{contribution}/{file}`),
    or None when the key doesn't have that shape."""
    parts = key.split("/")
    if len(parts) != 4 or parts[0] != KEY_PREFIX:  # prefix, user, contribution, file
        return None
    try:
        return uuid.UUID(parts[2])
    except ValueError:
        return None


class Cleanup:
    def __init__(
        self,
        sessions: async_sessionmaker[AsyncSession],
        uploads: Bucket,
        settings: CleanupSettings,
        *,
        now: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self._sessions = sessions
        self._uploads = uploads
        self._settings = settings
        self._now = now

    async def run(self) -> CleanupStats:
        stats = CleanupStats()
        now = self._now()
        for step in (self._label_fallbacks, self._rejected_photos, self._unsubmitted_uploads):
            try:
                await step(now, stats)
            except StorageError:
                logger.warning("cleanup step stopped", extra={"step": step.__name__}, exc_info=True)
                stats.failed += 1
        logger.info("cleanup done", extra=asdict(stats))
        return stats

    # ------------------------------------------------------------ steps

    async def _label_fallbacks(self, now: datetime, stats: CleanupStats) -> None:
        limit = cutoff(now, self._settings.label_fallback_days)
        async with self._sessions() as session:
            deleted = await session.execute(
                delete(LabelFallback)
                .where(LabelFallback.created_at < limit)
                .returning(LabelFallback.id)
            )
            stats.label_fallbacks_deleted = len(deleted.all())
            await session.commit()

    async def _rejected_photos(self, now: datetime, stats: CleanupStats) -> None:
        limit = cutoff(now, self._settings.rejected_photo_days)
        after: tuple[datetime, uuid.UUID] | None = None
        while batch := await self._rejected_batch(limit, after):
            for contribution_id, reviewed_at, photos in batch:
                after = (reviewed_at, contribution_id)
                if await self._delete_all(photos.values(), stats):
                    stats.rejected_photos_deleted += len(photos)
                    await self._mark_photos_deleted(contribution_id)
                    stats.rejected_contributions_cleared += 1

    async def _unsubmitted_uploads(self, now: datetime, stats: CleanupStats) -> None:
        limit = cutoff(now, self._settings.unsubmitted_upload_days)
        async for page in self._uploads.pages(f"{KEY_PREFIX}/"):
            old = [item for item in page if is_old_enough(item.last_modified, limit)]
            if not old:
                continue
            used = await self._used_keys(old)
            for item in old:
                if item.key not in used and await self._delete(item.key, stats):
                    stats.uploads_deleted += 1

    # ------------------------------------------------------------ helpers

    async def _rejected_batch(
        self, limit: datetime, after: tuple[datetime, uuid.UUID] | None
    ) -> list[tuple[uuid.UUID, datetime, dict[str, str]]]:
        """Rejected before `limit`, photos not deleted yet; keyset on (reviewed_at, id), so
        one whose deletes failed isn't picked again in the same run."""
        query = (
            select(Contribution.id, Contribution.reviewed_at, Contribution.photos)
            .where(
                Contribution.status == ContributionStatus.REJECTED,
                Contribution.reviewed_at < limit,
                Contribution.photos_deleted_at.is_(None),
            )
            .order_by(Contribution.reviewed_at, Contribution.id)
            .limit(REJECTED_BATCH_SIZE)
        )
        if after is not None:
            query = query.where(tuple_(Contribution.reviewed_at, Contribution.id) > after)
        async with self._sessions() as session:
            rows = (await session.execute(query)).all()
        # reviewed_at is set with the rejection (the query excludes NULL).
        return [(row.id, row.reviewed_at, row.photos) for row in rows]

    async def _mark_photos_deleted(self, contribution_id: uuid.UUID) -> None:
        async with self._sessions() as session:
            await session.execute(
                update(Contribution)
                .where(Contribution.id == contribution_id)
                .values(photos_deleted_at=func.clock_timestamp())
            )
            await session.commit()

    async def _used_keys(self, objects: list[ListedObject]) -> set[str]:
        """Every key used by the contributions these objects belong to (by the id in their
        key)."""
        ids = {i for item in objects if (i := contribution_id_of(item.key)) is not None}
        async with self._sessions() as session:
            photos = (
                await session.scalars(
                    select(Contribution.photos).where(Contribution.client_id.in_(ids))
                )
            ).all()
        return {key for keys in photos for key in keys.values()}

    async def _delete_all(self, keys: Iterable[str], stats: CleanupStats) -> bool:
        """Try every key; True if all were deleted (a missing one counts as deleted)."""
        results = [await self._delete(key, stats) for key in keys]
        return all(results)

    async def _delete(self, key: str, stats: CleanupStats) -> bool:
        try:
            await self._uploads.delete(key)
        except StorageError:
            logger.warning("photo not deleted", extra={"key": key}, exc_info=True)
            stats.failed += 1
            return False
        return True
