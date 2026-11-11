"""Health endpoints with fake readiness checks (no external services)."""

from collections.abc import AsyncIterator, Mapping

import httpx
import pytest
from fastapi import FastAPI

from app.api.health import get_readiness_checks
from app.core.config import Settings
from app.core.health import ReadinessCheck
from app.core.request_id import REQUEST_ID_HEADER
from app.factory import create_app


async def ok() -> None:
    return None


async def fails() -> None:
    raise ConnectionRefusedError("down")


@pytest.fixture
def app() -> FastAPI:
    settings = Settings(
        _env_file=None,
        database_url="postgresql+asyncpg://u:p@localhost:1/x",  # type: ignore[arg-type]
        redis_url="redis://localhost:1/0",  # type: ignore[arg-type]
        readiness_timeout_seconds=0.5,
    )
    return create_app(settings)


@pytest.fixture
async def client(app: FastAPI) -> AsyncIterator[httpx.AsyncClient]:
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


def use_checks(app: FastAPI, checks: Mapping[str, ReadinessCheck]) -> None:
    app.dependency_overrides[get_readiness_checks] = lambda: checks


async def test_health_is_ok_without_dependencies(client: httpx.AsyncClient) -> None:
    response = await client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    assert REQUEST_ID_HEADER in response.headers


async def test_ready_when_all_checks_pass(app: FastAPI, client: httpx.AsyncClient) -> None:
    use_checks(app, {"database": ok, "redis": ok})

    response = await client.get("/health/ready")

    assert response.status_code == 200
    assert response.json() == {"status": "ready", "checks": {"database": "ok", "redis": "ok"}}


async def test_not_ready_when_any_check_fails(app: FastAPI, client: httpx.AsyncClient) -> None:
    use_checks(app, {"database": fails, "redis": ok})

    response = await client.get("/health/ready")

    assert response.status_code == 503
    assert response.json() == {
        "status": "not_ready",
        "checks": {"database": "error", "redis": "ok"},
    }


async def test_endpoints_are_in_openapi_spec(client: httpx.AsyncClient) -> None:
    spec = (await client.get("/openapi.json")).json()

    assert {"/health", "/health/ready"} <= set(spec["paths"])
    assert "503" in spec["paths"]["/health/ready"]["get"]["responses"]
