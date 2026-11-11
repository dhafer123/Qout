import asyncio
import logging
from typing import cast

import pytest
from redis.asyncio import Redis

from app.core.health import check_redis, run_checks


async def ok() -> None:
    return None


async def fails() -> None:
    raise ConnectionRefusedError("nope")


async def hangs() -> None:
    await asyncio.sleep(10)


async def test_all_ok() -> None:
    assert await run_checks({"a": ok, "b": ok}, timeout_s=1) == {"a": "ok", "b": "ok"}


async def test_reports_error_and_timeout_per_check(caplog: pytest.LogCaptureFixture) -> None:
    caplog.set_level(logging.WARNING)

    results = await run_checks({"good": ok, "bad": fails, "slow": hangs}, timeout_s=0.05)

    assert results == {"good": "ok", "bad": "error", "slow": "timeout"}
    by_check = {r.__dict__["check"]: r for r in caplog.records}
    assert by_check["bad"].exc_info is not None
    assert by_check["slow"].getMessage() == "readiness check timed out"


async def test_checks_run_concurrently() -> None:
    loop = asyncio.get_running_loop()
    started = loop.time()

    await run_checks({f"slow{i}": hangs for i in range(5)}, timeout_s=0.1)

    assert loop.time() - started < 0.4


async def test_no_checks_means_nothing_to_report() -> None:
    assert await run_checks({}, timeout_s=1) == {}


class FakeRedis:
    def __init__(self, reply: bool) -> None:
        self.reply = reply

    async def ping(self) -> bool:
        return self.reply


async def test_check_redis_accepts_pong() -> None:
    await check_redis(cast(Redis, FakeRedis(reply=True)))


async def test_check_redis_rejects_falsy_reply() -> None:
    with pytest.raises(ConnectionError):
        await check_redis(cast(Redis, FakeRedis(reply=False)))
