"""Shared setup for the admin panel tests: the app with the test buckets, accounts with
real passwords, and a signed-in panel client."""

import uuid
from collections.abc import AsyncIterator, Callable
from typing import Any

import httpx
import pytest
from redis.asyncio import Redis
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.core.config import Settings
from app.core.storage import Storage
from app.factory import create_app
from app.modules.auth.models import User, UserRole
from app.modules.auth.passwords import hash_password
from app.modules.contributions.models import Contribution
from app.modules.contributions.schemas import PhotoContentType, PhotoKind
from app.modules.contributions.uploads import upload_key
from tests.factories import ContributionFactory, UserFactory
from tests.integration.conftest import IntegrationEnv, running_client

Sessions = async_sessionmaker[AsyncSession]
PASSWORD = "a long enough password"
REDIS_PATTERNS = ("qout:ratelimit:*", "qout:product:*")
JPEG = b"\xff\xd8\xff\xe0 a label photo"
_HASH = hash_password(PASSWORD)  # once: Argon2 is slow on purpose


async def _clear(engine: AsyncEngine, redis: Redis) -> None:
    async with engine.begin() as connection:
        await connection.execute(text("TRUNCATE users, products, contributions CASCADE"))
    for pattern in REDIS_PATTERNS:
        keys = [key async for key in redis.scan_iter(match=pattern)]
        if keys:
            await redis.delete(*keys)


@pytest.fixture
async def redis(integration_env: IntegrationEnv) -> AsyncIterator[Redis]:
    client = Redis.from_url(str(integration_env.redis_url))
    yield client
    await client.aclose()


@pytest.fixture
async def sessions(db_engine: AsyncEngine, redis: Redis) -> AsyncIterator[Sessions]:
    await _clear(db_engine, redis)
    yield async_sessionmaker(db_engine, expire_on_commit=False)
    await _clear(db_engine, redis)


@pytest.fixture
def app_with(make_settings: Callable[..., Settings]) -> Callable[..., Any]:
    def _app(**overrides: object) -> Any:
        return running_client(create_app(make_settings(**overrides)))

    return _app


@pytest.fixture
async def client(
    app_with: Callable[..., Any], sessions: Sessions, storage: Storage
) -> AsyncIterator[httpx.AsyncClient]:
    async with app_with() as http:
        yield http


async def account(
    sessions: Sessions,
    email: str,
    role: UserRole = UserRole.CONTRIBUTOR,
    *,
    is_active: bool = True,
) -> User:
    async with sessions() as session:
        user = await UserFactory.create(
            session, email=email, password_hash=_HASH, role=role, is_active=is_active
        )
        await session.commit()
        return user


async def panel_sign_in(
    http: httpx.AsyncClient, email: str, password: str = PASSWORD
) -> httpx.Response:
    return await http.post("/admin/login", data={"username": email, "password": password})


@pytest.fixture
async def admin(sessions: Sessions) -> User:
    return await account(sessions, "moderator@example.tn", UserRole.ADMIN)


@pytest.fixture
async def panel(client: httpx.AsyncClient, admin: User) -> httpx.AsyncClient:
    """The client, signed in to the panel as `admin`."""
    response = await panel_sign_in(client, admin.email)
    assert response.status_code == 302, response.text
    return client


async def set_user(sessions: Sessions, user_id: uuid.UUID, **values: Any) -> None:
    async with sessions() as session:
        user = await session.get(User, user_id)
        assert user is not None
        for name, value in values.items():
            setattr(user, name, value)
        await session.commit()


async def contribution_with_photos(
    sessions: Sessions, storage: Storage, user_id: uuid.UUID | None, **values: Any
) -> Contribution:
    """A pending contribution whose front and nutrition photos are in storage."""
    client_id = uuid.uuid4()
    owner = user_id or uuid.uuid4()
    photos = {}
    for kind in (PhotoKind.FRONT, PhotoKind.NUTRITION):
        key = upload_key(owner, client_id, kind, PhotoContentType.JPEG, uuid.uuid4().hex[:16])
        await storage.uploads.put(key, JPEG, content_type="image/jpeg")
        photos[kind.value] = key
    defaults: dict[str, Any] = {
        "client_id": client_id,
        "name": "Harissa",
        "brand": "Cap Bon",
        "photos": photos,
        "ocr_text": {"nutrition": "Valeurs nutritionnelles pour 100 g\nSucres 4 g"},
        "nutrition": {
            "energy_kj": "400",
            "sugars_g": "4",
            "saturated_fat_g": "0.5",
            "total_fat_g": "2",
            "salt_g": "3",
            "fibre_g": "3",
            "protein_g": "3",
            "fvl_percent": "60",
        },
    }
    async with sessions() as session:
        contribution = await ContributionFactory.create(
            session, user_id=user_id, **(defaults | values)
        )
        await session.commit()
        return contribution


async def reload(sessions: Sessions, model: type[Any], row_id: uuid.UUID) -> Any:
    async with sessions() as session:
        row = await session.get(model, row_id)
        assert row is not None
        return row
