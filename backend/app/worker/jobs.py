"""Background jobs (arq) and the resources they share.

Jobs stay thin: they build the services from the worker context and call them. Bulk
imports run one at a time (a Postgres advisory lock), whichever worker picks them up; a
job that finds another import running is retried later.
"""

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from dataclasses import asdict
from typing import Any

import httpx
from arq import Retry
from redis.asyncio import Redis
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.core.config import Settings, get_settings
from app.core.db import create_engine, create_session_factory
from app.core.logging import configure_logging
from app.modules.ingestion.download import download_client
from app.modules.ingestion.importer import ImportResult
from app.modules.ingestion.off_client import RetryPolicy
from app.modules.ingestion.off_import import ImportSettings, OffImport
from app.modules.products.cache import ProductCache

logger = logging.getLogger(__name__)

IMPORT_LOCK_KEY = 0x516F757401
"""Advisory lock id for bulk imports ("Qout" + 1)."""
BUSY_RETRY_SECONDS = 600

Context = dict[str, Any]


class ImportBusyError(Exception):
    """Another bulk import is running."""


# ---------------------------------------------------------------- worker lifecycle


async def startup(ctx: Context) -> None:
    """Open connections. `ctx["settings"]` may be preset (tests, CLI); else from the env."""
    settings: Settings = ctx.setdefault("settings", get_settings())
    configure_logging(settings.log_level)
    engine = create_engine(settings)
    ctx["engine"] = engine
    ctx["sessions"] = create_session_factory(engine)
    ctx["cache_redis"] = Redis.from_url(str(settings.redis_url))
    ctx["http"] = download_client(settings)


async def shutdown(ctx: Context) -> None:
    http: httpx.AsyncClient = ctx["http"]
    cache_redis: Redis = ctx["cache_redis"]
    engine: AsyncEngine = ctx["engine"]
    await http.aclose()
    await cache_redis.aclose()
    await engine.dispose()


# ---------------------------------------------------------------- jobs


async def import_off_export(ctx: Context, *, force: bool = False) -> dict[str, Any]:
    """Import the current Open Food Facts full export (see `OffImport.import_export`)."""
    try:
        result = await run_export(ctx, force=force)
    except ImportBusyError as error:
        raise Retry(defer=BUSY_RETRY_SECONDS) from error
    return summary(result)


async def import_off_deltas(ctx: Context) -> list[dict[str, Any]]:
    """Import the Open Food Facts delta files not imported yet (daily cron)."""
    try:
        results = await run_deltas(ctx)
    except ImportBusyError as error:
        raise Retry(defer=BUSY_RETRY_SECONDS) from error
    return [summary(result) for result in results]


async def run_export(ctx: Context, *, force: bool = False) -> ImportResult:
    async with _exclusive(ctx["engine"]):
        return await _off_import(ctx).import_export(force=force)


async def run_deltas(ctx: Context) -> list[ImportResult]:
    async with _exclusive(ctx["engine"]):
        return await _off_import(ctx).import_deltas()


def summary(result: ImportResult) -> dict[str, Any]:
    """JSON-friendly result (job results, CLI output)."""
    return {
        "kind": str(result.kind),
        "source": result.source,
        "status": None if result.status is None else str(result.status),
        "resumed_from_line": result.resumed_from_line,
        "stats": None if result.stats is None else asdict(result.stats),
    }


def _off_import(ctx: Context) -> OffImport:
    settings: Settings = ctx["settings"]
    sessions: async_sessionmaker[AsyncSession] = ctx["sessions"]
    cache = ProductCache(
        ctx["cache_redis"],
        ttl_seconds=settings.product_cache_ttl_seconds,
        not_found_ttl_seconds=settings.product_not_found_ttl_seconds,
    )
    return OffImport(
        sessions,
        cache,
        ctx["http"],
        ImportSettings.from_settings(settings),
        retry=RetryPolicy(max_retries=settings.off_max_retries),
    )


@asynccontextmanager
async def _exclusive(engine: AsyncEngine) -> AsyncIterator[None]:
    """Hold the bulk-import lock (session level: it survives the commit below, which
    keeps the connection from idling in a transaction for hours)."""
    async with engine.connect() as connection:
        locked = await connection.scalar(
            text("SELECT pg_try_advisory_lock(:key)"), {"key": IMPORT_LOCK_KEY}
        )
        await connection.commit()
        if not locked:
            logger.info("another bulk import is running")
            raise ImportBusyError
        try:
            yield
        finally:
            await connection.execute(
                text("SELECT pg_advisory_unlock(:key)"), {"key": IMPORT_LOCK_KEY}
            )
            await connection.commit()
