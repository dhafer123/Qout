"""The panel's moderation pages: the queue, the review page (photos next to the fields,
edit, preview, approve, reject) and the error reports (resolve, dismiss)."""

import re
import uuid
from datetime import UTC, datetime
from typing import Any

import httpx
import pytest
from sqlalchemy import select

from app.core.storage import Bucket, Storage, StorageError
from app.modules.auth.models import User
from app.modules.contributions.models import (
    Contribution,
    ContributionStatus,
    ErrorReport,
    ReportReason,
    ReportStatus,
)
from app.modules.products.models import NutritionFacts, Product, ProductStatus
from app.modules.scoring import Grade
from tests.factories import ProductFactory, ScoreFactory
from tests.integration.admin.conftest import (
    JPEG,
    Sessions,
    account,
    contribution_with_photos,
    reload,
)

FORM = {
    "name": "Harissa forte",
    "brand": "Cap Bon",
    "category": "general",
    "basis": "per_100g",
    "energy_kj": "400",
    "total_fat_g": "2",
    "saturated_fat_g": "0,5",
    "sugars_g": "4",
    "fibre_g": "3",
    "protein_g": "3",
    "salt_g": "3",
    "fvl_percent": "60",
    "non_nutritive_sweeteners": "",
    "note": "",
}


@pytest.fixture
async def contributor(sessions: Sessions) -> User:
    return await account(sessions, "contributor@example.tn")


@pytest.fixture
async def pending(sessions: Sessions, storage: Storage, contributor: User) -> Contribution:
    return await contribution_with_photos(sessions, storage, contributor.id)


def review_url(contribution: Contribution) -> str:
    return f"/admin/moderation/{contribution.id}"


async def post(
    panel: httpx.AsyncClient, contribution: Contribution, action: str, **changes: str
) -> httpx.Response:
    return await panel.post(review_url(contribution), data=FORM | changes | {"action": action})


# ---------------------------------------------------------------- queue and review page


async def test_queue_lists_pending_contributions_oldest_first(
    panel: httpx.AsyncClient, sessions: Sessions, storage: Storage, contributor: User
) -> None:
    first = await contribution_with_photos(sessions, storage, contributor.id, name="First")
    second = await contribution_with_photos(sessions, storage, contributor.id, name="Second")
    rejected = await contribution_with_photos(
        sessions, storage, contributor.id, name="Gone", status=ContributionStatus.REJECTED
    )

    page = (await panel.get("/admin/moderation")).text
    assert page.index(str(first.id)) < page.index(str(second.id))
    assert str(rejected.id) not in page

    page = (await panel.get("/admin/moderation", params={"status": "rejected"})).text
    assert str(rejected.id) in page
    assert str(first.id) not in page
    page = (await panel.get("/admin/moderation", params={"status": "nonsense"})).text
    assert str(first.id) in page  # pending


async def test_review_page_shows_the_photos_next_to_the_fields(
    panel: httpx.AsyncClient, pending: Contribution
) -> None:
    page = (await panel.get(review_url(pending))).text

    assert 'value="Harissa"' in page
    assert 'value="0.5"' in page  # saturates
    assert "Sucres 4 g" in page  # OCR text
    urls = re.findall(r'<img src="([^"]+)"', page)
    assert len(urls) == 2
    for url in urls:
        assert "X-Amz-Signature" in url
        assert "X-Amz-Expires=300" in url
    async with httpx.AsyncClient() as browser:  # the moderator's browser, straight to storage
        photo = await browser.get(urls[0].replace("&amp;", "&"))
    assert (photo.status_code, photo.content) == (200, JPEG)


def existing_product_note(page: str) -> str:
    """The note on whether approving creates or updates a product, as plain text."""
    match = re.search(
        r'<div class="card-body border-bottom" id="existing-product">(.*?)</div>\s*<form',
        page,
        re.S,
    )
    assert match is not None
    return " ".join(re.sub(r"<[^>]+>", " ", match.group(1)).split())


async def test_review_page_names_the_product_it_would_update(
    panel: httpx.AsyncClient, sessions: Sessions, storage: Storage, contributor: User
) -> None:
    async with sessions() as session:
        product = await ProductFactory.create(
            session, name="Chamia aux pistaches", brand="Le Moulin"
        )
        await session.commit()
    contribution = await contribution_with_photos(
        sessions, storage, contributor.id, ean=product.ean
    )

    page = (await panel.get(review_url(contribution))).text

    assert existing_product_note(page).startswith(
        "Updates an existing product: Chamia aux pistaches · Le Moulin"
        " · from open food facts, unverified · no grade."
    )
    assert f"/admin/product/details/{product.id}" in page


async def test_review_page_shows_the_current_grade_of_the_product(
    panel: httpx.AsyncClient, sessions: Sessions, storage: Storage, contributor: User
) -> None:
    async with sessions() as session:
        product = await ProductFactory.create(session, name=None)
        await ScoreFactory.create(session, product_id=product.id, grade=Grade.C)
        await session.commit()
    contribution = await contribution_with_photos(
        sessions, storage, contributor.id, ean=product.ean
    )

    note = existing_product_note((await panel.get(review_url(contribution))).text)

    assert note.startswith("Updates an existing product: unnamed · from open food facts")
    assert "grade C." in note


async def test_review_page_of_a_new_product(
    panel: httpx.AsyncClient, pending: Contribution
) -> None:
    page = (await panel.get(review_url(pending))).text
    assert existing_product_note(page) == "New product: approving creates it."


async def test_review_page_of_a_decided_contribution_has_no_note(
    panel: httpx.AsyncClient, sessions: Sessions, storage: Storage, contributor: User
) -> None:
    rejected = await contribution_with_photos(
        sessions, storage, contributor.id, status=ContributionStatus.REJECTED
    )
    page = (await panel.get(review_url(rejected))).text
    assert 'id="existing-product"' not in page


@pytest.mark.parametrize("path", [f"/admin/moderation/{uuid.uuid4()}", "/admin/moderation/x"])
async def test_unknown_contribution_is_404(panel: httpx.AsyncClient, path: str) -> None:
    assert (await panel.get(path)).status_code == 404


async def test_preview_scores_the_typed_values_without_saving(
    panel: httpx.AsyncClient, sessions: Sessions, pending: Contribution
) -> None:
    response = await post(panel, pending, "preview", sugars_g="40")

    assert response.status_code == 200
    assert re.search(r"Score with these values: <strong>[A-E]</strong>", response.text)
    assert 'value="40"' in response.text  # the form keeps what was typed
    assert (await reload(sessions, Contribution, pending.id)).nutrition["sugars_g"] == "4"


async def test_preview_of_insufficient_data(
    panel: httpx.AsyncClient, pending: Contribution
) -> None:
    response = await post(panel, pending, "preview", energy_kj="")
    assert "Not enough data to score" in response.text


@pytest.mark.parametrize(
    ("changes", "field", "message"),
    [
        ({"sugars_g": "four"}, "sugars_g", "Not a number"),
        ({"salt_g": "150"}, "salt_g", "less than or equal to 100"),
        ({"category": "soup"}, "category", "Input should be"),
        ({"non_nutritive_sweeteners": "maybe"}, "non_nutritive_sweeteners", "Choose yes"),
        ({"note": "x" * 501}, "note", "At most 500"),
    ],
)
async def test_invalid_values_are_shown_and_nothing_is_saved(
    panel: httpx.AsyncClient,
    *,
    sessions: Sessions,
    pending: Contribution,
    changes: dict[str, str],
    field: str,
    message: str,
) -> None:
    response = await post(panel, pending, "approve", **changes)

    assert response.status_code == 400
    assert f'data-error="{field}"' in response.text
    assert message in response.text
    saved = await reload(sessions, Contribution, pending.id)
    assert (saved.status, saved.submitted_values) == (ContributionStatus.PENDING, None)


async def test_unknown_action_is_refused(panel: httpx.AsyncClient, pending: Contribution) -> None:
    assert (await post(panel, pending, "publish")).status_code == 400


# ---------------------------------------------------------------- save, approve, reject


async def test_saving_keeps_the_contributors_values(
    panel: httpx.AsyncClient, sessions: Sessions, pending: Contribution
) -> None:
    response = await post(panel, pending, "save", sugars_g="5,5")

    assert response.status_code == 303
    assert response.headers["location"] == f"http://test{review_url(pending)}"
    saved = await reload(sessions, Contribution, pending.id)
    assert (saved.name, saved.nutrition["sugars_g"]) == ("Harissa forte", "5.5")
    assert saved.status == ContributionStatus.PENDING
    assert saved.submitted_values is not None
    assert saved.submitted_values["name"] == "Harissa"
    assert saved.submitted_values["nutrition"]["sugars_g"] == "4"

    page = (await panel.get(review_url(pending))).text
    assert "Saved." in page
    assert 'id="submitted"' in page

    await post(panel, pending, "save", name="Harissa extra")  # a second edit
    again = await reload(sessions, Contribution, pending.id)
    assert again.submitted_values == saved.submitted_values  # still the contributor's


async def test_saving_nothing_new_changes_nothing(
    panel: httpx.AsyncClient, sessions: Sessions, pending: Contribution
) -> None:
    response = await post(panel, pending, "save", name="Harissa")
    assert response.status_code == 303
    assert (await reload(sessions, Contribution, pending.id)).submitted_values is None
    assert "Nothing changed." in (await panel.get(review_url(pending))).text


async def test_approving_with_edits_makes_a_verified_product_of_them(
    panel: httpx.AsyncClient,
    sessions: Sessions,
    storage: Storage,
    pending: Contribution,
    admin: User,
) -> None:
    response = await post(panel, pending, "approve", salt_g="2.5", note="Thanks!")

    assert response.status_code == 303
    assert response.headers["location"] == "http://test/admin/moderation"
    decided = await reload(sessions, Contribution, pending.id)
    assert (decided.status, decided.reviewed_by, decided.review_note) == (
        ContributionStatus.APPROVED,
        admin.id,
        "Thanks!",
    )
    assert decided.submitted_values is not None
    async with sessions() as session:
        product = await session.scalar(select(Product).where(Product.ean == pending.ean))
        assert product is not None
        facts = await session.scalar(
            select(NutritionFacts).where(NutritionFacts.product_id == product.id)
        )
    assert (product.name, product.status) == ("Harissa forte", ProductStatus.VERIFIED)
    assert facts is not None
    assert str(facts.salt_g) == "2.5"
    assert product.image_key is not None
    assert await storage.public.head(product.image_key) is not None
    assert "Approved" in (await panel.get("/admin/moderation")).text


async def test_approving_without_edits_records_none(
    panel: httpx.AsyncClient, sessions: Sessions, pending: Contribution
) -> None:
    await post(panel, pending, "approve", name="Harissa")
    decided = await reload(sessions, Contribution, pending.id)
    assert (decided.status, decided.submitted_values) == (ContributionStatus.APPROVED, None)


async def test_rejecting_with_a_note(
    panel: httpx.AsyncClient, sessions: Sessions, pending: Contribution
) -> None:
    response = await post(panel, pending, "reject", note="The photo is blurry", sugars_g="bad")

    assert response.status_code == 303  # the values don't matter for a rejection
    decided = await reload(sessions, Contribution, pending.id)
    assert (decided.status, decided.review_note) == (
        ContributionStatus.REJECTED,
        "The photo is blurry",
    )
    assert decided.submitted_values is None


@pytest.mark.parametrize("action", ["approve", "reject", "save"])
async def test_a_decided_contribution_stays_as_it_is(
    panel: httpx.AsyncClient, sessions: Sessions, storage: Storage, contributor: User, action: str
) -> None:
    decided = await contribution_with_photos(
        sessions,
        storage,
        contributor.id,
        status=ContributionStatus.REJECTED,
        reviewed_at=datetime.now(UTC),
        review_note="Blurry",
    )

    response = await post(panel, decided, action)

    assert response.status_code == 303
    page = (await panel.get(review_url(decided))).text
    assert "already decided" in page
    assert 'id="decided"' in page
    assert 'value="approve"' not in page  # no buttons
    saved = await reload(sessions, Contribution, decided.id)
    assert (saved.status, saved.name, saved.submitted_values) == (
        ContributionStatus.REJECTED,
        "Harissa",
        None,
    )


async def test_storage_down_when_approving_changes_nothing(
    panel: httpx.AsyncClient,
    sessions: Sessions,
    pending: Contribution,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def failing_copy(*_: Any, **__: Any) -> None:
        raise StorageError("down")

    monkeypatch.setattr(Bucket, "copy_from", failing_copy)
    response = await post(panel, pending, "approve")

    assert response.status_code == 503
    assert "Photo storage is unavailable" in response.text
    assert (await reload(sessions, Contribution, pending.id)).status == ContributionStatus.PENDING


async def test_deleted_photos_are_said_so(
    panel: httpx.AsyncClient, sessions: Sessions, storage: Storage, contributor: User
) -> None:
    cleaned = await contribution_with_photos(
        sessions,
        storage,
        contributor.id,
        status=ContributionStatus.REJECTED,
        reviewed_at=datetime.now(UTC),
        photos_deleted_at=datetime.now(UTC),
    )
    page = (await panel.get(review_url(cleaned))).text
    assert 'id="photos-deleted"' in page
    assert "<img" not in page


# ---------------------------------------------------------------- error reports


async def report(sessions: Sessions, **values: Any) -> ErrorReport:
    async with sessions() as session:
        product = await ProductFactory.create(session)
        created = ErrorReport(
            client_id=uuid.uuid4().hex,
            ean=product.ean,
            product_id=product.id,
            reasons=[ReportReason.NUTRITION.value],
            comment="Sugar is wrong",
            product_updated_at=datetime.now(UTC),
            reported_at=datetime.now(UTC),
            **values,
        )
        session.add(created)
        await session.commit()
        return created


@pytest.mark.parametrize(
    ("decision", "status"),
    [("resolve", ReportStatus.RESOLVED), ("dismiss", ReportStatus.DISMISSED)],
)
async def test_reports_are_resolved_or_dismissed(
    panel: httpx.AsyncClient, sessions: Sessions, admin: User, decision: str, status: ReportStatus
) -> None:
    item = await report(sessions)
    page = (await panel.get("/admin/error-reports")).text
    assert "Sugar is wrong" in page
    assert f"/admin/product/details/{item.product_id}" in page

    response = await panel.post(f"/admin/error-reports/{item.id}/{decision}")

    assert response.status_code == 303
    saved = await reload(sessions, ErrorReport, item.id)
    assert (saved.status, saved.resolved_by) == (status, admin.id)
    assert saved.resolved_at is not None
    assert "Sugar is wrong" not in (await panel.get("/admin/error-reports")).text
    handled = (await panel.get("/admin/error-reports", params={"status": status.value})).text
    assert "Sugar is wrong" in handled


async def test_a_handled_report_stays_as_it_is(
    panel: httpx.AsyncClient, sessions: Sessions
) -> None:
    item = await report(sessions, status=ReportStatus.DISMISSED)

    response = await panel.post(f"/admin/error-reports/{item.id}/resolve")

    assert response.status_code == 303
    assert "already handled" in (await panel.get("/admin/error-reports")).text
    assert (await reload(sessions, ErrorReport, item.id)).status == ReportStatus.DISMISSED


@pytest.mark.parametrize(
    "path",
    [
        f"/admin/error-reports/{uuid.uuid4()}/resolve",
        "/admin/error-reports/x/resolve",
        f"/admin/error-reports/{uuid.uuid4()}/reopen",
    ],
)
async def test_unknown_report_or_decision_is_404(panel: httpx.AsyncClient, path: str) -> None:
    assert (await panel.post(path)).status_code == 404
