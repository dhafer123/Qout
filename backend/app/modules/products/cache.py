"""Redis cache for product lookups.

Stores the whole `ProductDetail` response, plus a short-lived "not found" marker for
barcodes nobody knows. The key holds the engine version and the cache format, so a new
engine (or a new response shape) never reads an old entry; old entries expire on their
own. The cache is an optimisation only: any Redis problem is logged and treated as a miss.
"""

import asyncio
import logging
from enum import Enum

from pydantic import ValidationError
from redis.asyncio import Redis
from redis.exceptions import RedisError

from app.modules.products.schemas import ProductDetail
from app.modules.scoring import ENGINE_VERSION

logger = logging.getLogger(__name__)

CACHE_FORMAT = 1
"""Bump when `ProductDetail` changes shape."""
_NOT_FOUND = b"not_found"
_TIMEOUT_SECONDS = 0.5


class CachedNotFound(Enum):
    """The barcode was looked up recently and is unknown."""

    NOT_FOUND = "not_found"


NOT_FOUND = CachedNotFound.NOT_FOUND


def cache_key(ean: str) -> str:
    return f"qout:product:v{CACHE_FORMAT}:{ENGINE_VERSION}:{ean}"


class ProductCache:
    def __init__(self, redis: Redis, *, ttl_seconds: int, not_found_ttl_seconds: int) -> None:
        self._redis = redis
        self._ttl = ttl_seconds
        self._not_found_ttl = not_found_ttl_seconds

    async def get(self, ean: str) -> ProductDetail | CachedNotFound | None:
        """The cached product, NOT_FOUND, or None on a miss (or any cache problem)."""
        try:
            async with asyncio.timeout(_TIMEOUT_SECONDS):
                raw = await self._redis.get(cache_key(ean))
        except (RedisError, OSError, TimeoutError):
            logger.warning("product cache read failed", extra={"ean": ean}, exc_info=True)
            return None
        if raw is None:
            return None
        if raw == _NOT_FOUND:
            return NOT_FOUND
        try:
            return ProductDetail.model_validate_json(raw)
        except ValidationError:
            logger.warning("unreadable product cache entry", extra={"ean": ean})
            await self.invalidate(ean)
            return None

    async def set(self, product: ProductDetail) -> None:
        await self._write(product.ean, product.model_dump_json().encode(), self._ttl)

    async def set_not_found(self, ean: str) -> None:
        await self._write(ean, _NOT_FOUND, self._not_found_ttl)

    async def invalidate(self, ean: str) -> None:
        """Forget `ean`. Call after any change to the product, its nutrition or score."""
        try:
            async with asyncio.timeout(_TIMEOUT_SECONDS):
                await self._redis.delete(cache_key(ean))
        except (RedisError, OSError, TimeoutError):
            logger.warning("product cache invalidation failed", extra={"ean": ean}, exc_info=True)

    async def _write(self, ean: str, value: bytes, ttl: int) -> None:
        try:
            async with asyncio.timeout(_TIMEOUT_SECONDS):
                await self._redis.set(cache_key(ean), value, ex=ttl)
        except (RedisError, OSError, TimeoutError):
            logger.warning("product cache write failed", extra={"ean": ean}, exc_info=True)
