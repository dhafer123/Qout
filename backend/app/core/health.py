"""Readiness checks for external dependencies. Framework-independent."""

import asyncio
import logging
from collections.abc import Awaitable, Callable, Mapping
from typing import Literal

from redis.asyncio import Redis
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine

CheckStatus = Literal["ok", "error", "timeout"]
ReadinessCheck = Callable[[], Awaitable[None]]

logger = logging.getLogger(__name__)


async def check_database(engine: AsyncEngine) -> None:
    """Raise if the database can't run a trivial query."""
    async with engine.connect() as connection:
        await connection.execute(text("SELECT 1"))


async def check_redis(client: Redis) -> None:
    """Raise if Redis doesn't answer PING."""
    if not await client.ping():
        raise ConnectionError("Redis PING returned a falsy reply")


async def _run_one(name: str, check: ReadinessCheck, timeout_s: float) -> CheckStatus:
    try:
        async with asyncio.timeout(timeout_s):
            await check()
    except TimeoutError:
        logger.warning("readiness check timed out", extra={"check": name, "timeout_s": timeout_s})
        return "timeout"
    except Exception:
        logger.warning("readiness check failed", extra={"check": name}, exc_info=True)
        return "error"
    return "ok"


async def run_checks(
    checks: Mapping[str, ReadinessCheck], timeout_s: float
) -> dict[str, CheckStatus]:
    """Run all checks concurrently, each with its own timeout. Never raises."""
    names = list(checks)
    results = await asyncio.gather(*(_run_one(n, checks[n], timeout_s) for n in names))
    return dict(zip(names, results, strict=True))
