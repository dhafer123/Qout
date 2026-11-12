"""Open Food Facts client: retries, timeouts, rate limiting (respx, no network)."""

from collections.abc import AsyncIterator, Iterator
from typing import Any

import httpx
import pytest
import respx

from app.core.config import Settings
from app.modules.ingestion.off_client import (
    PRODUCT_FIELDS,
    OffClient,
    OffRequestError,
    OffUnavailableError,
    RateLimiter,
    RetryPolicy,
)

BASE = "https://off.test"
EAN = "6194001800104"
URL = f"{BASE}/api/v2/product/{EAN}.json"
USER_AGENT = "Qout/0.1 (https://github.com/dhafer123/Qout)"
FOUND = {"code": EAN, "status": 1, "product": {"code": EAN, "product_name": "Harissa"}}


class FakeSleep:
    """Records requested waits instead of sleeping."""

    def __init__(self) -> None:
        self.waits: list[float] = []

    async def __call__(self, seconds: float) -> None:
        self.waits.append(seconds)


@pytest.fixture
def sleep() -> FakeSleep:
    return FakeSleep()


@pytest.fixture
async def client(sleep: FakeSleep) -> AsyncIterator[OffClient]:
    http = httpx.AsyncClient(base_url=BASE, headers={"User-Agent": USER_AGENT})
    retry = RetryPolicy(max_retries=3, backoff_base_seconds=0.5, sleep=sleep, jitter=lambda: 0.5)
    async with OffClient(http, retry=retry) as off:
        yield off


@pytest.fixture
def mock() -> Iterator[respx.MockRouter]:
    with respx.mock(assert_all_called=False) as router:
        yield router


# ---------------------------------------------------------------- responses


async def test_found(client: OffClient, mock: respx.MockRouter) -> None:
    route = mock.get(URL).respond(200, json=FOUND)
    assert await client.get_product(EAN) == FOUND["product"]

    request = route.calls.last.request
    assert request.headers["User-Agent"] == USER_AGENT
    assert request.url.params["fields"] == ",".join(PRODUCT_FIELDS)


async def test_not_found_as_404(client: OffClient, mock: respx.MockRouter) -> None:
    mock.get(URL).respond(404, json={"status": 0, "status_verbose": "product not found"})
    assert await client.get_product(EAN) is None


@pytest.mark.parametrize(
    "body",
    [
        {"status": 0, "status_verbose": "product not found"},
        {"status": 1},
        {"status": 1, "product": "oops"},
    ],
)
async def test_not_found_as_200(
    client: OffClient, mock: respx.MockRouter, body: dict[str, Any]
) -> None:
    mock.get(URL).respond(200, json=body)
    assert await client.get_product(EAN) is None


@pytest.mark.parametrize("content", [b"<html>maintenance</html>", b"[1, 2]"])
async def test_unusable_body(client: OffClient, mock: respx.MockRouter, content: bytes) -> None:
    mock.get(URL).respond(200, content=content)
    with pytest.raises(OffUnavailableError, match="OFF returned"):
        await client.get_product(EAN)


# ---------------------------------------------------------------- retries


async def test_retries_server_errors_then_succeeds(
    client: OffClient, mock: respx.MockRouter, sleep: FakeSleep
) -> None:
    route = mock.get(URL)
    route.side_effect = [httpx.Response(503), httpx.Response(502), httpx.Response(200, json=FOUND)]
    assert await client.get_product(EAN) == FOUND["product"]
    assert route.call_count == 3
    assert sleep.waits == [0.5, 1.0]  # base x 2^attempt, jitter factor 1.0


async def test_retries_timeouts_and_connection_errors(
    client: OffClient, mock: respx.MockRouter, sleep: FakeSleep
) -> None:
    route = mock.get(URL)
    route.side_effect = [
        httpx.ReadTimeout("slow"),
        httpx.ConnectError("refused"),
        httpx.ConnectTimeout("slow connect"),
        httpx.Response(200, json=FOUND),
    ]
    assert await client.get_product(EAN) == FOUND["product"]
    assert sleep.waits == [0.5, 1.0, 2.0]


async def test_gives_up_after_max_retries(
    client: OffClient, mock: respx.MockRouter, sleep: FakeSleep
) -> None:
    route = mock.get(URL).respond(500)
    with pytest.raises(OffUnavailableError, match="after 4 attempts: HTTP 500"):
        await client.get_product(EAN)
    assert route.call_count == 4
    assert len(sleep.waits) == 3


async def test_gives_up_on_repeated_timeouts(client: OffClient, mock: respx.MockRouter) -> None:
    mock.get(URL).side_effect = httpx.ReadTimeout("slow")
    with pytest.raises(OffUnavailableError, match="timeout"):
        await client.get_product(EAN)


async def test_429_honours_retry_after(
    client: OffClient, mock: respx.MockRouter, sleep: FakeSleep
) -> None:
    route = mock.get(URL)
    route.side_effect = [
        httpx.Response(429, headers={"Retry-After": "7"}),
        httpx.Response(429, headers={"Retry-After": "3600"}),
        httpx.Response(429, headers={"Retry-After": "Wed, 21 Oct 2026 07:28:00 GMT"}),
        httpx.Response(200, json=FOUND),
    ]
    assert await client.get_product(EAN) == FOUND["product"]
    # 7 s as asked; 3600 s capped to 30 s; an HTTP date falls back to the backoff.
    assert sleep.waits == [7.0, 30.0, 2.0]


async def test_negative_retry_after_is_ignored(
    client: OffClient, mock: respx.MockRouter, sleep: FakeSleep
) -> None:
    mock.get(URL).side_effect = [
        httpx.Response(503, headers={"Retry-After": "-5"}),
        httpx.Response(200, json=FOUND),
    ]
    await client.get_product(EAN)
    assert sleep.waits == [0.5]


@pytest.mark.parametrize("status", [400, 401, 403, 410, 422])
async def test_client_errors_are_not_retried(
    client: OffClient, mock: respx.MockRouter, sleep: FakeSleep, status: int
) -> None:
    route = mock.get(URL).respond(status)
    with pytest.raises(OffRequestError, match=f"HTTP {status}"):
        await client.get_product(EAN)
    assert route.call_count == 1
    assert sleep.waits == []


async def test_no_retries_when_disabled(mock: respx.MockRouter, sleep: FakeSleep) -> None:
    route = mock.get(URL).respond(503)
    http = httpx.AsyncClient(base_url=BASE)
    async with OffClient(http, retry=RetryPolicy(max_retries=0, sleep=sleep)) as off:
        with pytest.raises(OffUnavailableError, match="after 1 attempts"):
            await off.get_product(EAN)
    assert route.call_count == 1


def test_backoff_jitter_range() -> None:
    low = RetryPolicy(backoff_base_seconds=1, jitter=lambda: 0.0)
    high = RetryPolicy(backoff_base_seconds=1, jitter=lambda: 0.999)
    assert [low.backoff(n) for n in range(3)] == [0.5, 1.0, 2.0]
    assert high.backoff(2) == pytest.approx(5.996)


# ---------------------------------------------------------------- rate limiting


class FakeClock:
    def __init__(self) -> None:
        self.now = 1000.0
        self.waits: list[float] = []

    def __call__(self) -> float:
        return self.now

    async def sleep(self, seconds: float) -> None:
        self.waits.append(seconds)
        self.now += seconds


async def test_rate_limiter_spaces_calls() -> None:
    clock = FakeClock()
    limiter = RateLimiter(per_minute=120, clock=clock, sleep=clock.sleep)  # every 0.5 s
    for _ in range(4):
        await limiter.acquire()
    assert clock.waits == [0.5, 0.5, 0.5]


async def test_rate_limiter_does_not_wait_after_a_pause() -> None:
    clock = FakeClock()
    limiter = RateLimiter(per_minute=60, clock=clock, sleep=clock.sleep)
    await limiter.acquire()
    clock.now += 5  # idle longer than the interval
    await limiter.acquire()
    await limiter.acquire()
    assert clock.waits == [1.0]


async def test_client_uses_the_limiter(mock: respx.MockRouter, sleep: FakeSleep) -> None:
    clock = FakeClock()
    mock.get(URL).respond(200, json=FOUND)
    limiter = RateLimiter(per_minute=60, clock=clock, sleep=clock.sleep)
    http = httpx.AsyncClient(base_url=BASE)
    async with OffClient(http, retry=RetryPolicy(sleep=sleep), limiter=limiter) as off:
        await off.get_product(EAN)
        await off.get_product(EAN)
    assert clock.waits == [1.0]


# ---------------------------------------------------------------- settings


async def test_from_settings() -> None:
    settings = Settings(
        _env_file=None,  # type: ignore[call-arg]
        database_url="postgresql+asyncpg://u:p@localhost:5432/db",  # type: ignore[arg-type]
        redis_url="redis://localhost:6379/0",  # type: ignore[arg-type]
        off_base_url="https://off.test",  # type: ignore[arg-type]
        off_timeout_seconds=2.0,
        off_max_retries=1,
        off_rate_limit_per_minute=30,
    )
    off = OffClient.from_settings(settings)
    try:
        http = off._http
        assert str(http.base_url) == "https://off.test/"
        assert http.headers["User-Agent"] == settings.off_user_agent
        assert (http.timeout.read, http.timeout.connect) == (2.0, 2.0)
        assert off._retry.max_retries == 1
        assert off._limiter is not None
    finally:
        await off.aclose()
