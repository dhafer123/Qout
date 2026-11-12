"""Fixtures for bulk-import tests: committing sessions on clean tables, Redis, OFF files.

Imports commit (as in production), so tables are truncated before and after each test.
"""

import gzip
import json
from collections.abc import AsyncIterator, Callable
from pathlib import Path
from typing import Any

import pytest
from redis.asyncio import Redis
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.modules.products.cache import ProductCache
from tests.integration.conftest import IntegrationEnv

FIXTURES = Path(__file__).resolve().parents[2] / "fixtures"
EXPORT = FIXTURES / "off_export" / "export.jsonl"
CACHE_PATTERN = "qout:product:*"
TUNISIA = frozenset({"en:tunisia"})

# Products sold in Tunisia in the fixture export
RICOTTA = "6191585700226"
OLIVE_OIL = "6191509900855"
WATER = "6194039501011"
NUTELLA = "3017620422003"
NESCAFE = "6111018501480"
TUNISIAN = {RICOTTA, OLIVE_OIL, WATER, NUTELLA, NESCAFE}


def export_lines() -> list[str]:
    return EXPORT.read_text(encoding="utf-8").splitlines()


def edit_product(lines: list[str], ean: str, **changes: Any) -> list[str]:
    """`lines` with the product `ean` changed (nested `nutriments` merged)."""
    edited = []
    for line in lines:
        try:
            product = json.loads(line)
        except ValueError:
            edited.append(line)
            continue
        if isinstance(product, dict) and product.get("code") == ean:
            nutriments = {**product.get("nutriments", {}), **changes.get("nutriments", {})}
            product.update(changes)
            product["nutriments"] = nutriments
            edited.append(json.dumps(product))
        else:
            edited.append(line)
    return edited


@pytest.fixture
def write_gz(tmp_path: Path) -> Callable[..., Path]:
    def _write(lines: list[str], name: str = "export.jsonl.gz") -> Path:
        path = tmp_path / name
        with gzip.open(path, "wt", encoding="utf-8") as file:
            file.write("\n".join(lines) + "\n")
        return path

    return _write


async def _clear(engine: AsyncEngine, redis: Redis) -> None:
    async with engine.begin() as connection:
        await connection.execute(text("TRUNCATE products, scan_events, import_runs CASCADE"))
    keys = [key async for key in redis.scan_iter(match=CACHE_PATTERN)]
    if keys:
        await redis.delete(*keys)


@pytest.fixture
async def redis(integration_env: IntegrationEnv) -> AsyncIterator[Redis]:
    client = Redis.from_url(str(integration_env.redis_url))
    yield client
    await client.aclose()


@pytest.fixture
async def sessions(
    db_engine: AsyncEngine, redis: Redis
) -> AsyncIterator[async_sessionmaker[AsyncSession]]:
    await _clear(db_engine, redis)
    yield async_sessionmaker(db_engine, expire_on_commit=False)
    await _clear(db_engine, redis)


@pytest.fixture
def cache(redis: Redis) -> ProductCache:
    return ProductCache(redis, ttl_seconds=60, not_found_ttl_seconds=60)
