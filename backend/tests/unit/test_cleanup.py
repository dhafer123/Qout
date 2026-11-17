"""The daily cleanup's pure parts: what is old enough, which contribution a key belongs to,
and its settings. The job itself runs against storage and the DB in
`tests/integration/test_cleanup.py`."""

import uuid
from datetime import UTC, datetime, timedelta, timezone

import pytest
from pydantic import ValidationError

from app.core.config import Settings
from app.modules.contributions.cleanup import (
    CleanupSettings,
    contribution_id_of,
    cutoff,
    is_old_enough,
)

NOW = datetime(2026, 11, 17, 3, 0, tzinfo=UTC)
USER = uuid.UUID("0b8a6d3e-6a4f-4c43-9c39-2f4e1c1d9a01")
CONTRIBUTION = uuid.UUID("5f0c2a1b-3d4e-4f60-8a7b-9c0d1e2f3a4b")
REQUIRED = {"database_url": "postgresql+asyncpg://u:p@db:5432/q", "redis_url": "redis://r:6379/0"}


def settings(**overrides: object) -> Settings:
    return Settings(_env_file=None, **{**REQUIRED, **overrides})  # type: ignore[arg-type]


def test_cutoff_is_that_many_days_before_now() -> None:
    assert cutoff(NOW, 7) == datetime(2026, 11, 10, 3, 0, tzinfo=UTC)


@pytest.mark.parametrize(
    ("age", "old"),
    [
        (timedelta(days=7, microseconds=1), True),
        (timedelta(days=30), True),
        (timedelta(days=7), False),  # exactly the limit: kept until the next run
        (timedelta(days=6, hours=23), False),
        (timedelta(0), False),
        (-timedelta(hours=1), False),  # storage clock ahead of ours
    ],
)
def test_old_enough_is_strictly_before_the_cutoff(age: timedelta, *, old: bool) -> None:
    assert is_old_enough(NOW - age, cutoff(NOW, 7)) is old


def test_old_enough_compares_instants_across_time_zones() -> None:
    limit = cutoff(NOW, 7)  # 2026-11-10 03:00 UTC
    tunis = timezone(timedelta(hours=1))
    assert is_old_enough(datetime(2026, 11, 10, 4, 0, tzinfo=tunis), limit) is False  # = limit
    assert is_old_enough(datetime(2026, 11, 10, 3, 59, tzinfo=tunis), limit) is True


def test_contribution_id_from_an_upload_key() -> None:
    key = f"contributions/{USER}/{CONTRIBUTION}/front-0123456789abcdef.jpg"
    assert contribution_id_of(key) == CONTRIBUTION


@pytest.mark.parametrize(
    "key",
    [
        f"products/{USER}/{CONTRIBUTION}/front-0123456789abcdef.jpg",  # another prefix
        f"contributions/{USER}/not-a-uuid/front-0123456789abcdef.jpg",
        f"contributions/{USER}/{CONTRIBUTION}",  # no file
        f"contributions/{USER}/{CONTRIBUTION}/extra/front.jpg",  # too deep
        "contributions/stray.jpg",
        "",
    ],
)
def test_keys_of_another_shape_belong_to_no_contribution(key: str) -> None:
    assert contribution_id_of(key) is None


def test_retention_defaults() -> None:
    config = settings()
    assert (config.cleanup_cron_enabled, config.cleanup_cron_hour) == (True, 3)
    assert CleanupSettings.from_settings(config) == CleanupSettings(
        unsubmitted_upload_days=7, rejected_photo_days=30, label_fallback_days=7
    )


def test_retention_from_settings() -> None:
    config = settings(
        unsubmitted_upload_retention_days=3,
        rejected_photo_retention_days=60,
        label_fallback_retention_days=1,
    )
    assert CleanupSettings.from_settings(config) == CleanupSettings(
        unsubmitted_upload_days=3, rejected_photo_days=60, label_fallback_days=1
    )


@pytest.mark.parametrize(
    "overrides",
    [
        {"unsubmitted_upload_retention_days": 0},
        {"rejected_photo_retention_days": 0},
        {"label_fallback_retention_days": 0},
        {"unsubmitted_upload_retention_days": 366},
        {"cleanup_cron_hour": 24},
        {"cleanup_cron_hour": -1},
    ],
)
def test_invalid_cleanup_settings(overrides: dict[str, object]) -> None:
    with pytest.raises(ValidationError):
        settings(**overrides)
