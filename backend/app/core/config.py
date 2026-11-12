"""Application settings, loaded from environment variables and `.env` files.

Precedence (highest first): environment variables, `backend/.env`, repo-root `.env`,
field defaults. Fields without a default must be provided.
"""

from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import Field, HttpUrl, PostgresDsn, RedisDsn, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parents[2]
REPO_ROOT = BACKEND_DIR.parent

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

    @field_validator("off_user_agent")
    @classmethod
    def _real_user_agent(cls, value: str) -> str:
        if not value.strip() or "example.com" in value:
            msg = "OFF_USER_AGENT must name the app and a real contact, e.g. Qout/0.1 (URL)"
            raise ValueError(msg)
        return value

    @field_validator("log_level", mode="before")
    @classmethod
    def _uppercase_log_level(cls, value: object) -> object:
        return value.upper() if isinstance(value, str) else value


@lru_cache
def get_settings() -> Settings:
    """Return the process-wide settings, loaded once."""
    return Settings()
