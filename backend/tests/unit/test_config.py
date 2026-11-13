from pathlib import Path

import pytest
from pydantic import ValidationError

from app.core.config import BACKEND_DIR, Settings, get_settings

DB_URL = "postgresql+asyncpg://user:pw@db.example:5432/qout"
REDIS_URL = "redis://cache.example:6379/0"

ENV_VARS = (
    "APP_ENV",
    "LOG_LEVEL",
    "DATABASE_URL",
    "REDIS_URL",
    "READINESS_TIMEOUT_SECONDS",
    "DATABASE_POOL_SIZE",
    "DATABASE_MAX_OVERFLOW",
)


@pytest.fixture(autouse=True)
def clean_env(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in ENV_VARS:
        monkeypatch.delenv(name, raising=False)


def write_env_file(path: Path, **values: str) -> Path:
    path.write_text("".join(f"{k}={v}\n" for k, v in values.items()), encoding="utf-8")
    return path


def test_defaults_apply_when_only_required_fields_are_set(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("DATABASE_URL", DB_URL)
    monkeypatch.setenv("REDIS_URL", REDIS_URL)

    settings = Settings(_env_file=None)

    assert settings.app_env == "dev"
    assert settings.log_level == "INFO"
    assert settings.readiness_timeout_seconds == 2.0
    assert settings.database_pool_size == 5
    assert settings.database_max_overflow == 10
    assert str(settings.database_url) == DB_URL
    assert str(settings.redis_url) == REDIS_URL


def test_missing_required_fields_raise(tmp_path: Path) -> None:
    with pytest.raises(ValidationError) as exc_info:
        Settings(_env_file=None)

    missing = {err["loc"][0] for err in exc_info.value.errors() if err["type"] == "missing"}
    assert missing == {"database_url", "redis_url"}


def test_reads_values_from_env_file(tmp_path: Path) -> None:
    env_file = write_env_file(
        tmp_path / ".env",
        APP_ENV="staging",
        JWT_SECRET="s" * 40,
        LOG_LEVEL="debug",
        DATABASE_URL=DB_URL,
        REDIS_URL=REDIS_URL,
        READINESS_TIMEOUT_SECONDS="0.5",
        UNRELATED_SETTING="ignored",
    )

    settings = Settings(_env_file=env_file)

    assert settings.app_env == "staging"
    assert settings.log_level == "DEBUG"
    assert settings.readiness_timeout_seconds == 0.5


def test_environment_variables_override_env_file(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env_file = write_env_file(
        tmp_path / ".env",
        APP_ENV="staging",
        JWT_SECRET="s" * 40,
        DATABASE_URL=DB_URL,
        REDIS_URL=REDIS_URL,
    )
    monkeypatch.setenv("APP_ENV", "prod")

    assert Settings(_env_file=env_file).app_env == "prod"


def test_later_env_file_overrides_earlier(tmp_path: Path) -> None:
    root_env = write_env_file(
        tmp_path / "root.env", LOG_LEVEL="INFO", DATABASE_URL=DB_URL, REDIS_URL=REDIS_URL
    )
    backend_env = write_env_file(tmp_path / "backend.env", LOG_LEVEL="WARNING")

    assert Settings(_env_file=(root_env, backend_env)).log_level == "WARNING"


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("APP_ENV", "production"),
        ("LOG_LEVEL", "VERBOSE"),
        ("DATABASE_URL", "mysql://user@host/db"),
        ("DATABASE_URL", "not a url"),
        ("REDIS_URL", "http://cache.example"),
        ("READINESS_TIMEOUT_SECONDS", "0"),
        ("READINESS_TIMEOUT_SECONDS", "31"),
        ("DATABASE_POOL_SIZE", "0"),
        ("DATABASE_MAX_OVERFLOW", "-1"),
    ],
)
def test_invalid_values_are_rejected(
    monkeypatch: pytest.MonkeyPatch, field: str, value: str
) -> None:
    monkeypatch.setenv("DATABASE_URL", DB_URL)
    monkeypatch.setenv("REDIS_URL", REDIS_URL)
    monkeypatch.setenv(field, value)

    with pytest.raises(ValidationError):
        Settings(_env_file=None)


def test_settings_are_immutable(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATABASE_URL", DB_URL)
    monkeypatch.setenv("REDIS_URL", REDIS_URL)
    settings = Settings(_env_file=None)

    with pytest.raises(ValidationError):
        settings.app_env = "prod"  # type: ignore[misc]


def test_get_settings_is_cached(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATABASE_URL", DB_URL)
    monkeypatch.setenv("REDIS_URL", REDIS_URL)
    get_settings.cache_clear()
    try:
        assert get_settings() is get_settings()
    finally:
        get_settings.cache_clear()


@pytest.mark.parametrize("agent", ["", "   ", "Qout/0.1 (contact@example.com)"])
def test_placeholder_off_user_agent_is_rejected(
    monkeypatch: pytest.MonkeyPatch, agent: str
) -> None:
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://u:p@localhost:5432/db")
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/0")
    monkeypatch.setenv("OFF_USER_AGENT", agent)
    with pytest.raises(ValidationError, match="OFF_USER_AGENT"):
        Settings(_env_file=None)  # type: ignore[call-arg]


def test_off_defaults(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://u:p@localhost:5432/db")
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/0")
    settings = Settings(_env_file=None)  # type: ignore[call-arg]
    assert str(settings.off_base_url) == "https://world.openfoodfacts.org/"
    assert settings.off_user_agent == "Qout/0.1 (https://github.com/dhafer123/Qout)"
    assert (settings.off_timeout_seconds, settings.off_max_retries) == (10.0, 3)
    assert settings.off_rate_limit_per_minute == 100


@pytest.fixture
def required_env(monkeypatch: pytest.MonkeyPatch) -> pytest.MonkeyPatch:
    monkeypatch.setenv("DATABASE_URL", DB_URL)
    monkeypatch.setenv("REDIS_URL", REDIS_URL)
    for name in (
        "IMPORT_COUNTRIES",
        "OFF_DELTA_URL",
        "IMPORT_DELTA_CRON_HOUR",
        "IMPORT_DOWNLOAD_DIR",
    ):
        monkeypatch.delenv(name, raising=False)
    return monkeypatch


def test_import_defaults(required_env: pytest.MonkeyPatch) -> None:
    settings = Settings(_env_file=None)  # type: ignore[call-arg]
    assert settings.import_countries == {"en:tunisia"}
    assert settings.import_batch_size == 500
    assert settings.import_download_dir.parts[-2:] == ("var", "imports")
    assert str(settings.off_export_url).endswith("/data/openfoodfacts-products.jsonl.gz")
    assert str(settings.off_delta_url) == "https://static.openfoodfacts.org/data/delta/"
    assert (settings.import_delta_cron_enabled, settings.import_delta_cron_hour) == (True, 4)


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("en:tunisia", {"en:tunisia"}),
        (" Tunisia , en:algeria,,", {"en:tunisia", "en:algeria"}),
        ("en:united-kingdom", {"en:united-kingdom"}),
    ],
)
def test_import_countries_from_env(
    required_env: pytest.MonkeyPatch, raw: str, expected: set[str]
) -> None:
    required_env.setenv("IMPORT_COUNTRIES", raw)
    assert Settings(_env_file=None).import_countries == expected  # type: ignore[call-arg]


@pytest.mark.parametrize("raw", ["", " , ", "en:tun isia", 'en:"x"', "en:"])
def test_invalid_import_countries(required_env: pytest.MonkeyPatch, raw: str) -> None:
    required_env.setenv("IMPORT_COUNTRIES", raw)
    with pytest.raises(ValidationError, match="IMPORT_COUNTRIES"):
        Settings(_env_file=None)  # type: ignore[call-arg]


def test_import_countries_as_python_values(required_env: pytest.MonkeyPatch) -> None:
    settings = Settings(_env_file=None, import_countries={"en:tunisia"})  # type: ignore[call-arg]
    assert settings.import_countries == {"en:tunisia"}


def test_delta_url_is_a_folder(required_env: pytest.MonkeyPatch) -> None:
    required_env.setenv("OFF_DELTA_URL", "https://mirror.example/delta")
    assert str(Settings(_env_file=None).off_delta_url) == "https://mirror.example/delta/"  # type: ignore[call-arg]


@pytest.mark.parametrize("hour", ["-1", "24"])
def test_invalid_cron_hour(required_env: pytest.MonkeyPatch, hour: str) -> None:
    required_env.setenv("IMPORT_DELTA_CRON_HOUR", hour)
    with pytest.raises(ValidationError):
        Settings(_env_file=None)  # type: ignore[call-arg]


def test_relative_download_dir_is_under_backend(
    required_env: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    required_env.setenv("IMPORT_DOWNLOAD_DIR", "var/imports")
    assert Settings(_env_file=None).import_download_dir == BACKEND_DIR / "var" / "imports"  # type: ignore[call-arg]
    required_env.setenv("IMPORT_DOWNLOAD_DIR", str(tmp_path))
    assert Settings(_env_file=None).import_download_dir == tmp_path  # type: ignore[call-arg]
