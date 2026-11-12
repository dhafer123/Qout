"""Product cache with fake Redis clients: hits, misses, TTLs, and Redis failures ignored."""

import asyncio
from datetime import UTC, datetime
from typing import Any, cast

import pytest
from redis.asyncio import Redis
from redis.exceptions import ConnectionError as RedisConnectionError

from app.modules.products import cache as cache_module
from app.modules.products.cache import NOT_FOUND, ProductCache, cache_key
from app.modules.products.models import DataSource, ProductStatus
from app.modules.products.schemas import ProductDetail
from app.modules.scoring import ENGINE_VERSION

EAN = "3017620422003"


class FakeRedis:
    def __init__(self) -> None:
        self.data: dict[str, bytes] = {}
        self.ttls: dict[str, int] = {}

    async def get(self, key: str) -> bytes | None:
        return self.data.get(key)

    async def set(self, key: str, value: bytes, ex: int) -> None:
        self.data[key] = value
        self.ttls[key] = ex

    async def delete(self, key: str) -> None:
        self.data.pop(key, None)


class BrokenRedis:
    async def get(self, *_: object) -> Any:
        raise RedisConnectionError("down")

    async def set(self, *_: object, **__: object) -> Any:
        raise RedisConnectionError("down")

    async def delete(self, *_: object) -> Any:
        raise RedisConnectionError("down")


class HangingRedis:
    async def get(self, *_: object) -> Any:
        await asyncio.sleep(10)

    async def set(self, *_: object, **__: object) -> Any:
        await asyncio.sleep(10)

    async def delete(self, *_: object) -> Any:
        await asyncio.sleep(10)


def make_cache(redis: object) -> ProductCache:
    return ProductCache(cast(Redis, redis), ttl_seconds=3600, not_found_ttl_seconds=60)


def detail(ean: str = EAN) -> ProductDetail:
    return ProductDetail(
        ean=ean,
        name="Nutella",
        brand="Ferrero",
        image_url=None,
        category=None,
        source=DataSource.OPEN_FOOD_FACTS,
        status=ProductStatus.UNVERIFIED,
        quality_flag=None,
        nova_group=4,
        additives=[],
        nutrition=None,
        score=None,
        updated_at=datetime(2026, 11, 12, 10, 0, tzinfo=UTC),
    )


def test_key_holds_format_engine_version_and_ean() -> None:
    assert cache_key(EAN) == f"qout:product:v1:{ENGINE_VERSION}:{EAN}"


async def test_miss_then_hit() -> None:
    redis = FakeRedis()
    cache = make_cache(redis)
    assert await cache.get(EAN) is None
    await cache.set(detail())
    assert await cache.get(EAN) == detail()
    assert redis.ttls[cache_key(EAN)] == 3600


async def test_not_found_marker_has_its_own_ttl() -> None:
    redis = FakeRedis()
    cache = make_cache(redis)
    await cache.set_not_found(EAN)
    assert await cache.get(EAN) is NOT_FOUND
    assert redis.ttls[cache_key(EAN)] == 60


async def test_invalidate_forgets_the_product() -> None:
    cache = make_cache(FakeRedis())
    await cache.set(detail())
    await cache.invalidate(EAN)
    assert await cache.get(EAN) is None


async def test_unreadable_entry_is_a_miss_and_is_removed() -> None:
    redis = FakeRedis()
    redis.data[cache_key(EAN)] = b'{"ean": "old shape"}'
    cache = make_cache(redis)
    assert await cache.get(EAN) is None
    assert cache_key(EAN) not in redis.data


@pytest.mark.parametrize("redis", [BrokenRedis(), HangingRedis()], ids=["broken", "hanging"])
async def test_redis_problems_never_fail_the_caller(
    redis: object, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    monkeypatch.setattr(cache_module, "_TIMEOUT_SECONDS", 0.01)
    cache = make_cache(redis)
    assert await cache.get(EAN) is None
    await cache.set(detail())
    await cache.set_not_found(EAN)
    await cache.invalidate(EAN)
    messages = [record.getMessage() for record in caplog.records]
    assert messages == [
        "product cache read failed",
        "product cache write failed",
        "product cache write failed",
        "product cache invalidation failed",
    ]
