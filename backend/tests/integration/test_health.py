"""Health endpoints against real Postgres and Redis, plus simulated outages."""

import importlib

import pytest

from app.core.config import get_settings
from app.core.request_id import REQUEST_ID_HEADER
from tests.integration.conftest import ClientFactory, IntegrationEnv

# Port 1 on localhost: nothing listens there, so connections are refused immediately.
CLOSED_PORT = "127.0.0.1:1"


def with_host(url: object, host_port: str) -> str:
    """Replace the host:port of a DSN, keeping scheme, credentials and path."""
    scheme, rest = str(url).split("://", 1)
    credentials, _, after_host = rest.rpartition("@")
    path = after_host.split("/", 1)[1] if "/" in after_host else ""
    prefix = f"{credentials}@" if credentials else ""
    return f"{scheme}://{prefix}{host_port}/{path}"


async def test_health_ok(client_for: ClientFactory) -> None:
    async with client_for() as client:
        response = await client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


async def test_ready_with_real_database_and_redis(client_for: ClientFactory) -> None:
    async with client_for() as client:
        response = await client.get("/health/ready")

    assert response.status_code == 200
    assert response.json() == {"status": "ready", "checks": {"database": "ok", "redis": "ok"}}


async def test_ready_returns_503_when_database_is_down(
    client_for: ClientFactory, integration_env: IntegrationEnv
) -> None:
    db_down = with_host(integration_env.test_database_url, CLOSED_PORT)

    async with client_for(database_url=db_down) as client:
        response = await client.get("/health/ready")

    assert response.status_code == 503
    assert response.json() == {
        "status": "not_ready",
        "checks": {"database": "error", "redis": "ok"},
    }


async def test_ready_returns_503_when_redis_is_down(
    client_for: ClientFactory, integration_env: IntegrationEnv
) -> None:
    redis_down = with_host(integration_env.redis_url, CLOSED_PORT)

    async with client_for(redis_url=redis_down) as client:
        response = await client.get("/health/ready")

    assert response.status_code == 503
    assert response.json()["checks"] == {"database": "ok", "redis": "error"}


async def test_ready_times_out_on_hung_database(
    client_for: ClientFactory, integration_env: IntegrationEnv, silent_server: str
) -> None:
    hung_db = with_host(integration_env.test_database_url, silent_server)

    async with client_for(database_url=hung_db, readiness_timeout_seconds=0.3) as client:
        response = await client.get("/health/ready")

    assert response.status_code == 503
    assert response.json()["checks"] == {"database": "timeout", "redis": "ok"}


async def test_request_id_round_trips(client_for: ClientFactory) -> None:
    async with client_for() as client:
        response = await client.get("/health/ready", headers={REQUEST_ID_HEADER: "it-42"})

    assert response.headers[REQUEST_ID_HEADER] == "it-42"


def test_main_module_builds_app_from_environment(
    monkeypatch: pytest.MonkeyPatch, integration_env: IntegrationEnv
) -> None:
    monkeypatch.setenv("DATABASE_URL", str(integration_env.test_database_url))
    monkeypatch.setenv("REDIS_URL", str(integration_env.redis_url))
    get_settings.cache_clear()
    try:
        main = importlib.import_module("app.main")
        main = importlib.reload(main)
        assert main.app.title == "Qout API"
    finally:
        get_settings.cache_clear()
