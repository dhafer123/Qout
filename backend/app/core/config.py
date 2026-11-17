"""Application settings, loaded from environment variables and `.env` files.

Precedence (highest first): environment variables, `backend/.env`, repo-root `.env`,
field defaults. Fields without a default must be provided.
"""

import re
from functools import lru_cache
from pathlib import Path
from typing import Annotated, Literal

from pydantic import (
    Field,
    HttpUrl,
    PostgresDsn,
    RedisDsn,
    SecretStr,
    field_validator,
    model_validator,
)
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parents[2]
REPO_ROOT = BACKEND_DIR.parent

_COUNTRY_TAG = re.compile(r"^[a-z]{2}:[a-z0-9-]+$")

AppEnv = Literal["dev", "test", "staging", "prod"]

DEV_JWT_SECRET = "dev-only-jwt-secret-never-use-in-staging-or-prod"  # noqa: S105 - refused outside dev/test
"""Lets dev and tests run without configuration; refused in staging and prod."""
_MIN_JWT_SECRET_LENGTH = 32
DEV_S3_ACCESS_KEY = "qout-dev-access-key"
DEV_S3_SECRET_KEY = "qout-dev-secret-key"  # noqa: S105 - local RustFS only, refused when deployed
_BUCKET_NAME = r"^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$"
LogLevel = Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
_LLM_KEY_PLACEHOLDERS = frozenset({"dummy-key"})


class Settings(BaseSettings):
    """Runtime configuration. Immutable once loaded."""

    model_config = SettingsConfigDict(
        # Later files take priority over earlier ones.
        env_file=(REPO_ROOT / ".env", BACKEND_DIR / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
        frozen=True,
    )

    app_env: AppEnv = "dev"
    log_level: LogLevel = "INFO"
    database_url: PostgresDsn
    database_pool_size: int = Field(default=5, ge=1, le=100)
    database_max_overflow: int = Field(default=10, ge=0, le=100)
    redis_url: RedisDsn
    readiness_timeout_seconds: float = Field(default=2.0, gt=0, le=30)

    # Open Food Facts (called from the backend only). OFF asks every client to send a
    # User-Agent naming the app and a contact: AppName/Version (contact).
    off_base_url: HttpUrl = HttpUrl("https://world.openfoodfacts.org")
    off_user_agent: str = "Qout/0.1 (https://github.com/dhafer123/Qout)"
    off_timeout_seconds: float = Field(default=10.0, gt=0, le=60)
    off_max_retries: int = Field(default=3, ge=0, le=10)
    off_rate_limit_per_minute: int = Field(default=100, ge=1, le=1000)

    # Product lookup cache (Redis). Unknown barcodes are remembered for less time, so a
    # product added to OFF later shows up soon.
    product_cache_ttl_seconds: int = Field(default=86_400, ge=1)
    product_not_found_ttl_seconds: int = Field(default=600, ge=1)

    # Bulk import from Open Food Facts files (worker). Countries are OFF country tags,
    # comma-separated in the environment: `en:tunisia,en:algeria` (`tunisia` also works).
    import_countries: Annotated[frozenset[str], NoDecode] = frozenset({"en:tunisia"})
    import_batch_size: int = Field(default=500, ge=1, le=10_000)
    import_download_dir: Path = BACKEND_DIR / "var" / "imports"
    """A relative path is taken from `backend/`, wherever the worker is started."""
    off_export_url: HttpUrl = HttpUrl(
        "https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz"
    )
    off_delta_url: HttpUrl = HttpUrl("https://static.openfoodfacts.org/data/delta/")
    """Folder holding `index.txt` and the delta files."""
    import_delta_cron_enabled: bool = True
    import_delta_cron_hour: int = Field(default=4, ge=0, le=23)
    """Hour (UTC) of the daily delta import."""

    # Auth (contributors only; scanning needs no account).
    jwt_secret: SecretStr = SecretStr(DEV_JWT_SECRET)
    """HS256 key for access tokens: at least 32 characters, a real secret outside dev/test."""
    access_token_ttl_seconds: int = Field(default=900, ge=60, le=3600)
    refresh_token_ttl_days: int = Field(default=30, ge=1, le=365)
    login_max_failures_per_email: int = Field(default=5, ge=1, le=100)
    """Failed logins for one email per window before 429."""
    login_max_attempts_per_ip: int = Field(default=20, ge=1, le=1000)
    """Login attempts (failed or not) from one IP per window before 429."""
    login_window_seconds: int = Field(default=900, ge=1, le=86_400)
    register_max_per_ip: int = Field(default=5, ge=1, le=1000)
    register_window_seconds: int = Field(default=3600, ge=1, le=86_400)

    # Object storage: any S3-compatible service (RustFS locally, ADR 0002), path-style.
    s3_endpoint_url: HttpUrl = HttpUrl("http://localhost:9000")
    s3_public_endpoint_url: HttpUrl | None = None
    """Host written into presigned upload URLs, which the phone calls directly (the host is
    signed). Unset: `s3_endpoint_url`. Set it when the phone can't reach that address."""
    s3_access_key: SecretStr = SecretStr(DEV_S3_ACCESS_KEY)
    s3_secret_key: SecretStr = SecretStr(DEV_S3_SECRET_KEY)
    s3_region: str = Field(default="us-east-1", min_length=1)
    s3_bucket: str = Field(default="qout-uploads", pattern=_BUCKET_NAME)
    """Private: contribution photos."""
    s3_public_bucket: str = Field(default="qout-public", pattern=_BUCKET_NAME)
    """Readable by anyone: product photos shown in the app."""
    media_base_url: HttpUrl = HttpUrl("http://localhost:9000/qout-public/")
    """Where the public bucket's objects are served from (the bucket, a CDN, ...)."""

    # Contribution photo uploads (presigned PUT URLs).
    upload_max_bytes: int = Field(default=8 * 1024 * 1024, ge=1024, le=100 * 1024 * 1024)
    upload_url_ttl_seconds: int = Field(default=300, ge=30, le=3600)
    upload_max_per_user: int = Field(default=30, ge=1, le=10_000)
    """Upload URLs one user may request per window before 429."""
    upload_window_seconds: int = Field(default=3600, ge=1, le=86_400)

    # "Report an error": new reports from one IP per window before 429.
    report_max_per_ip: int = Field(default=20, ge=1, le=10_000)
    report_window_seconds: int = Field(default=3600, ge=1, le=86_400)

    # Product photos: copied from Open Food Facts into the public bucket (worker).
    product_image_max_bytes: int = Field(default=2 * 1024 * 1024, ge=1024, le=20 * 1024 * 1024)
    product_images_cron_enabled: bool = True
    """Copy new and changed product photos every 15 minutes."""

    # LLM fallback for nutrition labels the rule-based parser can't read (T28), on the
    # Google Gemini API. Only the label's OCR text is sent. Off by default; needs a real
    # Gemini API key when on.
    llm_parser_enabled: bool = False
    llm_api_key: SecretStr = SecretStr("")
    llm_model: str = Field(default="gemini-3.8-flash", min_length=1)
    llm_timeout_seconds: float = Field(default=30.0, gt=0, le=300)
    """One reading, including the SDK's retries."""
    llm_parse_deadline_seconds: int = Field(default=90, ge=10, le=3600)
    """A fallback not finished this long after it was asked for (queue wait included) is
    given up: the contributor enters the values by hand."""
    llm_parse_max_per_user: int = Field(default=20, ge=1, le=10_000)
    """LLM readings one user may ask for per window; beyond, manual entry."""
    llm_parse_window_seconds: int = Field(default=3600, ge=1, le=86_400)

    # Daily cleanup (worker): what contributions leave behind, and how long it is kept.
    cleanup_cron_enabled: bool = True
    cleanup_cron_hour: int = Field(default=3, ge=0, le=23)
    """Hour (UTC) of the daily cleanup."""
    unsubmitted_upload_retention_days: int = Field(default=7, ge=1, le=365)
    """Uploaded photos no contribution refers to are deleted this long after the upload.
    The app's outbox submits soon after uploading, but only while the app is open."""
    rejected_photo_retention_days: int = Field(default=30, ge=1, le=3650)
    """Photos of a rejected contribution are deleted this long after the rejection."""
    label_fallback_retention_days: int = Field(default=7, ge=1, le=3650)
    """LLM fallback requests (they hold the label's OCR text) are deleted this long after
    they were asked for (the app waits for an answer for 90 s at most)."""

    @field_validator("off_user_agent")
    @classmethod
    def _real_user_agent(cls, value: str) -> str:
        if not value.strip() or "example.com" in value:
            msg = "OFF_USER_AGENT must name the app and a real contact, e.g. Qout/0.1 (URL)"
            raise ValueError(msg)
        return value

    @field_validator("import_countries", mode="before")
    @classmethod
    def _country_tags(cls, value: object) -> object:
        if not isinstance(value, str):
            return value
        tags = {t.strip().lower() for t in value.split(",") if t.strip()}
        return {t if ":" in t else f"en:{t}" for t in tags}

    @field_validator("import_countries")
    @classmethod
    def _valid_country_tags(cls, value: frozenset[str]) -> frozenset[str]:
        if not value:
            raise ValueError("IMPORT_COUNTRIES needs at least one country")
        invalid = sorted(t for t in value if not _COUNTRY_TAG.match(t))
        if invalid:
            msg = f"IMPORT_COUNTRIES: not OFF country tags: {invalid} (e.g. en:tunisia)"
            raise ValueError(msg)
        return value

    @field_validator("import_download_dir")
    @classmethod
    def _from_backend_dir(cls, value: Path) -> Path:
        return value if value.is_absolute() else BACKEND_DIR / value

    @field_validator("off_delta_url")
    @classmethod
    def _folder_url(cls, value: HttpUrl) -> HttpUrl:
        text = str(value)
        return value if text.endswith("/") else HttpUrl(f"{text}/")

    @field_validator("jwt_secret")
    @classmethod
    def _long_jwt_secret(cls, value: SecretStr) -> SecretStr:
        if len(value.get_secret_value()) < _MIN_JWT_SECRET_LENGTH:
            msg = f"JWT_SECRET must be at least {_MIN_JWT_SECRET_LENGTH} characters"
            raise ValueError(msg)
        return value

    @model_validator(mode="after")
    def _real_jwt_secret_when_deployed(self) -> "Settings":
        secret = self.jwt_secret.get_secret_value()
        if self.app_env in ("staging", "prod") and (
            secret == DEV_JWT_SECRET or secret.startswith("change-me")
        ):
            msg = "JWT_SECRET: set a real random secret in staging and prod"
            raise ValueError(msg)
        return self

    @model_validator(mode="after")
    def _real_s3_keys_when_deployed(self) -> "Settings":
        if self.app_env in ("staging", "prod") and (
            self.s3_access_key.get_secret_value() == DEV_S3_ACCESS_KEY
            or self.s3_secret_key.get_secret_value() == DEV_S3_SECRET_KEY
        ):
            msg = "S3_ACCESS_KEY / S3_SECRET_KEY: set real credentials in staging and prod"
            raise ValueError(msg)
        return self

    @model_validator(mode="after")
    def _separate_buckets(self) -> "Settings":
        if self.s3_bucket == self.s3_public_bucket:
            msg = "S3_PUBLIC_BUCKET must differ from S3_BUCKET (contribution photos are private)"
            raise ValueError(msg)
        return self

    @model_validator(mode="after")
    def _llm_key_when_enabled(self) -> "Settings":
        if self.llm_parser_enabled and not has_llm_key(self):
            msg = "LLM_PARSER_ENABLED needs a real LLM_API_KEY"
            raise ValueError(msg)
        return self

    @model_validator(mode="after")
    def _llm_deadline_after_timeout(self) -> "Settings":
        if self.llm_parse_deadline_seconds <= self.llm_timeout_seconds:
            msg = "LLM_PARSE_DEADLINE_SECONDS must be longer than LLM_TIMEOUT_SECONDS"
            raise ValueError(msg)
        return self

    @field_validator("s3_public_endpoint_url", mode="before")
    @classmethod
    def _empty_is_unset(cls, value: object) -> object:
        return None if isinstance(value, str) and not value.strip() else value

    @field_validator("media_base_url")
    @classmethod
    def _media_folder_url(cls, value: HttpUrl) -> HttpUrl:
        text = str(value)
        return value if text.endswith("/") else HttpUrl(f"{text}/")

    @property
    def s3_presign_endpoint_url(self) -> HttpUrl:
        return self.s3_public_endpoint_url or self.s3_endpoint_url

    @field_validator("log_level", mode="before")
    @classmethod
    def _uppercase_log_level(cls, value: object) -> object:
        return value.upper() if isinstance(value, str) else value


def has_llm_key(settings: Settings) -> bool:
    """False for an empty key or a placeholder (`.env.example`'s `dummy-key`, `change-me...`)."""
    key = settings.llm_api_key.get_secret_value().strip()
    return bool(key) and key not in _LLM_KEY_PLACEHOLDERS and not key.startswith("change-me")


@lru_cache
def get_settings() -> Settings:
    """Return the process-wide settings, loaded once."""
    return Settings()
