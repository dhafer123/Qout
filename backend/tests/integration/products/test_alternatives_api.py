"""`GET /v1/products/{ean}/alternatives` against real Postgres.

Requests commit, so every test starts and ends with empty product tables. Open Food Facts
is mocked to fail: the endpoint must never call it.
"""

from collections.abc import AsyncIterator, Callable, Iterator
from decimal import Decimal
from typing import Any

import httpx
import pytest
import respx
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.core.config import Settings
from app.factory import create_app
from app.modules.products.models import Product, ProductStatus
from app.modules.scoring import ENGINE_VERSION, Category, Grade
from tests.factories import NutritionFactsFactory, ProductFactory, ScoreFactory
from tests.integration.conftest import running_client

OFF_BASE = "https://off.test"
SNACKS = ["en:snacks", "en:biscuits"]


@pytest.fixture
async def sessions(db_engine: AsyncEngine) -> AsyncIterator[async_sessionmaker[AsyncSession]]:
    async def clear() -> None:
        async with db_engine.begin() as connection:
            await connection.execute(text("TRUNCATE products, scan_events CASCADE"))

    await clear()
    yield async_sessionmaker(db_engine, expire_on_commit=False)
    await clear()


@pytest.fixture
def off() -> Iterator[respx.Route]:
    with respx.mock(assert_all_called=False) as router:
        yield router.route(host="off.test").respond(500)


@pytest.fixture
async def api(
    make_settings: Callable[..., Settings],
    sessions: async_sessionmaker[AsyncSession],
    off: respx.Route,
) -> AsyncIterator[httpx.AsyncClient]:
    settings = make_settings(off_base_url=OFF_BASE, off_max_retries=0)
    async with running_client(create_app(settings)) as client:
        yield client


async def seed(
    sessions: async_sessionmaker[AsyncSession],
    *,
    grade: Grade | None,
    total: int | None = None,
    category: Category | None = Category.GENERAL,
    food_categories: list[str] | None = None,
    status: ProductStatus = ProductStatus.UNVERIFIED,
    engine_version: str = ENGINE_VERSION,
    old_version_grade: Grade | None = None,
    **nutrients: str,
) -> Product:
    """A product with nutrition and a stored score (`grade` None: insufficient data).
    `old_version_grade` adds an older nutrition version scored with that grade."""
    amounts: dict[str, Any] = {k: Decimal(v) for k, v in nutrients.items()}
    async with sessions() as session:
        product = await ProductFactory.create(
            session,
            category=category,
            status=status,
            food_categories=SNACKS if food_categories is None else food_categories,
            nova_group=3,
            brand="Brand",
        )
        version = 1
        if old_version_grade is not None:
            old = await NutritionFactsFactory.create(session, product_id=product.id, version=1)
            await ScoreFactory.create(
                session, product_id=product.id, nutrition_facts_id=old.id, grade=old_version_grade
            )
            version = 2
        facts = await NutritionFactsFactory.create(
            session, product_id=product.id, version=version, **amounts
        )
        await ScoreFactory.create(
            session,
            product_id=product.id,
            nutrition_facts_id=facts.id,
            engine_version=engine_version,
            grade=grade,
            total=total,
            breakdown={"grade": grade.value} if grade else {"insufficient_data": ["salt_g"]},
        )
        await session.commit()
        return product


async def alternatives(api: httpx.AsyncClient, ean: str, **params: Any) -> list[str]:
    response = await api.get(f"/v1/products/{ean}/alternatives", params=params)
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["ean"] == ean
    return [item["ean"] for item in body["items"]]


async def test_better_grades_of_the_same_kind_closest_first(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession], off: respx.Route
) -> None:
    product = await seed(sessions, grade=Grade.D, total=15, sugars_g="30")
    near = await seed(sessions, grade=Grade.B, total=2, sugars_g="28")
    far = await seed(sessions, grade=Grade.A, total=-1, sugars_g="2")
    await seed(sessions, grade=Grade.D, total=14, sugars_g="30")  # not better
    await seed(sessions, grade=Grade.E, total=20, sugars_g="30")  # worse

    assert await alternatives(api, product.ean) == [near.ean, far.ean]
    assert not off.called


async def test_item_fields(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    product = await seed(sessions, grade=Grade.C, total=5)
    better = await seed(sessions, grade=Grade.A, total=-2)

    body = (await api.get(f"/v1/products/{product.ean}/alternatives")).json()
    assert body == {
        "ean": product.ean,
        "items": [
            {
                "ean": better.ean,
                "name": better.name,
                "brand": "Brand",
                "grade": "A",
                "total": -2,
                "nova_group": 3,
            }
        ],
    }


async def test_same_category_and_a_shared_food_category_only(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    product = await seed(sessions, grade=Grade.D)
    await seed(sessions, grade=Grade.A, category=Category.CHEESE)
    await seed(sessions, grade=Grade.A, food_categories=["en:sauces"])
    more_shared = await seed(sessions, grade=Grade.B, food_categories=SNACKS)
    less_shared = await seed(sessions, grade=Grade.A, food_categories=["en:snacks"])

    assert await alternatives(api, product.ean) == [more_shared.ean, less_shared.ean]


async def test_product_without_food_categories_compares_by_category(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    product = await seed(sessions, grade=Grade.D, food_categories=[])
    other = await seed(sessions, grade=Grade.B, food_categories=["en:sauces"])

    assert await alternatives(api, product.ean) == [other.ean]


async def test_hidden_outdated_and_ungraded_candidates_are_skipped(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    product = await seed(sessions, grade=Grade.D)
    await seed(sessions, grade=Grade.A, status=ProductStatus.HIDDEN)
    await seed(sessions, grade=Grade.A, engine_version="nutriscore-old")
    await seed(sessions, grade=None)
    # Graded A on an older nutrition version only: its current nutrition is E.
    await seed(sessions, grade=Grade.E, old_version_grade=Grade.A)
    verified = await seed(sessions, grade=Grade.B, status=ProductStatus.VERIFIED)

    assert await alternatives(api, product.ean) == [verified.ean]


async def test_limit(api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]) -> None:
    product = await seed(sessions, grade=Grade.E)
    for _ in range(7):
        await seed(sessions, grade=Grade.B)

    assert len(await alternatives(api, product.ean)) == 5  # default
    assert len(await alternatives(api, product.ean, limit=2)) == 2
    assert len(await alternatives(api, product.ean, limit=20)) == 7


@pytest.mark.parametrize("limit", [0, 21, "x"])
async def test_limit_out_of_range(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession], limit: object
) -> None:
    product = await seed(sessions, grade=Grade.E)
    response = await api.get(f"/v1/products/{product.ean}/alternatives", params={"limit": limit})
    assert response.status_code == 422


@pytest.mark.parametrize(
    ("grade", "category"),
    [(Grade.A, Category.GENERAL), (None, Category.GENERAL), (None, None)],
)
async def test_nothing_better_or_nothing_to_compare(
    api: httpx.AsyncClient,
    sessions: async_sessionmaker[AsyncSession],
    grade: Grade | None,
    category: Category | None,
) -> None:
    product = await seed(sessions, grade=grade, category=category)
    await seed(sessions, grade=Grade.A)

    assert await alternatives(api, product.ean) == []


async def test_upc_a_is_answered_as_ean_13(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    async with sessions() as session:
        product = await ProductFactory.create(
            session, ean="0036000291452", category=Category.GENERAL
        )
        await session.commit()

    response = await api.get("/v1/products/036000291452/alternatives")
    assert response.status_code == 200
    assert response.json()["ean"] == product.ean


async def test_product_scored_on_read_when_its_score_is_missing(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    # Stored nutrition without a score for the current engine: scored like a lookup would
    # (all-zero general food -> A), so nothing is better.
    async with sessions() as session:
        product = await ProductFactory.create(session, category=Category.GENERAL)
        await NutritionFactsFactory.create(session, product_id=product.id)
        await session.commit()
    await seed(sessions, grade=Grade.B)

    assert await alternatives(api, product.ean) == []


async def test_unknown_and_hidden_products_are_404_without_calling_off(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession], off: respx.Route
) -> None:
    hidden = await seed(sessions, grade=Grade.E, status=ProductStatus.HIDDEN)

    for ean in ("6190000000019", hidden.ean):
        response = await api.get(f"/v1/products/{ean}/alternatives")
        assert response.status_code == 404
        assert "not found" in response.json()["detail"]
    assert not off.called


async def test_invalid_barcode_is_422(api: httpx.AsyncClient) -> None:
    response = await api.get("/v1/products/6190000000018/alternatives")
    assert response.status_code == 422
    assert "check digit" in response.json()["detail"]
