"""Background jobs (arq) and the resources they share.

Jobs stay thin: they build the services from the worker context and call them. Bulk
imports run one at a time (a Postgres advisory lock), whichever worker picks them up; a
job that finds another import running is retried later. Every worker start queues a
rescoring for the current engine version (once per version: the job id says which), so
deploying a new engine rescores outdated products. Product photos are copied into our
storage by their own job (every 15 minutes, one run at a time).
"""

import logging
from collections.abc import AsyncIterator
from contextlib import AsyncExitStack, asynccontextmanager
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
from app.core.storage import Storage, open_storage
from app.modules.ingestion.download import download_client
from app.modules.ingestion.importer import ImportResult
from app.modules.ingestion.off_client import RateLimiter, RetryPolicy
from app.modules.ingestion.off_import import ImportSettings, OffImport
from app.modules.products.cache import ProductCache
from app.modules.products.images import ImageCopySettings, ImageCopyStats, ProductImageCopier
from app.modules.products.rescoring import Rescorer, RescoreStats
from app.modules.scoring import ENGINE_VERSION

logger = logging.getLogger(__name__)

IMPORT_LOCK_KEY = 0x516F757401
"""Advisory lock id for bulk imports ("Qout" + 1)."""
IMAGES_LOCK_KEY = 0x516F757402
"""Advisory lock id for the product photo copy ("Qout" + 2)."""
BUSY_RETRY_SECONDS = 600
RESCORE_BATCH_SIZE = 500

Context = dict[str, Any]


class ImportBusyError(Exception):
    """Another run holds the job's lock (a bulk import, or the photo copy)."""


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
    resources = AsyncExitStack()
    ctx["storage"] = await resources.enter_async_context(open_storage(settings))
    ctx["resources"] = resources


async def worker_startup(ctx: Context) -> None:
    """arq `on_startup`: connections, then the rescoring for this engine version."""
    await startup(ctx)
    queued = await ctx["redis"].enqueue_job("rescore_products", _job_id=rescore_job_id())
    if queued is not None:
        logger.info("rescoring queued", extra={"engine_version": ENGINE_VERSION})


def rescore_job_id() -> str:
    return f"rescore:{ENGINE_VERSION}"


async def shutdown(ctx: Context) -> None:
    http: httpx.AsyncClient = ctx["http"]
    cache_redis: Redis = ctx["cache_redis"]
    engine: AsyncEngine = ctx["engine"]
    resources: AsyncExitStack = ctx["resources"]
    await resources.aclose()
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


async def rescore_products(ctx: Context) -> dict[str, int]:
    """Score every product without a score for the current engine version."""
    return asdict(await run_rescore(ctx))


async def copy_product_images(ctx: Context) -> dict[str, int] | None:
    """Copy new and changed product photos into the public bucket (cron, every 15 min).
    Skipped (None) while another copy runs: the next one picks up what is left."""
    try:
        stats = await run_copy_images(ctx)
    except ImportBusyError:
        return None
    return asdict(stats)


async def run_copy_images(ctx: Context) -> ImageCopyStats:
    settings: Settings = ctx["settings"]
    storage: Storage = ctx["storage"]
    copier = ProductImageCopier(
        ctx["sessions"],
        ctx["http"],
        storage.public,
        _cache(ctx),
        ImageCopySettings(
            retry=RetryPolicy(max_retries=settings.off_max_retries),
            max_bytes=settings.product_image_max_bytes,
            limiter=RateLimiter(settings.off_rate_limit_per_minute),
        ),
    )
    async with _exclusive(ctx["engine"], IMAGES_LOCK_KEY):
        return await copier.run()


async def run_rescore(ctx: Context) -> RescoreStats:
    return await Rescorer(ctx["sessions"], batch_size=RESCORE_BATCH_SIZE).run()


async def run_export(ctx: Context, *, force: bool = False) -> ImportResult:
    async with _exclusive(ctx["engine"], IMPORT_LOCK_KEY):
        return await _off_import(ctx).import_export(force=force)


async def run_deltas(ctx: Context) -> list[ImportResult]:
    async with _exclusive(ctx["engine"], IMPORT_LOCK_KEY):
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


def _cache(ctx: Context) -> ProductCache:
    settings: Settings = ctx["settings"]
    return ProductCache(
        ctx["cache_redis"],
        ttl_seconds=settings.product_cache_ttl_seconds,
        not_found_ttl_seconds=settings.product_not_found_ttl_seconds,
    )


def _off_import(ctx: Context) -> OffImport:
    settings: Settings = ctx["settings"]
    sessions: async_sessionmaker[AsyncSession] = ctx["sessions"]
    return OffImport(
        sessions,
        _cache(ctx),
        ctx["http"],
        ImportSettings.from_settings(settings),
        retry=RetryPolicy(max_retries=settings.off_max_retries),
    )


@asynccontextmanager
async def _exclusive(engine: AsyncEngine, key: int) -> AsyncIterator[None]:
    """Hold an advisory lock (session level: it survives the commit below, which keeps
    the connection from idling in a transaction for hours)."""
    async with engine.connect() as connection:
        locked = await connection.scalar(text("SELECT pg_try_advisory_lock(:key)"), {"key": key})
        await connection.commit()
        if not locked:
            logger.info("another run holds the lock", extra={"lock": key})
            raise ImportBusyError
        try:
            yield
        finally:
            await connection.execute(text("SELECT pg_advisory_unlock(:key)"), {"key": key})
            await connection.commit()
