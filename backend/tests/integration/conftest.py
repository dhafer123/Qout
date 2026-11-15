"""Integration fixtures: real Postgres (test database), Redis and RustFS from docker compose.

Database tests get `db_session`: a session inside an outer transaction that is rolled
back after the test, so every test starts from a clean, migrated `qout_test`. Storage
tests use their own buckets (`TEST_UPLOADS_BUCKET`, `TEST_PUBLIC_BUCKET`), created once
and emptied by the `storage` fixture, never the dev buckets.
"""

import asyncio
import json
from collections.abc import AsyncIterator, Callable, Iterator
from contextlib import AbstractAsyncContextManager, asynccontextmanager
from pathlib import Path
from typing import Any

import httpx
import pytest
from aiobotocore.session import get_session
from alembic import command
from alembic.config import Config
from fastapi import FastAPI
from pydantic import HttpUrl, PostgresDsn, RedisDsn, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict
from redis.asyncio import Redis
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.config import (
    BACKEND_DIR,
    DEV_S3_ACCESS_KEY,
    DEV_S3_SECRET_KEY,
    REPO_ROOT,
    Settings,
)
from app.core.health import check_database, check_redis
from app.core.storage import Storage, open_storage
from app.factory import create_app
from tests.models import TEST_SCHEMA, TestBase

STACK_HINT = "Start the local stack first: `docker compose up -d` (repo root)."
TEST_UPLOADS_BUCKET = "qout-test-uploads"
TEST_PUBLIC_BUCKET = "qout-test-public"


class IntegrationEnv(BaseSettings):
    """Connection URLs for integration tests (TEST_DATABASE_URL, never the dev DB)."""

    model_config = SettingsConfigDict(
        env_file=(REPO_ROOT / ".env", BACKEND_DIR / ".env"), extra="ignore"
    )

    test_database_url: PostgresDsn
    redis_url: RedisDsn
    s3_endpoint_url: HttpUrl = HttpUrl("http://localhost:9000")
    s3_access_key: SecretStr = SecretStr(DEV_S3_ACCESS_KEY)
    s3_secret_key: SecretStr = SecretStr(DEV_S3_SECRET_KEY)
    s3_region: str = "us-east-1"


_INTEGRATION_DIR = Path(__file__).parent


def pytest_collection_modifyitems(items: list[pytest.Item]) -> None:
    # This hook sees every collected test, not only those in this directory.
    for item in items:
        if _INTEGRATION_DIR in item.path.parents:
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
        asyncio.run(_create_test_buckets(integration_env))
    except Exception as exc:
        pytest.fail(f"Integration stack unreachable ({exc!r}). {STACK_HINT}", pytrace=False)


def _s3_client(env: IntegrationEnv) -> Any:
    return get_session().create_client(
        "s3",
        endpoint_url=str(env.s3_endpoint_url).rstrip("/"),
        region_name=env.s3_region,
        aws_access_key_id=env.s3_access_key.get_secret_value(),
        aws_secret_access_key=env.s3_secret_key.get_secret_value(),
    )


async def _create_test_buckets(env: IntegrationEnv) -> None:
    """Create the test buckets (the public one readable by anyone, as in compose)."""
    async with asyncio.timeout(15), _s3_client(env) as client:
        existing = {b["Name"] for b in (await client.list_buckets())["Buckets"]}
        for bucket in (TEST_UPLOADS_BUCKET, TEST_PUBLIC_BUCKET):
            if bucket not in existing:
                await client.create_bucket(Bucket=bucket)
        policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {"AWS": ["*"]},
                    "Action": ["s3:GetObject"],
                    "Resource": [f"arn:aws:s3:::{TEST_PUBLIC_BUCKET}/*"],
                }
            ],
        }
        await client.put_bucket_policy(Bucket=TEST_PUBLIC_BUCKET, Policy=json.dumps(policy))


async def _empty_test_buckets(env: IntegrationEnv) -> None:
    async with _s3_client(env) as client:
        for bucket in (TEST_UPLOADS_BUCKET, TEST_PUBLIC_BUCKET):
            paginator = client.get_paginator("list_objects_v2")
            async for page in paginator.paginate(Bucket=bucket):
                for item in page.get("Contents", []):
                    await client.delete_object(Bucket=bucket, Key=item["Key"])


@pytest.fixture
def make_settings(integration_env: IntegrationEnv) -> Callable[..., Settings]:
    """Settings pointing at the test stack, with optional overrides."""

    def _make(**overrides: object) -> Settings:
        values: dict[str, object] = {
            "app_env": "test",
            "database_url": integration_env.test_database_url,
            "redis_url": integration_env.redis_url,
            "readiness_timeout_seconds": 2.0,
            "s3_endpoint_url": integration_env.s3_endpoint_url,
            "s3_access_key": integration_env.s3_access_key,
            "s3_secret_key": integration_env.s3_secret_key,
            "s3_region": integration_env.s3_region,
            "s3_bucket": TEST_UPLOADS_BUCKET,
            "s3_public_bucket": TEST_PUBLIC_BUCKET,
            "media_base_url": f"{integration_env.s3_endpoint_url}{TEST_PUBLIC_BUCKET}/",
        }
        values.update(overrides)
        return Settings(_env_file=None, **values)  # type: ignore[arg-type]

    return _make


@pytest.fixture
async def storage(
    integration_env: IntegrationEnv, make_settings: Callable[..., Settings]
) -> AsyncIterator[Storage]:
    """Clients for the (emptied) test buckets; emptied again afterwards."""
    await _empty_test_buckets(integration_env)
    async with open_storage(make_settings()) as opened:
        yield opened
    await _empty_test_buckets(integration_env)


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


# ----------------------------------------------------------------------------- database


def alembic_config(database_url: str) -> Config:
    """Alembic config for programmatic use: explicit URL, leave logging alone."""
    config = Config(str(BACKEND_DIR / "alembic.ini"))
    config.attributes["database_url"] = database_url
    config.attributes["configure_logger"] = False
    return config


async def _reset_test_schema(database_url: str, *, create: bool) -> None:
    engine = create_async_engine(database_url, poolclass=NullPool)
    try:
        async with engine.begin() as connection:
            await connection.execute(text(f"DROP SCHEMA IF EXISTS {TEST_SCHEMA} CASCADE"))
            if create:
                await connection.execute(text(f"CREATE SCHEMA {TEST_SCHEMA}"))
                await connection.run_sync(TestBase.metadata.create_all)
    finally:
        await engine.dispose()


@pytest.fixture(scope="session")
def migrated_database(require_stack: None, integration_env: IntegrationEnv) -> Iterator[str]:
    """Upgrade the test database to head once; create test-only tables. Yields its URL."""
    url = str(integration_env.test_database_url)
    command.upgrade(alembic_config(url), "head")
    asyncio.run(_reset_test_schema(url, create=True))
    yield url
    asyncio.run(_reset_test_schema(url, create=False))


@pytest.fixture
async def db_engine(migrated_database: str) -> AsyncIterator[AsyncEngine]:
    engine = create_async_engine(migrated_database, poolclass=NullPool)
    yield engine
    await engine.dispose()


@pytest.fixture
async def db_session(db_engine: AsyncEngine) -> AsyncIterator[AsyncSession]:
    """Session bound to an outer transaction that is always rolled back.

    `session.commit()` inside a test only releases a SAVEPOINT, so committed data is
    visible within the test but never outlives it.
    """
    async with db_engine.connect() as connection:
        transaction = await connection.begin()
        session = AsyncSession(
            bind=connection,
            expire_on_commit=False,
            join_transaction_mode="create_savepoint",
        )
        try:
            yield session
        finally:
            await session.close()
            if transaction.is_active:
                await transaction.rollback()
