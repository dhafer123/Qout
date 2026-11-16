"""The arq job queue, shared by the worker and the API (which queues jobs for it)."""

from datetime import timedelta
from typing import Any, Protocol

from arq.connections import RedisSettings

from app.core.config import Settings

QUEUE_NAME = "qout:queue"


def redis_settings(settings: Settings) -> RedisSettings:
    return RedisSettings.from_dsn(str(settings.redis_url))


class JobQueue(Protocol):
    """What the API needs from `arq.connections.ArqRedis`."""

    async def enqueue_job(
        self,
        function: str,
        *args: Any,
        _job_id: str | None = None,
        _expires: float | timedelta | None = None,
    ) -> object | None:
        """Queue `function(*args)`; None if a job with `_job_id` already exists."""
        ...
