"""`GET /v1/products/{ean}` against real Postgres and Redis; OFF mocked with respx.

These requests commit (as in production), so every test starts and ends with empty
product tables and no cached products.
"""

import asyncio
import json
import re
from collections.abc import AsyncIterator, Callable, Iterator
from pathlib import Path
from typing import Any

import httpx
import pytest
import respx
from redis.asyncio import Redis
from sqlalchemy import Engine, event, func, select, text, update
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.core.config import Settings
from app.factory import create_app
from app.modules.products.cache import ProductCache
from app.modules.products.ean import check_digit
from app.modules.products.lookup import ProductLookup
from app.modules.products.models import (
    NutritionFacts,
    Product,
    ProductStatus,
    Score,
)
from app.modules.scoring import ENGINE_VERSION, Category, Grade
from tests.factories import NutritionFactsFactory, ProductFactory, ScoreFactory
from tests.integration.conftest import IntegrationEnv, running_client

FIXTURES = Path(__file__).resolve().parents[2] / "fixtures" / "off"
OFF_BASE = "https://off.test"
OFF_PRODUCT = re.compile(r"https://off\.test/api/v2/product/(?P<ean>\d+)\.json")
CACHE_PATTERN = "qout:product:*"

NUTELLA = "3017620422003"  # general-complete-spread
WATER = "6194039501011"  # water-tunisian-hayet
NESCAFE = "6111018501480"  # general-no-category: a beverage without nutrition
UNKNOWN = "6190000000019"  # not-found


def off_fixture(name: str) -> tuple[str, dict[str, Any] | None]:
    data = json.loads((FIXTURES / f"{name}.json").read_text(encoding="utf-8"))
    return data["ean"], data["product"]


class FakeOff:
    """OFF API v2 product endpoint serving recorded fixtures; unknown EANs are 404."""

    def __init__(self, router: respx.MockRouter) -> None:
        self.products: dict[str, dict[str, Any]] = {}
        self.down = False
        self.route = router.get(url__regex=OFF_PRODUCT.pattern).mock(side_effect=self._respond)

    def serve(self, *names: str) -> None:
        for name in names:
            ean, product = off_fixture(name)
            if product is not None:
                self.products[ean] = product

    @property
    def calls(self) -> int:
        return self.route.call_count

    def _respond(self, request: httpx.Request, ean: str) -> httpx.Response:
        assert request.headers["User-Agent"].startswith("Qout/")
        if self.down:
            return httpx.Response(503)
        product = self.products.get(ean)
        if product is None:
            return httpx.Response(404, json={"status": 0, "status_verbose": "product not found"})
        return httpx.Response(200, json={"code": ean, "status": 1, "product": product})


# ---------------------------------------------------------------- fixtures


async def _clear(engine: AsyncEngine, redis: Redis) -> None:
    async with engine.begin() as connection:
        await connection.execute(text("TRUNCATE products, scan_events CASCADE"))
    keys = [key async for key in redis.scan_iter(match=CACHE_PATTERN)]
    if keys:
        await redis.delete(*keys)


@pytest.fixture
async def redis(integration_env: IntegrationEnv) -> AsyncIterator[Redis]:
    client = Redis.from_url(str(integration_env.redis_url))
    yield client
    await client.aclose()


@pytest.fixture
async def clean(db_engine: AsyncEngine, redis: Redis) -> AsyncIterator[None]:
    await _clear(db_engine, redis)
    yield
    await _clear(db_engine, redis)


@pytest.fixture
def sessions(db_engine: AsyncEngine, clean: None) -> async_sessionmaker[AsyncSession]:
    """Committing sessions (seed data, read back what the API stored)."""
    return async_sessionmaker(db_engine, expire_on_commit=False)


@pytest.fixture
def off() -> Iterator[FakeOff]:
    with respx.mock(assert_all_called=False) as router:
        yield FakeOff(router)


@pytest.fixture
def lookup_settings(make_settings: Callable[..., Settings]) -> Settings:
    return make_settings(off_base_url=OFF_BASE, off_max_retries=0, off_rate_limit_per_minute=1000)


@pytest.fixture
async def api(
    lookup_settings: Settings, clean: None, off: FakeOff
) -> AsyncIterator[httpx.AsyncClient]:
    async with running_client(create_app(lookup_settings)) as client:
        yield client


class StatementCounter:
    def __init__(self) -> None:
        self.count = 0

    def __call__(self, *_: object) -> None:
        self.count += 1


@pytest.fixture
def statements() -> Iterator[StatementCounter]:
    counter = StatementCounter()
    event.listen(Engine, "before_cursor_execute", counter)
    yield counter
    event.remove(Engine, "before_cursor_execute", counter)


async def count(sessions: async_sessionmaker[AsyncSession], model: type[Any]) -> int:
    async with sessions() as session:
        return await session.scalar(select(func.count()).select_from(model)) or 0


# ---------------------------------------------------------------- OFF hit


async def test_off_hit_is_saved_scored_and_then_served_from_the_db(
    api: httpx.AsyncClient,
    off: FakeOff,
    sessions: async_sessionmaker[AsyncSession],
    redis: Redis,
) -> None:
    off.serve("general-complete-spread")

    response = await api.get(f"/v1/products/{NUTELLA}")

    assert response.status_code == 200
    body = response.json()
    assert (body["ean"], body["name"], body["category"]) == (NUTELLA, "Nutella", "general")
    assert body["source"] == "open_food_facts"
    assert body["quality_flag"] == "complete"
    assert body["nutrition"]["basis"] == "per_100g"
    assert body["nutrition"]["version"] == 1
    assert body["score"]["grade"] == "E"
    assert body["score"]["engine_version"] == ENGINE_VERSION
    assert body["score"]["breakdown"]["grade"] == "E"
    assert off.calls == 1

    async with sessions() as session:
        product = await session.scalar(select(Product).where(Product.ean == NUTELLA))
        assert product is not None
        stored = await session.scalar(select(Score).where(Score.product_id == product.id))
        assert stored is not None
        assert (stored.grade, stored.off_grade) == (Grade.E, Grade.E)
    assert await count(sessions, NutritionFacts) == 1

    # Not from the cache: from our database, without asking OFF again.
    await redis.delete(*[key async for key in redis.scan_iter(match=CACHE_PATTERN)])
    again = await api.get(f"/v1/products/{NUTELLA}")
    assert again.json() == body
    assert off.calls == 1
    assert await count(sessions, Score) == 1


async def test_water_is_graded_a_without_points(api: httpx.AsyncClient, off: FakeOff) -> None:
    off.serve("water-tunisian-hayet")
    body = (await api.get(f"/v1/products/{WATER}")).json()
    assert body["category"] == "water"
    assert (body["score"]["grade"], body["score"]["total"]) == ("A", None)
    assert body["score"]["breakdown"] == {"grade": "A"}


async def test_unknown_category_is_stored_without_a_score(
    api: httpx.AsyncClient, off: FakeOff, sessions: async_sessionmaker[AsyncSession]
) -> None:
    off.serve("edited-no-classification")
    response = await api.get(f"/v1/products/{NUTELLA}")
    assert response.status_code == 200
    assert (response.json()["category"], response.json()["score"]) == (None, None)
    assert await count(sessions, Product) == 1
    assert await count(sessions, Score) == 0


async def test_no_nutrition_is_insufficient_data(api: httpx.AsyncClient, off: FakeOff) -> None:
    off.serve("general-no-category")
    body = (await api.get(f"/v1/products/{NESCAFE}")).json()
    assert (body["category"], body["nutrition"]) == ("beverage", None)
    assert body["score"]["grade"] is None
    assert "sugars_g" in body["score"]["breakdown"]["insufficient_data"]


# ---------------------------------------------------------------- DB hit


async def test_db_hit_does_not_call_off(
    api: httpx.AsyncClient, off: FakeOff, sessions: async_sessionmaker[AsyncSession]
) -> None:
    async with sessions() as session:
        product = await ProductFactory.create(session, category=Category.GENERAL)
        facts = await NutritionFactsFactory.create(session, product_id=product.id)
        await ScoreFactory.create(session, product_id=product.id, nutrition_facts_id=facts.id)
        await session.commit()

    response = await api.get(f"/v1/products/{product.ean}")

    assert response.status_code == 200
    assert response.json()["name"] == product.name
    assert response.json()["score"]["breakdown"] == {"grade": "B"}  # the stored score
    assert off.calls == 0


async def test_outdated_score_is_recomputed_and_keeps_off_grade(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    async with sessions() as session:
        product = await ProductFactory.create(session, category=Category.GENERAL)
        facts = await NutritionFactsFactory.create(session, product_id=product.id)
        await ScoreFactory.create(
            session,
            product_id=product.id,
            nutrition_facts_id=facts.id,
            engine_version="nutriscore-2023.1",
            off_grade=Grade.B,
        )
        await session.commit()

    body = (await api.get(f"/v1/products/{product.ean}")).json()

    # All-zero general food: 0 points, grade A. The stored B was the old version's.
    assert (body["score"]["engine_version"], body["score"]["grade"]) == (ENGINE_VERSION, "A")
    assert body["score"]["total"] == 0
    async with sessions() as session:
        current = await session.scalar(select(Score).where(Score.engine_version == ENGINE_VERSION))
        assert current is not None
        assert current.off_grade == Grade.B
    assert await count(sessions, Score) == 2


async def test_new_nutrition_version_is_scored(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    async with sessions() as session:
        product = await ProductFactory.create(session, category=Category.GENERAL)
        old = await NutritionFactsFactory.create(session, product_id=product.id)
        await ScoreFactory.create(session, product_id=product.id, nutrition_facts_id=old.id)
        await NutritionFactsFactory.create(session, product_id=product.id, version=2)
        await session.commit()

    body = (await api.get(f"/v1/products/{product.ean}")).json()

    assert body["nutrition"]["version"] == 2
    assert body["score"]["breakdown"]["score"] == 0
    assert await count(sessions, Score) == 2


async def test_hidden_product_is_404_without_calling_off(
    api: httpx.AsyncClient, off: FakeOff, sessions: async_sessionmaker[AsyncSession]
) -> None:
    async with sessions() as session:
        product = await ProductFactory.create(session, status=ProductStatus.HIDDEN)
        await session.commit()
    response = await api.get(f"/v1/products/{product.ean}")
    assert response.status_code == 404
    assert off.calls == 0


async def test_upc_a_finds_the_stored_ean_13(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    upc_body = "03600029145"
    upc_a = f"{upc_body}{check_digit(upc_body)}"
    async with sessions() as session:
        await ProductFactory.create(session, ean=f"0{upc_a}")
        await session.commit()

    by_upc = await api.get(f"/v1/products/{upc_a}")
    by_ean = await api.get(f"/v1/products/0{upc_a}")

    assert by_upc.status_code == 200
    assert by_upc.json() == by_ean.json()
    assert by_upc.json()["ean"] == f"0{upc_a}"


# ---------------------------------------------------------------- misses and failures


async def test_off_miss_is_404_and_remembered(
    api: httpx.AsyncClient, off: FakeOff, sessions: async_sessionmaker[AsyncSession]
) -> None:
    first = await api.get(f"/v1/products/{UNKNOWN}")
    second = await api.get(f"/v1/products/{UNKNOWN}")

    assert (first.status_code, second.status_code) == (404, 404)
    assert off.calls == 1
    assert await count(sessions, Product) == 0


async def test_off_down_is_503_with_retry_after(api: httpx.AsyncClient, off: FakeOff) -> None:
    off.serve("general-complete-spread")
    off.down = True

    response = await api.get(f"/v1/products/{NUTELLA}")

    assert response.status_code == 503
    assert response.headers["Retry-After"] == "30"

    off.down = False  # nothing was cached: the next request asks OFF again
    assert (await api.get(f"/v1/products/{NUTELLA}")).status_code == 200


async def test_off_down_does_not_affect_stored_products(
    api: httpx.AsyncClient, off: FakeOff, sessions: async_sessionmaker[AsyncSession]
) -> None:
    off.down = True
    async with sessions() as session:
        product = await ProductFactory.create(session)
        await session.commit()
    assert (await api.get(f"/v1/products/{product.ean}")).status_code == 200


async def test_invalid_ean_is_422_without_any_lookup(
    api: httpx.AsyncClient, off: FakeOff, statements: StatementCounter
) -> None:
    response = await api.get("/v1/products/3017620422004")
    assert response.status_code == 422
    assert "wrong check digit" in response.json()["detail"]
    assert (off.calls, statements.count) == (0, 0)


# ---------------------------------------------------------------- cache


async def test_cache_hit_avoids_the_database(
    api: httpx.AsyncClient, off: FakeOff, statements: StatementCounter
) -> None:
    off.serve("general-complete-spread")
    first = await api.get(f"/v1/products/{NUTELLA}")
    statements.count = 0

    second = await api.get(f"/v1/products/{NUTELLA}")

    assert second.json() == first.json()
    assert statements.count == 0
    assert off.calls == 1


async def test_invalidate_drops_the_cached_product(
    api: httpx.AsyncClient,
    sessions: async_sessionmaker[AsyncSession],
    redis: Redis,
    lookup_settings: Settings,
) -> None:
    async with sessions() as session:
        product = await ProductFactory.create(session, name="Old name")
        await session.commit()
    await api.get(f"/v1/products/{product.ean}")
    async with sessions() as session:
        await session.execute(
            update(Product).where(Product.id == product.id).values(name="New name")
        )
        await session.commit()

    assert (await api.get(f"/v1/products/{product.ean}")).json()["name"] == "Old name"
    cache = ProductCache(
        redis,
        ttl_seconds=lookup_settings.product_cache_ttl_seconds,
        not_found_ttl_seconds=lookup_settings.product_not_found_ttl_seconds,
    )
    await cache.invalidate(product.ean)
    assert (await api.get(f"/v1/products/{product.ean}")).json()["name"] == "New name"


async def test_cached_entry_expires(
    make_settings: Callable[..., Settings], clean: None, off: FakeOff, redis: Redis
) -> None:
    settings = make_settings(off_base_url=OFF_BASE, product_cache_ttl_seconds=123)
    off.serve("general-complete-spread")
    async with running_client(create_app(settings)) as client:
        await client.get(f"/v1/products/{NUTELLA}")
    keys = [key async for key in redis.scan_iter(match=CACHE_PATTERN)]
    assert len(keys) == 1
    assert 0 < await redis.ttl(keys[0]) <= 123


# ---------------------------------------------------------------- concurrency


class BarrierSource:
    """Answers only once `parties` lookups are waiting, so they all miss the DB first."""

    def __init__(self, product: dict[str, Any], parties: int) -> None:
        self._product = product
        self._barrier = asyncio.Barrier(parties)

    async def get_product(self, ean: str) -> dict[str, Any] | None:
        assert ean == self._product["code"]
        await self._barrier.wait()
        return self._product


async def test_concurrent_first_lookups_store_one_product(
    sessions: async_sessionmaker[AsyncSession], redis: Redis
) -> None:
    ean, product = off_fixture("general-complete-spread")
    assert product is not None
    source = BarrierSource(product, parties=2)
    cache = ProductCache(redis, ttl_seconds=60, not_found_ttl_seconds=60)

    async def lookup() -> Any:
        async with sessions() as session:
            return await ProductLookup(session, source, cache).lookup(ean)

    first, second = await asyncio.wait_for(asyncio.gather(lookup(), lookup()), timeout=10)

    assert first == second
    assert await count(sessions, Product) == 1
    assert await count(sessions, NutritionFacts) == 1
    assert await count(sessions, Score) == 1


class NoSource:
    async def get_product(self, ean: str) -> dict[str, Any] | None:
        raise AssertionError(f"OFF must not be asked for a stored product ({ean})")


async def wait_for_lock_wait(sessions: async_sessionmaker[AsyncSession]) -> None:
    """Return once some connection is blocked on a lock."""
    async with asyncio.timeout(10):
        while True:
            async with sessions() as session:
                waiting = await session.scalar(
                    text("SELECT count(*) FROM pg_locks WHERE NOT granted")
                )
            if waiting:
                return
            await asyncio.sleep(0.02)


async def test_concurrent_rescoring_keeps_the_first_score(
    sessions: async_sessionmaker[AsyncSession], redis: Redis
) -> None:
    async with sessions() as session:
        product = await ProductFactory.create(session, category=Category.GENERAL)
        facts = await NutritionFactsFactory.create(session, product_id=product.id)
        await session.commit()
    cache = ProductCache(redis, ttl_seconds=60, not_found_ttl_seconds=60)

    async with sessions() as first:
        # The first writer has inserted the current score but not committed yet.
        winner = await ScoreFactory.create(
            first, product_id=product.id, nutrition_facts_id=facts.id, total=0
        )

        async def second_lookup() -> Any:
            async with sessions() as session:
                return await ProductLookup(session, NoSource(), cache).lookup(product.ean)

        second = asyncio.create_task(second_lookup())
        await wait_for_lock_wait(sessions)  # its insert waits on the unique constraint
        await first.commit()
        result = await asyncio.wait_for(second, timeout=10)

    assert result.score is not None
    assert result.score.computed_at == winner.created_at
    assert result.score.breakdown == winner.breakdown
    assert await count(sessions, Score) == 1
