"""Open Food Facts API client (read-only product lookups).

- Every request sends the configured User-Agent (OFF requires AppName/Version (contact)).
- Timeouts: connect at most 3 s, read `off_timeout_seconds`.
- Retries timeouts, connection errors, 429 and 5xx with exponential backoff and jitter,
  honouring `Retry-After`; other 4xx are not retried.
- A per-process rate limiter spaces requests evenly (`off_rate_limit_per_minute`).

The client returns OFF's raw `product` object; turning it into our schema is the
normaliser's job (`off_normaliser`).
"""

import asyncio
import random
import time
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from types import TracebackType
from typing import Any, Self

import httpx

from app.core.config import Settings

# Only what the normaliser reads, to keep responses small.
PRODUCT_FIELDS = (
    "code",
    "product_name",
    "product_name_fr",
    "product_name_ar",
    "generic_name",
    "brands",
    "image_front_url",
    "nova_group",
    "additives_tags",
    "categories_tags",
    "nutriments",
    "nutrition_data_per",
    "no_nutrition_data",
    "nutriscore",
    "nutriscore_grade",
    "nutriscore_version",
)

_RETRY_STATUSES = frozenset({429, 500, 502, 503, 504})
_MAX_RETRY_AFTER_SECONDS = 30.0
_CONNECT_TIMEOUT_SECONDS = 3.0

Sleep = Callable[[float], Awaitable[None]]
Clock = Callable[[], float]


class OffError(Exception):
    """Base class for Open Food Facts client errors."""


class OffUnavailableError(OffError):
    """OFF could not be reached or kept failing after all retries."""


class OffRequestError(OffError):
    """OFF rejected the request (4xx other than 404/429): retrying would not help."""


class RateLimiter:
    """Spaces calls at least `60 / per_minute` seconds apart (no bursts)."""

    def __init__(
        self, per_minute: int, *, clock: Clock = time.monotonic, sleep: Sleep = asyncio.sleep
    ) -> None:
        self._interval = 60.0 / per_minute
        self._clock = clock
        self._sleep = sleep
        self._next_slot = float("-inf")
        self._lock = asyncio.Lock()

    async def acquire(self) -> None:
        async with self._lock:
            now = self._clock()
            wait = self._next_slot - now
            if wait > 0:
                await self._sleep(wait)
            self._next_slot = max(now, self._next_slot) + self._interval


@dataclass(frozen=True)
class RetryPolicy:
    """How failed requests are retried: `max_retries` extra attempts, waiting
    base x 2^attempt x [0.5, 1.5) between them (or the server's `Retry-After`)."""

    max_retries: int = 3
    backoff_base_seconds: float = 0.5
    sleep: Sleep = asyncio.sleep
    jitter: Callable[[], float] = random.random

    def backoff(self, attempt: int) -> float:
        return float(self.backoff_base_seconds * 2**attempt * (0.5 + self.jitter()))


class OffClient:
    def __init__(
        self,
        http: httpx.AsyncClient,
        *,
        retry: RetryPolicy | None = None,
        limiter: RateLimiter | None = None,
    ) -> None:
        self._http = http
        self._retry = retry or RetryPolicy()
        self._limiter = limiter

    @classmethod
    def from_settings(cls, settings: Settings) -> Self:
        http = httpx.AsyncClient(
            base_url=str(settings.off_base_url),
            headers={"User-Agent": settings.off_user_agent, "Accept": "application/json"},
            timeout=httpx.Timeout(
                settings.off_timeout_seconds,
                connect=min(_CONNECT_TIMEOUT_SECONDS, settings.off_timeout_seconds),
            ),
        )
        return cls(
            http,
            retry=RetryPolicy(max_retries=settings.off_max_retries),
            limiter=RateLimiter(settings.off_rate_limit_per_minute),
        )

    async def aclose(self) -> None:
        await self._http.aclose()

    async def __aenter__(self) -> Self:
        return self

    async def __aexit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        await self.aclose()

    async def get_product(self, ean: str) -> dict[str, Any] | None:
        """OFF's `product` object for `ean`, or None if OFF does not know the product."""
        response = await self._request(
            f"/api/v2/product/{ean}.json", params={"fields": ",".join(PRODUCT_FIELDS)}
        )
        if response.status_code == httpx.codes.NOT_FOUND:
            return None
        try:
            body = response.json()
        except ValueError as error:
            raise OffUnavailableError(f"OFF returned invalid JSON for {ean}") from error
        if not isinstance(body, dict):
            raise OffUnavailableError(f"OFF returned an unexpected body for {ean}")
        product = body.get("product")
        if body.get("status") != 1 or not isinstance(product, dict):
            return None  # "product not found" can also come as 200 with status 0
        return product

    async def _request(self, url: str, *, params: dict[str, str]) -> httpx.Response:
        attempt = 0
        while True:
            if self._limiter is not None:
                await self._limiter.acquire()
            failure: str
            retry_after: float | None = None
            try:
                response = await self._http.get(url, params=params)
            except httpx.TimeoutException:
                failure = "timeout"
            except httpx.TransportError as error:
                failure = f"connection error ({type(error).__name__})"
            else:
                status = response.status_code
                if status < httpx.codes.BAD_REQUEST or status == httpx.codes.NOT_FOUND:
                    return response
                if status not in _RETRY_STATUSES:
                    raise OffRequestError(f"OFF rejected {url}: HTTP {status}")
                failure = f"HTTP {status}"
                retry_after = _retry_after(response)

            if attempt >= self._retry.max_retries:
                raise OffUnavailableError(
                    f"OFF unavailable after {attempt + 1} attempts: {failure}"
                )
            delay = retry_after if retry_after is not None else self._retry.backoff(attempt)
            await self._retry.sleep(delay)
            attempt += 1


def _retry_after(response: httpx.Response) -> float | None:
    """`Retry-After` in seconds (delta form only), capped; None if absent or unusable."""
    value = response.headers.get("Retry-After")
    if value is None:
        return None
    try:
        seconds = float(value)
    except ValueError:
        return None
    if seconds < 0:
        return None
    return min(seconds, _MAX_RETRY_AFTER_SECONDS)
