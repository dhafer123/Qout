"""arq worker configuration, built from the application settings."""

from datetime import UTC, timedelta
from typing import Any

from arq import cron
from arq.connections import RedisSettings
from arq.worker import func

from app.core.config import Settings
from app.worker import jobs

QUEUE_NAME = "qout:queue"
EXPORT_TIMEOUT = timedelta(hours=12)
"""Download (~14 GB) plus a pass over every line of the export."""
DELTA_TIMEOUT = timedelta(hours=2)
RESCORE_TIMEOUT = timedelta(hours=2)
KEEP_RESULT = timedelta(days=1)
MAX_TRIES = 5
"""Runs of a job interrupted by a worker restart, or retried because another import was
running. Interrupted imports resume from their checkpoint."""


def redis_settings(settings: Settings) -> RedisSettings:
    return RedisSettings.from_dsn(str(settings.redis_url))


def worker_settings(settings: Settings, *, queue_name: str = QUEUE_NAME) -> dict[str, Any]:
    """Keyword arguments for `arq.Worker` (the arq CLI accepts this dict as settings)."""
    cron_jobs = []
    if settings.import_delta_cron_enabled:
        cron_jobs.append(
            cron(
                jobs.import_off_deltas,
                hour={settings.import_delta_cron_hour},
                minute={0},
                second={0},
                timeout=DELTA_TIMEOUT,
                max_tries=MAX_TRIES,
                unique=True,
            )
        )
    return {
        "functions": [
            func(
                jobs.import_off_export,
                timeout=EXPORT_TIMEOUT,
                keep_result=KEEP_RESULT,
                max_tries=MAX_TRIES,
            ),
            func(
                jobs.import_off_deltas,
                timeout=DELTA_TIMEOUT,
                keep_result=KEEP_RESULT,
                max_tries=MAX_TRIES,
            ),
            func(
                jobs.rescore_products,
                timeout=RESCORE_TIMEOUT,
                keep_result=KEEP_RESULT,
                max_tries=MAX_TRIES,
            ),
        ],
        "cron_jobs": cron_jobs,
        "redis_settings": redis_settings(settings),
        "queue_name": queue_name,
        "on_startup": jobs.worker_startup,
        "on_shutdown": jobs.shutdown,
        "ctx": {"settings": settings},
        "timezone": UTC,  # cron hours are UTC
    }
