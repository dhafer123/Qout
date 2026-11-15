"""Contributions, score preview, error reports and moderation through the API, against
real Postgres, Redis and RustFS. Photos are uploaded the way the app does: a presigned
URL from `POST /v1/uploads`, then a PUT to storage."""

import uuid
from collections.abc import AsyncIterator, Callable, Iterator
from decimal import Decimal
from pathlib import Path
from typing import Any

import httpx
import pytest
import respx
from redis.asyncio import Redis
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.core.config import Settings
from app.core.storage import Bucket, Storage, StorageError, StoredObject
from app.factory import create_app
from app.modules.contributions import moderation
from app.modules.contributions.models import Contribution, ErrorReport
from app.modules.contributions.nutrition import score_preview
from app.modules.contributions.reports import ReportService
from app.modules.contributions.schemas import NutritionValues
from app.modules.contributions.service import ContributionService
from app.modules.products.cache import ProductCache, cache_key
from app.modules.products.models import (
    DataSource,
    NutritionFacts,
    Product,
    ProductStatus,
    QualityFlag,
    Score,
)
from app.modules.scoring import Category
from tests.factories import NutritionFactsFactory, ProductFactory
from tests.integration.conftest import IntegrationEnv, running_client

Sessions = async_sessionmaker[AsyncSession]
PASSWORD = "a long enough password"
EAN = "6191507220214"
JPEG = b"\xff\xd8\xff\xe0" + b"front of the package"
PNG = b"\x89PNG\r\n\x1a\n" + b"nutrition table"
NUTRITION = {
    "energy_kj": 1520,
    "sugars_g": 12.5,
    "saturated_fat_g": 3.1,
    "total_fat_g": 9,
    "salt_g": 0.8,
    "protein_g": 6.2,
    "fvl_percent": 0,
}
REDIS_PATTERNS = ("qout:ratelimit:*", "qout:product:*")


# ---------------------------------------------------------------- fixtures


async def _clear(engine: AsyncEngine, redis: Redis) -> None:
    async with engine.begin() as connection:
        await connection.execute(text("TRUNCATE users, products CASCADE"))
    for pattern in REDIS_PATTERNS:
        keys = [key async for key in redis.scan_iter(match=pattern)]
        if keys:
            await redis.delete(*keys)


@pytest.fixture
async def redis(integration_env: IntegrationEnv) -> AsyncIterator[Redis]:
    client = Redis.from_url(str(integration_env.redis_url))
    yield client
    await client.aclose()


@pytest.fixture
async def sessions(db_engine: AsyncEngine, redis: Redis) -> AsyncIterator[Sessions]:
    await _clear(db_engine, redis)
    yield async_sessionmaker(db_engine, expire_on_commit=False)
    await _clear(db_engine, redis)


@pytest.fixture
def no_off() -> Iterator[respx.MockRouter]:
    """Open Food Facts is never called (unmocked requests fail); storage is reachable."""
    with respx.mock(assert_all_called=False) as router:
        router.route(host="localhost").pass_through()
        yield router


@pytest.fixture
def api_with(
    make_settings: Callable[..., Settings],
    sessions: Sessions,
    storage: Storage,
    no_off: respx.MockRouter,
) -> Callable[..., Any]:
    def _api(**overrides: object) -> Any:
        return running_client(create_app(make_settings(**overrides)))

    return _api


@pytest.fixture
async def api(api_with: Callable[..., Any]) -> AsyncIterator[httpx.AsyncClient]:
    async with api_with() as client:
        yield client


@pytest.fixture
def cache(redis: Redis) -> ProductCache:
    return ProductCache(redis, ttl_seconds=60, not_found_ttl_seconds=60)


# ---------------------------------------------------------------- helpers


async def sign_in(api: httpx.AsyncClient, email: str = "contributor@example.tn") -> dict[str, str]:
    response = await api.post("/v1/auth/register", json={"email": email, "password": PASSWORD})
    assert response.status_code == 201, response.text
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


async def moderator(api: httpx.AsyncClient, sessions: Sessions) -> dict[str, str]:
    headers = await sign_in(api, "moderator@example.tn")
    async with sessions() as session:
        await session.execute(
            text("UPDATE users SET role = 'admin' WHERE email = 'moderator@example.tn'")
        )
        await session.commit()
    return headers


async def upload(
    api: httpx.AsyncClient,
    headers: dict[str, str],
    client_id: uuid.UUID,
    kind: str,
    *,
    data: bytes = JPEG,
    content_type: str = "image/jpeg",
) -> str:
    ticket = await api.post(
        "/v1/uploads",
        json={
            "contribution_id": str(client_id),
            "kind": kind,
            "content_type": content_type,
            "size_bytes": len(data),
        },
        headers=headers,
    )
    assert ticket.status_code == 201, ticket.text
    async with httpx.AsyncClient() as http:
        put = await http.put(
            ticket.json()["url"], content=data, headers={"Content-Type": content_type}
        )
    assert put.status_code == 200
    key: str = ticket.json()["key"]
    return key


def contribution_body(client_id: uuid.UUID, photos: dict[str, str], **values: Any) -> Any:
    body: dict[str, Any] = {
        "client_id": str(client_id),
        "ean": EAN,
        "name": "Harissa du Cap Bon",
        "brand": "Sicam",
        "category": "general",
        "basis": "per_100g",
        "nutrition": NUTRITION,
        "photos": photos,
        "ocr_text": {"nutrition": "Valeurs nutritionnelles pour 100 g ..."},
        "parser_used": "rules",
    }
    return body | values


async def contribute(
    api: httpx.AsyncClient, headers: dict[str, str], **values: Any
) -> dict[str, Any]:
    """Uploads a front (PNG) and a nutrition photo (JPEG) and submits."""
    client_id = uuid.uuid4()
    photos = {
        "front": await upload(api, headers, client_id, "front", data=PNG, content_type="image/png"),
        "nutrition": await upload(api, headers, client_id, "nutrition"),
    }
    response = await api.post(
        "/v1/contributions", json=contribution_body(client_id, photos, **values), headers=headers
    )
    assert response.status_code == 201, response.text
    body: dict[str, Any] = response.json()
    return body


async def count(sessions: Sessions, model: type[Any]) -> int:
    async with sessions() as session:
        return await session.scalar(select(func.count()).select_from(model)) or 0


async def product_by_ean(sessions: Sessions, ean: str = EAN) -> Product | None:
    async with sessions() as session:
        return await session.scalar(select(Product).where(Product.ean == ean))


async def contribution_row(sessions: Sessions, contribution_id: str) -> Contribution:
    async with sessions() as session:
        row = await session.get(Contribution, uuid.UUID(contribution_id))
    assert row is not None
    return row


# ---------------------------------------------------------------- submit


async def test_submitted_contribution_is_pending(
    api: httpx.AsyncClient, sessions: Sessions
) -> None:
    headers = await sign_in(api)

    body = await contribute(api, headers, name="  Harissa  ", brand="")

    assert body["status"] == "pending"
    assert (body["ean"], body["name"], body["brand"]) == (EAN, "Harissa", None)
    assert (body["review_note"], body["reviewed_at"]) == (None, None)
    row = await contribution_row(sessions, body["id"])
    assert row.nutrition["sugars_g"] == "12.5"
    assert set(row.photos) == {"front", "nutrition"}
    assert row.ocr_text == {"nutrition": "Valeurs nutritionnelles pour 100 g ..."}
    assert row.parser_used == "rules"
    assert await count(sessions, Product) == 0  # nothing public before moderation


async def test_upc_a_is_stored_as_ean_13(api: httpx.AsyncClient) -> None:
    headers = await sign_in(api)

    body = await contribute(api, headers, ean="036000291452")

    assert body["ean"] == "0036000291452"


async def test_resending_returns_the_stored_contribution(
    api: httpx.AsyncClient, sessions: Sessions
) -> None:
    headers = await sign_in(api)
    first = await contribute(api, headers)
    row = await contribution_row(sessions, first["id"])

    again = await api.post(
        "/v1/contributions",
        json=contribution_body(row.client_id, row.photos, name="Changed"),
        headers=headers,
    )

    assert again.status_code == 200
    assert again.json() == first
    assert await count(sessions, Contribution) == 1


async def test_same_client_id_from_another_user_is_another_contribution(
    api: httpx.AsyncClient, sessions: Sessions
) -> None:
    first_user = await sign_in(api, "one@example.tn")
    other_user = await sign_in(api, "two@example.tn")
    client_id = uuid.uuid4()
    for headers in (first_user, other_user):
        photos = {
            "front": await upload(api, headers, client_id, "front"),
            "nutrition": await upload(api, headers, client_id, "nutrition"),
        }
        response = await api.post(
            "/v1/contributions", json=contribution_body(client_id, photos), headers=headers
        )
        assert response.status_code == 201

    assert await count(sessions, Contribution) == 2


async def test_photos_of_another_user_are_refused(api: httpx.AsyncClient) -> None:
    owner = await sign_in(api, "owner@example.tn")
    thief = await sign_in(api, "thief@example.tn")
    client_id = uuid.uuid4()
    photos = {
        "front": await upload(api, owner, client_id, "front"),
        "nutrition": await upload(api, owner, client_id, "nutrition"),
    }

    response = await api.post(
        "/v1/contributions", json=contribution_body(client_id, photos), headers=thief
    )

    assert response.status_code == 422
    assert response.json()["detail"] == (
        "front photo: not an upload of yours for this contribution"
    )


async def test_photos_of_another_contribution_are_refused(api: httpx.AsyncClient) -> None:
    headers = await sign_in(api)
    earlier = uuid.uuid4()
    photos = {
        "front": await upload(api, headers, earlier, "front"),
        "nutrition": await upload(api, headers, earlier, "nutrition"),
    }

    response = await api.post(
        "/v1/contributions", json=contribution_body(uuid.uuid4(), photos), headers=headers
    )

    assert response.status_code == 422


async def test_photos_must_be_uploaded(api: httpx.AsyncClient, sessions: Sessions) -> None:
    headers = await sign_in(api)
    client_id = uuid.uuid4()
    front = await upload(api, headers, client_id, "front")
    ticket = await api.post(
        "/v1/uploads",
        json={
            "contribution_id": str(client_id),
            "kind": "nutrition",
            "content_type": "image/jpeg",
            "size_bytes": 10,
        },
        headers=headers,
    )
    never_uploaded = ticket.json()["key"]

    response = await api.post(
        "/v1/contributions",
        json=contribution_body(client_id, {"front": front, "nutrition": never_uploaded}),
        headers=headers,
    )

    assert response.status_code == 422
    assert response.json()["detail"] == "nutrition photo: not uploaded"
    assert await count(sessions, Contribution) == 0


async def test_invalid_barcode_is_refused(api: httpx.AsyncClient) -> None:
    headers = await sign_in(api)
    client_id = uuid.uuid4()
    photos = {
        "front": await upload(api, headers, client_id, "front"),
        "nutrition": await upload(api, headers, client_id, "nutrition"),
    }

    response = await api.post(
        "/v1/contributions",
        json=contribution_body(client_id, photos, ean="6191507220215"),
        headers=headers,
    )

    assert response.status_code == 422


async def test_storage_down_is_503(api_with: Callable[..., Any]) -> None:
    async with api_with(s3_endpoint_url="http://127.0.0.1:1") as api:
        headers = await sign_in(api)
        client_id = uuid.uuid4()
        prefix = f"contributions/{(await api.get('/v1/auth/me', headers=headers)).json()['id']}"
        photos = {
            "front": f"{prefix}/{client_id}/front-0123456789abcdef.jpg",
            "nutrition": f"{prefix}/{client_id}/nutrition-0123456789abcdef.jpg",
        }
        response = await api.post(
            "/v1/contributions", json=contribution_body(client_id, photos), headers=headers
        )

    assert response.status_code == 503
    assert response.headers["retry-after"] == "30"


async def test_contributing_needs_an_account(api: httpx.AsyncClient) -> None:
    body = contribution_body(uuid.uuid4(), {"front": "a", "nutrition": "b"})

    assert (await api.post("/v1/contributions", json=body)).status_code == 401
    assert (await api.get("/v1/contributions")).status_code == 401
    assert (await api.get(f"/v1/contributions/{uuid.uuid4()}")).status_code == 401


async def test_contributors_see_only_their_own(api: httpx.AsyncClient) -> None:
    mine = await sign_in(api, "mine@example.tn")
    theirs = await sign_in(api, "theirs@example.tn")
    first = await contribute(api, mine)
    second = await contribute(api, mine, ean="6194001481440")
    other = await contribute(api, theirs)

    listed = (await api.get("/v1/contributions", headers=mine)).json()["items"]
    one = await api.get(f"/v1/contributions/{first['id']}", headers=mine)
    not_mine = await api.get(f"/v1/contributions/{other['id']}", headers=mine)
    limited = await api.get("/v1/contributions?limit=1", headers=mine)

    assert [item["id"] for item in listed] == [second["id"], first["id"]]
    assert one.json() == first
    assert not_mine.status_code == 404
    assert [item["id"] for item in limited.json()["items"]] == [second["id"]]


# ---------------------------------------------------------------- preview


async def test_preview_scores_without_saving(api: httpx.AsyncClient, sessions: Sessions) -> None:
    headers = await sign_in(api)

    response = await api.post(
        "/v1/score/preview",
        json={"category": "general", "nutrition": NUTRITION},
        headers=headers,
    )

    expected = score_preview(Category.GENERAL, NutritionValues(**NUTRITION))
    assert response.status_code == 200
    assert response.json() == expected.model_dump(mode="json")
    assert response.json()["grade"] is not None
    for model in (Product, NutritionFacts, Score, Contribution):
        assert await count(sessions, model) == 0


async def test_preview_reports_insufficient_data(api: httpx.AsyncClient) -> None:
    headers = await sign_in(api)

    response = await api.post(
        "/v1/score/preview",
        json={"category": "general", "nutrition": {"energy_kj": 100}},
        headers=headers,
    )

    body = response.json()
    assert (body["grade"], body["total"]) == (None, None)
    assert "salt_g" in body["breakdown"]["insufficient_data"]


async def test_preview_needs_an_account(api: httpx.AsyncClient) -> None:
    response = await api.post("/v1/score/preview", json={"category": "water", "nutrition": {}})

    assert response.status_code == 401


# ---------------------------------------------------------------- label parsing

LABELS = Path(__file__).resolve().parents[1] / "fixtures" / "labels"


async def test_label_text_is_parsed(api: httpx.AsyncClient, sessions: Sessions) -> None:
    headers = await sign_in(api)
    text = (LABELS / "fr-three-columns.txt").read_text(encoding="utf-8")

    response = await api.post("/v1/labels/parse", json={"ocr_text": text}, headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert (body["parser_used"], body["ok"], body["basis"]) == ("rules", True, "per_100g")
    assert body["values"]["energy_kj"] == 1958
    assert body["values"]["saturated_fat_g"] == 8.2
    assert body["values"]["sodium_g"] is None
    assert body["issues"] == []
    assert await count(sessions, Contribution) == 0


async def test_label_declared_per_portion_only(api: httpx.AsyncClient) -> None:
    headers = await sign_in(api)
    text = (LABELS / "per-portion-only.txt").read_text(encoding="utf-8")

    body = (await api.post("/v1/labels/parse", json={"ocr_text": text}, headers=headers)).json()

    assert body["ok"] is False
    assert body["issues"] == [{"code": "per_portion_only", "field": None, "blocking": True}]
    assert all(value is None for value in body["values"].values())


async def test_label_parsing_needs_an_account_and_a_bounded_text(
    api: httpx.AsyncClient,
) -> None:
    headers = await sign_in(api)

    anonymous = await api.post("/v1/labels/parse", json={"ocr_text": "Sel 1 g"})
    too_long = await api.post("/v1/labels/parse", json={"ocr_text": "x" * 20_001}, headers=headers)

    assert (anonymous.status_code, too_long.status_code) == (401, 422)


# ---------------------------------------------------------------- approve


async def test_approval_creates_a_verified_scored_product_with_its_photo(
    api: httpx.AsyncClient,
    sessions: Sessions,
    storage: Storage,
    cache: ProductCache,
    redis: Redis,
) -> None:
    contributor = await sign_in(api)
    admin = await moderator(api, sessions)
    submitted = await contribute(api, contributor)
    await cache.set_not_found(EAN)  # someone scanned it before

    response = await api.post(
        f"/v1/admin/contributions/{submitted['id']}/approve", json={}, headers=admin
    )

    assert response.status_code == 200, response.text
    decided = response.json()
    assert decided["status"] == "approved"
    assert decided["reviewed_by"] == (await api.get("/v1/auth/me", headers=admin)).json()["id"]
    assert decided["product_id"] is not None
    product = await product_by_ean(sessions)
    assert product is not None
    assert (product.source, product.status) == (DataSource.CONTRIBUTION, ProductStatus.VERIFIED)
    assert (product.name, product.brand, product.category) == (
        "Harissa du Cap Bon",
        "Sicam",
        Category.GENERAL,
    )
    assert product.image_key == f"products/{EAN}/contribution-{uuid.UUID(submitted['id']).hex}.png"
    assert await storage.public.head(product.image_key) == StoredObject(len(PNG), "image/png")
    assert await redis.exists(cache_key(EAN)) == 0

    lookup = (await api.get(f"/v1/products/{EAN}")).json()
    expected = score_preview(Category.GENERAL, NutritionValues(**NUTRITION))
    assert (lookup["status"], lookup["source"]) == ("verified", "contribution")
    assert lookup["image_url"].endswith(product.image_key)
    assert lookup["nutrition"]["version"] == 1
    assert lookup["nutrition"]["source"] == "contribution"
    assert lookup["nutrition"]["sugars_g"] == 12.5
    assert lookup["nutrition"]["fibre_g"] is None
    assert (lookup["score"]["grade"], lookup["score"]["total"]) == (
        expected.grade,
        expected.total,
    )

    mine = await api.get(f"/v1/contributions/{submitted['id']}", headers=contributor)
    assert mine.json()["status"] == "approved"


async def test_approval_updates_an_off_product(
    api: httpx.AsyncClient, sessions: Sessions, storage: Storage
) -> None:
    old_photo = f"products/{EAN}/front-0123456789abcdef.jpg"
    await storage.public.put(old_photo, JPEG, content_type="image/jpeg")
    async with sessions() as session:
        product = await ProductFactory.create(
            session,
            ean=EAN,
            name="Harissa (OFF)",
            brand="Sicam",
            category=Category.GENERAL,
            quality_flag=QualityFlag.INCOMPLETE,
            nova_group=4,
            source_image_url="https://images.openfoodfacts.org/x/front_fr.1.400.jpg",
            image_key=old_photo,
            image_copied_from="https://images.openfoodfacts.org/x/front_fr.1.400.jpg",
        )
        await NutritionFactsFactory.create(session, product_id=product.id)
        await session.commit()
    contributor = await sign_in(api)
    admin = await moderator(api, sessions)
    submitted = await contribute(api, contributor, name=None, brand="Sicam Tunisie")

    response = await api.post(
        f"/v1/admin/contributions/{submitted['id']}/approve",
        json={"note": "  checked against the label "},
        headers=admin,
    )

    assert response.json()["review_note"] == "checked against the label"
    updated = await product_by_ean(sessions)
    assert updated is not None
    assert updated.id == product.id
    assert (updated.name, updated.brand) == ("Harissa (OFF)", "Sicam Tunisie")
    assert (updated.source, updated.status) == (DataSource.CONTRIBUTION, ProductStatus.VERIFIED)
    assert (updated.quality_flag, updated.nova_group) == (None, 4)
    assert (updated.source_image_url, updated.image_copied_from) == (None, None)
    assert await storage.public.head(old_photo) is None
    async with sessions() as session:
        versions = (
            await session.scalars(
                select(NutritionFacts)
                .where(NutritionFacts.product_id == product.id)
                .order_by(NutritionFacts.version)
            )
        ).all()
    assert [(v.version, v.source) for v in versions] == [
        (1, DataSource.OPEN_FOOD_FACTS),
        (2, DataSource.CONTRIBUTION),
    ]
    assert versions[1].salt_g == Decimal("0.8")


async def test_approval_without_the_front_photo_keeps_the_product_photo(
    api: httpx.AsyncClient, sessions: Sessions, storage: Storage
) -> None:
    contributor = await sign_in(api)
    admin = await moderator(api, sessions)
    submitted = await contribute(api, contributor)
    row = await contribution_row(sessions, submitted["id"])
    await storage.uploads.delete(row.photos["front"])

    response = await api.post(
        f"/v1/admin/contributions/{submitted['id']}/approve", json={}, headers=admin
    )

    assert response.status_code == 200
    product = await product_by_ean(sessions)
    assert product is not None
    assert product.image_key is None


async def test_approval_with_storage_down_changes_nothing(
    api_with: Callable[..., Any], api: httpx.AsyncClient, sessions: Sessions
) -> None:
    contributor = await sign_in(api)
    admin = await moderator(api, sessions)
    submitted = await contribute(api, contributor)

    async with api_with(s3_endpoint_url="http://127.0.0.1:1") as down:
        response = await down.post(
            f"/v1/admin/contributions/{submitted['id']}/approve", json={}, headers=admin
        )

    assert response.status_code == 503
    assert (await contribution_row(sessions, submitted["id"])).status == "pending"
    assert await count(sessions, Product) == 0


@pytest.mark.parametrize("front_uploaded", [True, False])
async def test_failed_approval_changes_nothing(
    api: httpx.AsyncClient,
    sessions: Sessions,
    storage: Storage,
    monkeypatch: pytest.MonkeyPatch,
    front_uploaded: bool,
) -> None:
    """The copied photo, if any, is removed again."""

    async def broken_scoring(*_: Any) -> Any:
        raise RuntimeError("scoring failed")

    contributor = await sign_in(api)
    admin = await moderator(api, sessions)
    submitted = await contribute(api, contributor)
    if not front_uploaded:
        await storage.uploads.delete(
            (await contribution_row(sessions, submitted["id"])).photos["front"]
        )
    monkeypatch.setattr(moderation, "ensure_current_score", broken_scoring)

    with pytest.raises(RuntimeError, match="scoring failed"):
        await api.post(f"/v1/admin/contributions/{submitted['id']}/approve", json={}, headers=admin)

    photo = f"products/{EAN}/contribution-{uuid.UUID(submitted['id']).hex}.png"
    assert await storage.public.head(photo) is None
    assert (await contribution_row(sessions, submitted["id"])).status == "pending"
    assert await count(sessions, Product) == 0


async def test_old_photo_that_cannot_be_deleted_does_not_fail_approval(
    api: httpx.AsyncClient,
    sessions: Sessions,
    storage: Storage,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async with sessions() as session:
        await ProductFactory.create(session, ean=EAN, image_key=f"products/{EAN}/old.jpg")
        await session.commit()
    contributor = await sign_in(api)
    admin = await moderator(api, sessions)
    submitted = await contribute(api, contributor)

    async def failing_delete(_: Bucket, key: str) -> None:
        raise StorageError(key)

    monkeypatch.setattr(Bucket, "delete", failing_delete)

    response = await api.post(
        f"/v1/admin/contributions/{submitted['id']}/approve", json={}, headers=admin
    )

    assert response.status_code == 200
    product = await product_by_ean(sessions)
    assert product is not None
    assert product.image_key is not None
    assert product.image_key.startswith(f"products/{EAN}/contribution-")


# ---------------------------------------------------------------- races


async def test_concurrent_resend_of_a_contribution(
    api: httpx.AsyncClient, sessions: Sessions, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Both requests passed the "already stored?" check: the second insert loses."""
    headers = await sign_in(api)
    first = await contribute(api, headers)
    row = await contribution_row(sessions, first["id"])
    original = ContributionService._find
    calls = 0

    async def miss_once(self: ContributionService, *args: Any) -> Contribution | None:
        nonlocal calls
        calls += 1
        return None if calls == 1 else await original(self, *args)

    monkeypatch.setattr(ContributionService, "_find", miss_once)

    again = await api.post(
        "/v1/contributions", json=contribution_body(row.client_id, row.photos), headers=headers
    )

    assert again.status_code == 200
    assert again.json()["id"] == first["id"]
    assert await count(sessions, Contribution) == 1


async def test_concurrent_resend_of_a_report(
    api: httpx.AsyncClient,
    sessions: Sessions,
    reported_product: Product,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    body = report_body()
    first = await api.post("/v1/reports", json=body)
    original = ReportService._find
    calls = 0

    async def miss_once(self: ReportService, client_id: str) -> ErrorReport | None:
        nonlocal calls
        calls += 1
        return None if calls == 1 else await original(self, client_id)

    monkeypatch.setattr(ReportService, "_find", miss_once)

    again = await api.post("/v1/reports", json=body)

    assert again.status_code == 200
    assert again.json() == first.json()
    assert await count(sessions, ErrorReport) == 1


# ---------------------------------------------------------------- reject and queue


async def test_rejection_leaves_the_product_unchanged(
    api: httpx.AsyncClient, sessions: Sessions
) -> None:
    async with sessions() as session:
        await ProductFactory.create(session, ean=EAN, name="Harissa (OFF)")
        await session.commit()
    before = await product_by_ean(sessions)
    contributor = await sign_in(api)
    admin = await moderator(api, sessions)
    submitted = await contribute(api, contributor)

    response = await api.post(
        f"/v1/admin/contributions/{submitted['id']}/reject",
        json={"note": "The nutrition photo is blurry"},
        headers=admin,
    )

    assert response.status_code == 200
    assert response.json()["status"] == "rejected"
    after = await product_by_ean(sessions)
    assert after is not None
    assert before is not None
    assert (after.name, after.source, after.status, after.updated_at) == (
        before.name,
        before.source,
        before.status,
        before.updated_at,
    )
    assert await count(sessions, NutritionFacts) == 0
    mine = (await api.get(f"/v1/contributions/{submitted['id']}", headers=contributor)).json()
    assert (mine["status"], mine["review_note"]) == ("rejected", "The nutrition photo is blurry")
    assert mine["reviewed_at"] is not None


@pytest.mark.parametrize("decision", ["approve", "reject"])
async def test_a_decision_is_final(
    api: httpx.AsyncClient, sessions: Sessions, decision: str
) -> None:
    contributor = await sign_in(api)
    admin = await moderator(api, sessions)
    submitted = await contribute(api, contributor)
    url = f"/v1/admin/contributions/{submitted['id']}"
    assert (await api.post(f"{url}/{decision}", json={}, headers=admin)).status_code == 200

    again = [
        await api.post(f"{url}/{other}", json={}, headers=admin) for other in ("approve", "reject")
    ]

    assert [response.status_code for response in again] == [409, 409]


async def test_unknown_contribution_is_404(api: httpx.AsyncClient, sessions: Sessions) -> None:
    admin = await moderator(api, sessions)
    for decision in ("approve", "reject"):
        response = await api.post(
            f"/v1/admin/contributions/{uuid.uuid4()}/{decision}", json={}, headers=admin
        )
        assert response.status_code == 404


async def test_queue_is_oldest_first_per_status(api: httpx.AsyncClient, sessions: Sessions) -> None:
    contributor = await sign_in(api)
    admin = await moderator(api, sessions)
    first = await contribute(api, contributor)
    second = await contribute(api, contributor, ean="6194001481440")
    third = await contribute(api, contributor, ean="6194039501011")
    await api.post(f"/v1/admin/contributions/{second['id']}/reject", json={}, headers=admin)

    pending = (await api.get("/v1/admin/contributions", headers=admin)).json()["items"]
    rejected = await api.get("/v1/admin/contributions?status=rejected", headers=admin)
    limited = await api.get("/v1/admin/contributions?limit=1", headers=admin)

    assert [item["id"] for item in pending] == [first["id"], third["id"]]
    assert pending[0]["photos"].keys() == {"front", "nutrition"}
    assert pending[0]["nutrition"]["energy_kj"] == "1520.0"
    assert pending[0]["user_id"] is not None
    assert [item["id"] for item in rejected.json()["items"]] == [second["id"]]
    assert len(limited.json()["items"]) == 1


async def test_moderation_is_for_admins_only(api: httpx.AsyncClient, sessions: Sessions) -> None:
    contributor = await sign_in(api)
    submitted = await contribute(api, contributor)
    calls = [
        ("get", "/v1/admin/contributions"),
        ("get", "/v1/admin/reports"),
        ("post", f"/v1/admin/contributions/{submitted['id']}/approve"),
        ("post", f"/v1/admin/contributions/{submitted['id']}/reject"),
    ]
    for method, url in calls:
        kwargs: dict[str, Any] = {"json": {}} if method == "post" else {}
        anonymous = await api.request(method, url, **kwargs)
        forbidden = await api.request(method, url, headers=contributor, **kwargs)
        assert (anonymous.status_code, forbidden.status_code) == (401, 403), url
    assert (await contribution_row(sessions, submitted["id"])).status == "pending"


# ---------------------------------------------------------------- reports


def report_body(**values: Any) -> dict[str, Any]:
    body: dict[str, Any] = {
        "client_id": uuid.uuid4().hex,
        "ean": EAN,
        "reasons": ["grade", "other"],
        "comment": "The label says 3 g of salt",
        "product_updated_at": "2026-11-12T18:00:00.000Z",
        "created_at": "2026-11-15T09:30:00.000Z",
    }
    return body | values


@pytest.fixture
async def reported_product(sessions: Sessions) -> Product:
    async with sessions() as session:
        product = await ProductFactory.create(session, ean=EAN)
        await session.commit()
    return product


async def test_anonymous_report_is_stored(
    api: httpx.AsyncClient, sessions: Sessions, reported_product: Product
) -> None:
    body = report_body()

    response = await api.post("/v1/reports", json=body)

    assert response.status_code == 201
    assert response.json()["client_id"] == body["client_id"]
    async with sessions() as session:
        report = await session.scalar(select(ErrorReport))
    assert report is not None
    assert (report.product_id, report.user_id) == (reported_product.id, None)
    assert report.reasons == ["grade", "other"]
    assert (report.status, report.reported_at.isoformat()) == (
        "open",
        "2026-11-15T09:30:00+00:00",
    )


async def test_report_records_the_signed_in_user(
    api: httpx.AsyncClient, sessions: Sessions, reported_product: Product
) -> None:
    headers = await sign_in(api)
    me = (await api.get("/v1/auth/me", headers=headers)).json()["id"]

    await api.post("/v1/reports", json=report_body(), headers=headers)
    stale = await api.post(
        "/v1/reports", json=report_body(), headers={"Authorization": "Bearer expired"}
    )

    assert stale.status_code == 201  # an invalid token makes it anonymous, not refused
    async with sessions() as session:
        users = sorted(str(r.user_id) for r in (await session.scalars(select(ErrorReport))).all())
    assert users == sorted([me, "None"])


async def test_a_resent_report_is_stored_once(
    api_with: Callable[..., Any], sessions: Sessions, reported_product: Product
) -> None:
    body = report_body()
    async with api_with(report_max_per_ip=1) as api:
        first = await api.post("/v1/reports", json=body)
        again = await api.post("/v1/reports", json=body)

    assert (first.status_code, again.status_code) == (201, 200)
    assert again.json() == first.json()  # same receipt, not rate-limited
    assert await count(sessions, ErrorReport) == 1


async def test_reports_are_rate_limited_per_ip(
    api_with: Callable[..., Any], reported_product: Product
) -> None:
    async with api_with(report_max_per_ip=2, report_window_seconds=60) as api:
        statuses = [
            (await api.post("/v1/reports", json=report_body())).status_code for _ in range(3)
        ]
        limited = await api.post("/v1/reports", json=report_body())

    assert statuses == [201, 201, 429]
    assert 1 <= int(limited.headers["retry-after"]) <= 60


async def test_report_on_an_unknown_product_is_404(api: httpx.AsyncClient) -> None:
    response = await api.post("/v1/reports", json=report_body(ean="6194001481440"))

    assert response.status_code == 404


@pytest.mark.parametrize(
    "values",
    [
        pytest.param({"ean": "6191507220215"}, id="check-digit"),
        pytest.param({"reasons": ["other"], "comment": None}, id="other-without-comment"),
        pytest.param({"reasons": []}, id="no-reason"),
    ],
)
async def test_invalid_reports_are_refused(
    api: httpx.AsyncClient, reported_product: Product, values: dict[str, Any]
) -> None:
    response = await api.post("/v1/reports", json=report_body(**values))

    assert response.status_code == 422


async def test_moderators_list_open_reports(
    api: httpx.AsyncClient, sessions: Sessions, reported_product: Product
) -> None:
    admin = await moderator(api, sessions)
    first, second = report_body(), report_body(reasons=["name"], comment=None)
    for body in (first, second):
        await api.post("/v1/reports", json=body)

    listed = (await api.get("/v1/admin/reports", headers=admin)).json()["items"]
    resolved = (await api.get("/v1/admin/reports?status=resolved", headers=admin)).json()

    assert [item["client_id"] for item in listed] == [first["client_id"], second["client_id"]]
    assert listed[1]["reasons"] == ["name"]
    assert listed[0]["product_id"] == str(reported_product.id)
    assert resolved["items"] == []
