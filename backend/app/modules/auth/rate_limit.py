"""Fixed-window counters in Redis, for the login and registration limits.

A key counts events for `window` seconds from its first event. Redis being down must not
lock everybody out: errors are logged and the request is allowed (the limits slow down
guessing; passwords are still checked).
"""

import logging
from dataclasses import dataclass

from redis.asyncio import Redis
from redis.exceptions import RedisError

logger = logging.getLogger(__name__)

_PREFIX = "qout:ratelimit:"


@dataclass(frozen=True)
class Limit:
    allowed: bool
    retry_after: int
    """Seconds until the window ends (0 when allowed)."""


class RateLimiter:
    def __init__(self, redis: Redis) -> None:
        self._redis = redis

    async def hit(self, key: str, *, limit: int, window: int) -> Limit:
        """Counts one event; allowed while the count stays within `limit`."""
        try:
            async with self._redis.pipeline(transaction=True) as pipe:
                pipe.incr(_PREFIX + key)
                pipe.expire(_PREFIX + key, window, nx=True)
                pipe.ttl(_PREFIX + key)
                count, _, ttl = await pipe.execute()
        except RedisError:
            logger.warning("rate limiter unavailable, allowing", extra={"key": key})
            return Limit(allowed=True, retry_after=0)
        if int(count) <= limit:
            return Limit(allowed=True, retry_after=0)
        return Limit(allowed=False, retry_after=max(int(ttl), 1))

    async def check(self, key: str, *, limit: int) -> Limit:
        """Whether the count has reached `limit`, without counting."""
        try:
            async with self._redis.pipeline(transaction=True) as pipe:
                pipe.get(_PREFIX + key)
                pipe.ttl(_PREFIX + key)
                count, ttl = await pipe.execute()
        except RedisError:
            logger.warning("rate limiter unavailable, allowing", extra={"key": key})
            return Limit(allowed=True, retry_after=0)
        if count is None or int(count) < limit:
            return Limit(allowed=True, retry_after=0)
        return Limit(allowed=False, retry_after=max(int(ttl), 1))

    async def reset(self, key: str) -> None:
        try:
            await self._redis.delete(_PREFIX + key)
        except RedisError:
            logger.warning("rate limiter unavailable, not reset", extra={"key": key})
