"""`POST /v1/uploads` against real Postgres, Redis and RustFS: signed-in contributors get a
URL for one PUT of the declared photo; other types, sizes and anonymous callers are refused."""

import uuid
from collections.abc import AsyncIterator, Callable
from datetime import UTC, datetime, timedelta
from typing import Any

import httpx
import pytest
from redis.asyncio import Redis
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine

from app.core.config import Settings
from app.core.storage import Storage, StoredObject
from app.factory import create_app
from tests.integration.conftest import IntegrationEnv, running_client

PASSWORD = "a long enough password"
CONTRIBUTION = uuid.UUID("0b6c4a5e-8f0e-4f6c-9a43-6f3f1c1f9a01")
RATE_LIMIT_KEYS = "qout:ratelimit:*"


async def _clear(engine: AsyncEngine, redis: Redis) -> None:
    async with engine.begin() as connection:
        await connection.execute(text("TRUNCATE users CASCADE"))
    keys = [key async for key in redis.scan_iter(match=RATE_LIMIT_KEYS)]
    if keys:
        await redis.delete(*keys)


@pytest.fixture
async def clean(db_engine: AsyncEngine, integration_env: IntegrationEnv) -> AsyncIterator[None]:
    redis = Redis.from_url(str(integration_env.redis_url))
    await _clear(db_engine, redis)
    yield
    await _clear(db_engine, redis)
    await redis.aclose()


@pytest.fixture
def api_with(
    make_settings: Callable[..., Settings], clean: None, storage: Storage
) -> Callable[..., Any]:
    def _api(**overrides: object) -> Any:
        return running_client(create_app(make_settings(**overrides)))

    return _api


@pytest.fixture
async def api(api_with: Callable[..., Any]) -> AsyncIterator[httpx.AsyncClient]:
    async with api_with() as client:
        yield client


async def sign_in(api: httpx.AsyncClient, email: str = "photos@example.tn") -> dict[str, str]:
    response = await api.post("/v1/auth/register", json={"email": email, "password": PASSWORD})
    assert response.status_code == 201
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


async def user_id(api: httpx.AsyncClient, headers: dict[str, str]) -> str:
    return str((await api.get("/v1/auth/me", headers=headers)).json()["id"])


def body(**overrides: object) -> dict[str, object]:
    values: dict[str, object] = {
        "contribution_id": str(CONTRIBUTION),
        "kind": "nutrition",
        "content_type": "image/jpeg",
        "size_bytes": 5,
    }
    return values | overrides


async def put(url: str, content: bytes, content_type: str) -> httpx.Response:
    async with httpx.AsyncClient(timeout=10) as http:
        return await http.put(url, content=content, headers={"Content-Type": content_type})


async def test_presigned_upload_round_trip(api: httpx.AsyncClient, storage: Storage) -> None:
    headers = await sign_in(api)
    before = datetime.now(UTC)

    response = await api.post("/v1/uploads", json=body(), headers=headers)

    assert response.status_code == 201
    ticket = response.json()
    owner = await user_id(api, headers)
    assert ticket["key"].startswith(f"contributions/{owner}/{CONTRIBUTION}/nutrition-")
    assert ticket["key"].endswith(".jpg")
    expires_at = datetime.fromisoformat(ticket["expires_at"])
    assert before + timedelta(seconds=299) <= expires_at
    assert expires_at <= datetime.now(UTC) + timedelta(seconds=301)
    assert (await put(ticket["url"], b"12345", "image/jpeg")).status_code == 200
    assert await storage.uploads.head(ticket["key"]) == StoredObject(5, "image/jpeg")
    assert await storage.public.head(ticket["key"]) is None


async def test_png_gets_a_png_key(api: httpx.AsyncClient) -> None:
    headers = await sign_in(api)

    response = await api.post(
        "/v1/uploads", json=body(content_type="image/png", kind="front"), headers=headers
    )

    assert response.status_code == 201
    assert "/front-" in response.json()["key"]
    assert response.json()["key"].endswith(".png")


async def test_each_request_gets_its_own_key(api: httpx.AsyncClient) -> None:
    headers = await sign_in(api)

    first = await api.post("/v1/uploads", json=body(), headers=headers)
    second = await api.post("/v1/uploads", json=body(), headers=headers)

    assert first.json()["key"] != second.json()["key"]


async def test_upload_with_another_content_type_is_rejected_by_storage(
    api: httpx.AsyncClient, storage: Storage
) -> None:
    headers = await sign_in(api)
    ticket = (await api.post("/v1/uploads", json=body(), headers=headers)).json()

    response = await put(ticket["url"], b"12345", "image/png")

    assert response.status_code == 403
    assert await storage.uploads.head(ticket["key"]) is None


@pytest.mark.parametrize(
    "content_type", ["image/gif", "image/webp", "application/pdf", "text/html", ""]
)
async def test_wrong_content_type_is_refused(api: httpx.AsyncClient, content_type: str) -> None:
    headers = await sign_in(api)

    response = await api.post("/v1/uploads", json=body(content_type=content_type), headers=headers)

    assert response.status_code == 422


@pytest.mark.parametrize(
    "overrides",
    [
        pytest.param({"kind": "back"}, id="unknown-kind"),
        pytest.param({"size_bytes": 0}, id="empty"),
        pytest.param({"size_bytes": -1}, id="negative"),
        pytest.param({"contribution_id": "not-a-uuid"}, id="contribution-id"),
        pytest.param({"extra": 1}, id="unknown-field"),
    ],
)
async def test_invalid_request_is_refused(
    api: httpx.AsyncClient, overrides: dict[str, object]
) -> None:
    headers = await sign_in(api)

    response = await api.post("/v1/uploads", json=body(**overrides), headers=headers)

    assert response.status_code == 422


async def test_too_large_is_refused(api_with: Callable[..., Any]) -> None:
    async with api_with(upload_max_bytes=2048) as api:
        headers = await sign_in(api)
        at_limit = await api.post("/v1/uploads", json=body(size_bytes=2048), headers=headers)
        over = await api.post("/v1/uploads", json=body(size_bytes=2049), headers=headers)

    assert at_limit.status_code == 201
    assert over.status_code == 422
    assert over.json() == {"detail": "photo too large: 2049 bytes, at most 2048"}


async def test_signed_in_users_only(api: httpx.AsyncClient) -> None:
    anonymous = await api.post("/v1/uploads", json=body())
    bad_token = await api.post(
        "/v1/uploads", json=body(), headers={"Authorization": "Bearer nonsense"}
    )

    assert anonymous.status_code == 401
    assert bad_token.status_code == 401
    assert anonymous.headers["www-authenticate"] == "Bearer"


async def test_uploads_are_rate_limited_per_user(api_with: Callable[..., Any]) -> None:
    async with api_with(upload_max_per_user=2, upload_window_seconds=60) as api:
        first_user = await sign_in(api, "one@example.tn")
        other_user = await sign_in(api, "two@example.tn")
        statuses = [
            (await api.post("/v1/uploads", json=body(), headers=first_user)).status_code
            for _ in range(3)
        ]
        limited = await api.post("/v1/uploads", json=body(), headers=first_user)
        other = await api.post("/v1/uploads", json=body(), headers=other_user)

    assert statuses == [201, 201, 429]
    assert 1 <= int(limited.headers["retry-after"]) <= 60
    assert other.status_code == 201


async def test_operation_is_documented_as_secured(api: httpx.AsyncClient) -> None:
    spec = (await api.get("/openapi.json")).json()
    operation = spec["paths"]["/v1/uploads"]["post"]

    assert operation["operationId"] == "createUpload"
    assert operation["security"] == [{"HTTPBearer": []}]
