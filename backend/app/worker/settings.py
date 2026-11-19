"""arq worker configuration, built from the application settings."""

from datetime import UTC, timedelta
from typing import Any

from arq import cron
from arq.worker import func

from app.core.config import Settings
from app.core.queue import QUEUE_NAME, redis_settings
from app.worker import jobs

EXPORT_TIMEOUT = timedelta(hours=12)
"""Download (~14 GB) plus a pass over every line of the export."""
DELTA_TIMEOUT = timedelta(hours=2)
RESCORE_TIMEOUT = timedelta(hours=2)
IMAGES_TIMEOUT = timedelta(hours=2)
CLEANUP_TIMEOUT = timedelta(hours=1)
REFRESH_TIMEOUT = timedelta(hours=6)
"""One OFF request per stored product, at OFF's rate limit."""
KEEP_RESULT = timedelta(days=1)
LABEL_JOB_MARGIN = timedelta(seconds=30)
"""Beyond the LLM time limit: database reads and writes around the call."""
MAX_TRIES = 5
"""Runs of a job interrupted by a worker restart, or retried because another import was
running. Interrupted imports resume from their checkpoint."""


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
    if settings.product_images_cron_enabled:
        cron_jobs.append(
            cron(
                jobs.copy_product_images,
                minute={0, 15, 30, 45},
                second={0},
                timeout=IMAGES_TIMEOUT,
                unique=True,
            )
        )
    if settings.cleanup_cron_enabled:
        cron_jobs.append(
            cron(
                jobs.clean_up,
                hour={settings.cleanup_cron_hour},
                minute={0},
                second={0},
                timeout=CLEANUP_TIMEOUT,
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
            func(jobs.copy_product_images, timeout=IMAGES_TIMEOUT, keep_result=KEEP_RESULT),
            func(jobs.clean_up, timeout=CLEANUP_TIMEOUT, keep_result=KEEP_RESULT),
            func(
                jobs.refresh_off_products,
                timeout=REFRESH_TIMEOUT,
                keep_result=KEEP_RESULT,
                max_tries=MAX_TRIES,
            ),
            func(
                jobs.rescore_products,
                timeout=RESCORE_TIMEOUT,
                keep_result=KEEP_RESULT,
                max_tries=MAX_TRIES,
            ),
            func(
                jobs.parse_label_with_llm,
                timeout=timedelta(seconds=settings.llm_timeout_seconds) + LABEL_JOB_MARGIN,
                keep_result=timedelta(hours=1),
                max_tries=1,  # the contributor is waiting: no retry, manual entry instead
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
