"""The moderation endpoints added for the panel (T31): one contribution with photo links,
edits before deciding, resolving and dismissing reports. Also the `make-admin` command."""

import uuid
from collections.abc import Callable
from datetime import UTC, datetime

import httpx
import pytest

from app.admin import cli
from app.core.config import Settings
from app.core.storage import Storage
from app.modules.auth.models import User, UserRole
from app.modules.contributions.models import (
    Contribution,
    ContributionStatus,
    ErrorReport,
    ReportReason,
    ReportStatus,
)
from tests.factories import ProductFactory
from tests.integration.admin.conftest import (
    JPEG,
    PASSWORD,
    Sessions,
    account,
    contribution_with_photos,
    reload,
)


async def bearer(client: httpx.AsyncClient, email: str) -> dict[str, str]:
    response = await client.post("/v1/auth/login", json={"email": email, "password": PASSWORD})
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


@pytest.fixture
async def moderator(client: httpx.AsyncClient, admin: User) -> dict[str, str]:
    return await bearer(client, admin.email)


@pytest.fixture
async def contributor(client: httpx.AsyncClient, sessions: Sessions) -> dict[str, str]:
    await account(sessions, "contributor@example.tn")
    return await bearer(client, "contributor@example.tn")


@pytest.fixture
async def pending(sessions: Sessions, storage: Storage) -> Contribution:
    user = await account(sessions, "someone@example.tn")
    return await contribution_with_photos(sessions, storage, user.id)


async def report(sessions: Sessions, status: ReportStatus = ReportStatus.OPEN) -> ErrorReport:
    async with sessions() as session:
        product = await ProductFactory.create(session)
        created = ErrorReport(
            client_id=uuid.uuid4().hex,
            ean=product.ean,
            product_id=product.id,
            reasons=[ReportReason.GRADE.value],
            product_updated_at=datetime.now(UTC),
            reported_at=datetime.now(UTC),
            status=status,
        )
        session.add(created)
        await session.commit()
        return created


# ---------------------------------------------------------------- access


@pytest.mark.parametrize(
    ("method", "path"),
    [
        ("GET", "/v1/admin/contributions/{id}"),
        ("PATCH", "/v1/admin/contributions/{id}"),
        ("POST", "/v1/admin/reports/{id}/resolve"),
        ("POST", "/v1/admin/reports/{id}/dismiss"),
    ],
)
async def test_moderators_only(
    client: httpx.AsyncClient, contributor: dict[str, str], method: str, path: str
) -> None:
    url = path.format(id=uuid.uuid4())
    body = {"name": "x"} if method == "PATCH" else None
    assert (await client.request(method, url, json=body)).status_code == 401
    refused = await client.request(method, url, json=body, headers=contributor)
    assert refused.status_code == 403


# ---------------------------------------------------------------- one contribution


async def test_contribution_with_photo_links(
    client: httpx.AsyncClient, moderator: dict[str, str], pending: Contribution
) -> None:
    response = await client.get(f"/v1/admin/contributions/{pending.id}", headers=moderator)

    assert response.status_code == 200
    body = response.json()
    assert body["photos"] == pending.photos
    assert set(body["photo_urls"]) == {"front", "nutrition"}
    assert (body["submitted_values"], body["photos_deleted_at"]) == (None, None)
    async with httpx.AsyncClient() as browser:
        photo = await browser.get(body["photo_urls"]["front"])
    assert photo.content == JPEG


async def test_no_photo_links_once_deleted(
    client: httpx.AsyncClient, moderator: dict[str, str], sessions: Sessions, storage: Storage
) -> None:
    cleaned = await contribution_with_photos(
        sessions,
        storage,
        None,
        status=ContributionStatus.REJECTED,
        photos_deleted_at=datetime.now(UTC),
    )
    response = await client.get(f"/v1/admin/contributions/{cleaned.id}", headers=moderator)
    assert response.json()["photo_urls"] == {}


async def test_unknown_contribution(client: httpx.AsyncClient, moderator: dict[str, str]) -> None:
    url = f"/v1/admin/contributions/{uuid.uuid4()}"
    assert (await client.get(url, headers=moderator)).status_code == 404
    assert (await client.patch(url, json={"name": "x"}, headers=moderator)).status_code == 404


# ---------------------------------------------------------------- edits


async def test_edit_changes_only_what_is_sent(
    client: httpx.AsyncClient, moderator: dict[str, str], sessions: Sessions, pending: Contribution
) -> None:
    response = await client.patch(
        f"/v1/admin/contributions/{pending.id}",
        json={"brand": "  ", "nutrition": {"energy_kj": 420, "sugars_g": 4.5}},
        headers=moderator,
    )

    assert response.status_code == 200
    body = response.json()
    assert (body["name"], body["brand"]) == ("Harissa", None)
    assert body["nutrition"] == {"energy_kj": "420.0", "sugars_g": "4.5"}
    assert body["submitted_values"]["brand"] == "Cap Bon"
    assert body["submitted_values"]["nutrition"] == pending.nutrition
    saved = await reload(sessions, Contribution, pending.id)
    assert saved.status == ContributionStatus.PENDING


@pytest.mark.parametrize(
    "body",
    [{}, {"category": None}, {"nutrition": None}, {"basis": None}, {"ean": "123"}],
    ids=["empty", "no-category", "no-nutrition", "no-basis", "not-editable"],
)
async def test_invalid_edits(
    client: httpx.AsyncClient,
    moderator: dict[str, str],
    pending: Contribution,
    body: dict[str, object],
) -> None:
    response = await client.patch(
        f"/v1/admin/contributions/{pending.id}", json=body, headers=moderator
    )
    assert response.status_code == 422


async def test_decided_contributions_are_not_edited(
    client: httpx.AsyncClient, moderator: dict[str, str], pending: Contribution
) -> None:
    url = f"/v1/admin/contributions/{pending.id}"
    assert (await client.post(f"{url}/reject", json={}, headers=moderator)).status_code == 200
    response = await client.patch(url, json={"name": "Late"}, headers=moderator)
    assert response.status_code == 409


# ---------------------------------------------------------------- reports


@pytest.mark.parametrize(
    ("decision", "status"),
    [("resolve", ReportStatus.RESOLVED), ("dismiss", ReportStatus.DISMISSED)],
)
async def test_report_decisions(
    client: httpx.AsyncClient,
    moderator: dict[str, str],
    *,
    sessions: Sessions,
    admin: User,
    decision: str,
    status: ReportStatus,
) -> None:
    item = await report(sessions)
    url = f"/v1/admin/reports/{item.id}/{decision}"

    response = await client.post(url, headers=moderator)

    assert response.status_code == 200
    body = response.json()
    assert (body["status"], body["resolved_by"]) == (status.value, str(admin.id))
    assert body["resolved_at"] is not None
    assert (await client.post(url, headers=moderator)).status_code == 409
    listed = await client.get(
        "/v1/admin/reports", params={"status": status.value}, headers=moderator
    )
    assert [r["id"] for r in listed.json()["items"]] == [str(item.id)]


async def test_unknown_report(client: httpx.AsyncClient, moderator: dict[str, str]) -> None:
    url = f"/v1/admin/reports/{uuid.uuid4()}/resolve"
    assert (await client.post(url, headers=moderator)).status_code == 404


# ---------------------------------------------------------------- make-admin


async def test_make_admin(
    make_settings: Callable[..., Settings], sessions: Sessions, capsys: pytest.CaptureFixture[str]
) -> None:
    user = await account(sessions, "first@example.tn", is_active=False)
    settings = make_settings()

    assert await cli.amain(["make-admin", " First@Example.tn "], settings=settings) == 0

    saved = await reload(sessions, User, user.id)
    assert (saved.role, saved.is_active) == (UserRole.ADMIN, True)
    assert "first@example.tn is now a moderator" in capsys.readouterr().out


async def test_make_admin_needs_an_account(
    make_settings: Callable[..., Settings], sessions: Sessions, capsys: pytest.CaptureFixture[str]
) -> None:
    settings = make_settings()
    assert await cli.amain(["make-admin", "nobody@example.tn"], settings=settings) == 1
    assert "no account" in capsys.readouterr().err
