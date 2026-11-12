"""Application settings, loaded from environment variables and `.env` files.

Precedence (highest first): environment variables, `backend/.env`, repo-root `.env`,
field defaults. Fields without a default must be provided.
"""

import re
from functools import lru_cache
from pathlib import Path
from typing import Annotated, Literal

from pydantic import Field, HttpUrl, PostgresDsn, RedisDsn, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parents[2]
REPO_ROOT = BACKEND_DIR.parent

_COUNTRY_TAG = re.compile(r"^[a-z]{2}:[a-z0-9-]+$")

AppEnv = Literal["dev", "test", "staging", "prod"]
LogLevel = Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]


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

    @field_validator("log_level", mode="before")
    @classmethod
    def _uppercase_log_level(cls, value: object) -> object:
        return value.upper() if isinstance(value, str) else value


@lru_cache
def get_settings() -> Settings:
    """Return the process-wide settings, loaded once."""
    return Settings()
