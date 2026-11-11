"""Integration fixtures: real Postgres (test database) and Redis from docker compose."""

import asyncio
from collections.abc import AsyncIterator, Callable
from contextlib import AbstractAsyncContextManager, asynccontextmanager

import httpx
import pytest
from fastapi import FastAPI
from pydantic import PostgresDsn, RedisDsn
from pydantic_settings import BaseSettings, SettingsConfigDict
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import create_async_engine

from app.core.config import BACKEND_DIR, REPO_ROOT, Settings
from app.core.health import check_database, check_redis
from app.factory import create_app

STACK_HINT = "Start the local stack first: `docker compose up -d` (repo root)."


class IntegrationEnv(BaseSettings):
    """Connection URLs for integration tests (TEST_DATABASE_URL, never the dev DB)."""

    model_config = SettingsConfigDict(
        env_file=(REPO_ROOT / ".env", BACKEND_DIR / ".env"), extra="ignore"
    )

    test_database_url: PostgresDsn
    redis_url: RedisDsn


def pytest_collection_modifyitems(items: list[pytest.Item]) -> None:
    for item in items:
        item.add_marker(pytest.mark.integration)


@pytest.fixture(scope="session")
def integration_env() -> IntegrationEnv:
    return IntegrationEnv()  # type: ignore[call-arg]


@pytest.fixture(scope="session", autouse=True)
def require_stack(integration_env: IntegrationEnv) -> None:
    """Fail fast with a clear message if Postgres or Redis isn't reachable."""

    async def probe() -> None:
        engine = create_async_engine(str(integration_env.test_database_url))
        redis = Redis.from_url(str(integration_env.redis_url))
        try:
            async with asyncio.timeout(5):
                await check_database(engine)
                await check_redis(redis)
        finally:
            await redis.aclose()
            await engine.dispose()

    try:
        asyncio.run(probe())
    except Exception as exc:
        pytest.fail(f"Integration stack unreachable ({exc!r}). {STACK_HINT}", pytrace=False)


@pytest.fixture
def make_settings(integration_env: IntegrationEnv) -> Callable[..., Settings]:
    """Settings pointing at the test stack, with optional overrides."""

    def _make(**overrides: object) -> Settings:
        values: dict[str, object] = {
            "app_env": "test",
            "database_url": integration_env.test_database_url,
            "redis_url": integration_env.redis_url,
            "readiness_timeout_seconds": 2.0,
        }
        values.update(overrides)
        return Settings(_env_file=None, **values)  # type: ignore[arg-type]

    return _make


@asynccontextmanager
async def running_client(app: FastAPI) -> AsyncIterator[httpx.AsyncClient]:
    """Run the app's lifespan (open/close connections) around an HTTP client."""
    async with app.router.lifespan_context(app):
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            yield client


ClientFactory = Callable[..., AbstractAsyncContextManager[httpx.AsyncClient]]


@pytest.fixture
def client_for(make_settings: Callable[..., Settings]) -> ClientFactory:
    def _client_for(**overrides: object) -> AbstractAsyncContextManager[httpx.AsyncClient]:
        return running_client(create_app(make_settings(**overrides)))

    return _client_for


@pytest.fixture
async def silent_server() -> AsyncIterator[str]:
    """A TCP server that accepts connections and never answers (a hung dependency)."""
    writers: list[asyncio.StreamWriter] = []

    async def handle(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        writers.append(writer)
        await reader.read()  # wait until the client gives up

    server = await asyncio.start_server(handle, host="127.0.0.1", port=0)
    port = server.sockets[0].getsockname()[1]
    try:
        yield f"127.0.0.1:{port}"
    finally:
        server.close()
        for writer in writers:
            writer.close()
        await server.wait_closed()
