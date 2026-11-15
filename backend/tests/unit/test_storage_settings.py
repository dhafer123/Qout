"""Object storage and upload settings."""

import pytest
from pydantic import ValidationError

from app.core.config import DEV_S3_ACCESS_KEY, DEV_S3_SECRET_KEY, Settings
from app.core.storage import media_url

REAL_JWT = "a-real-jwt-secret-of-at-least-32-characters"


def settings(**values: object) -> Settings:
    base: dict[str, object] = {
        "database_url": "postgresql+asyncpg://user:pw@db.example:5432/qout",
        "redis_url": "redis://cache.example:6379/0",
    }
    return Settings(_env_file=None, **(base | values))  # type: ignore[arg-type]


@pytest.fixture(autouse=True)
def clean_env(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in (
        "APP_ENV",
        "S3_ENDPOINT_URL",
        "S3_PUBLIC_ENDPOINT_URL",
        "S3_ACCESS_KEY",
        "S3_SECRET_KEY",
        "S3_REGION",
        "S3_BUCKET",
        "S3_PUBLIC_BUCKET",
        "MEDIA_BASE_URL",
        "UPLOAD_MAX_BYTES",
        "UPLOAD_URL_TTL_SECONDS",
        "UPLOAD_MAX_PER_USER",
        "UPLOAD_WINDOW_SECONDS",
    ):
        monkeypatch.delenv(name, raising=False)


def test_defaults_match_the_local_stack() -> None:
    loaded = settings()

    assert str(loaded.s3_endpoint_url) == "http://localhost:9000/"
    assert loaded.s3_public_endpoint_url is None
    assert str(loaded.s3_presign_endpoint_url) == "http://localhost:9000/"
    assert loaded.s3_access_key.get_secret_value() == DEV_S3_ACCESS_KEY
    assert loaded.s3_secret_key.get_secret_value() == DEV_S3_SECRET_KEY
    assert (loaded.s3_bucket, loaded.s3_public_bucket) == ("qout-uploads", "qout-public")
    assert str(loaded.media_base_url) == "http://localhost:9000/qout-public/"
    assert loaded.upload_max_bytes == 8 * 1024 * 1024
    assert loaded.upload_url_ttl_seconds == 300
    assert (loaded.upload_max_per_user, loaded.upload_window_seconds) == (30, 3600)


def test_public_endpoint_is_used_for_presigning(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("S3_PUBLIC_ENDPOINT_URL", "http://192.168.1.20:9000")

    assert str(settings().s3_presign_endpoint_url) == "http://192.168.1.20:9000/"


@pytest.mark.parametrize("value", ["", "  "])
def test_empty_public_endpoint_means_unset(monkeypatch: pytest.MonkeyPatch, value: str) -> None:
    monkeypatch.setenv("S3_PUBLIC_ENDPOINT_URL", value)

    assert settings().s3_public_endpoint_url is None


def test_media_base_url_is_a_folder() -> None:
    loaded = settings(media_base_url="https://media.qout.example/photos")

    assert str(loaded.media_base_url) == "https://media.qout.example/photos/"
    assert media_url(loaded, "products/a.jpg") == "https://media.qout.example/photos/products/a.jpg"


def test_buckets_must_differ() -> None:
    with pytest.raises(ValidationError, match="S3_PUBLIC_BUCKET"):
        settings(s3_bucket="same-bucket", s3_public_bucket="same-bucket")


@pytest.mark.parametrize("name", ["A", "ab", "Upper-Case", "under_score", "-dash-first"])
def test_invalid_bucket_names(name: str) -> None:
    with pytest.raises(ValidationError):
        settings(s3_bucket=name)


@pytest.mark.parametrize("env", ["staging", "prod"])
@pytest.mark.parametrize(
    "keys",
    [
        {},
        {"s3_access_key": "real-access-key"},
        {"s3_secret_key": "real-secret-key"},
    ],
)
def test_dev_keys_are_refused_when_deployed(env: str, keys: dict[str, str]) -> None:
    with pytest.raises(ValidationError, match="S3_ACCESS_KEY"):
        settings(app_env=env, jwt_secret=REAL_JWT, **keys)


@pytest.mark.parametrize("env", ["staging", "prod"])
def test_real_keys_are_accepted_when_deployed(env: str) -> None:
    loaded = settings(
        app_env=env,
        jwt_secret=REAL_JWT,
        s3_access_key="real-access-key",
        s3_secret_key="real-secret-key",
    )

    assert loaded.app_env == env


@pytest.mark.parametrize(
    "values",
    [
        {"upload_max_bytes": 1023},
        {"upload_url_ttl_seconds": 29},
        {"upload_url_ttl_seconds": 3601},
        {"upload_max_per_user": 0},
        {"upload_window_seconds": 0},
    ],
)
def test_upload_limits_are_bounded(values: dict[str, int]) -> None:
    with pytest.raises(ValidationError):
        settings(**values)
