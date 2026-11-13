"""`/v1/auth` against real Postgres and Redis: register, login, refresh rotation, reuse
detection, logout, the current user, and the rate limits.

Requests commit, so every test starts and ends with no users and no rate-limit counters.
"""

import asyncio
from collections.abc import AsyncIterator, Callable
from datetime import UTC, datetime, timedelta
from typing import Any

import httpx
import pytest
from argon2 import PasswordHasher
from redis.asyncio import Redis
from sqlalchemy import select, text, update
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.core.config import DEV_JWT_SECRET, Settings
from app.factory import create_app
from app.modules.auth.models import RefreshToken, User, UserRole
from app.modules.auth.passwords import needs_rehash
from app.modules.auth.rate_limit import RateLimiter
from app.modules.auth.tokens import create_access_token
from tests.integration.conftest import IntegrationEnv, running_client

EMAIL = "contributor@example.tn"
PASSWORD = "a long enough password"
RATE_LIMIT_KEYS = "qout:ratelimit:*"


async def _clear(engine: AsyncEngine, redis: Redis) -> None:
    async with engine.begin() as connection:
        await connection.execute(text("TRUNCATE users CASCADE"))
    keys = [key async for key in redis.scan_iter(match=RATE_LIMIT_KEYS)]
    if keys:
        await redis.delete(*keys)


@pytest.fixture
async def redis(integration_env: IntegrationEnv) -> AsyncIterator[Redis]:
    client = Redis.from_url(str(integration_env.redis_url))
    yield client
    await client.aclose()


@pytest.fixture
async def sessions(
    db_engine: AsyncEngine, redis: Redis
) -> AsyncIterator[async_sessionmaker[AsyncSession]]:
    await _clear(db_engine, redis)
    yield async_sessionmaker(db_engine, expire_on_commit=False)
    await _clear(db_engine, redis)


@pytest.fixture
def api_with(
    make_settings: Callable[..., Settings], sessions: async_sessionmaker[AsyncSession]
) -> Callable[..., Any]:
    def _api(**overrides: object) -> Any:
        return running_client(create_app(make_settings(**overrides)))

    return _api


@pytest.fixture
async def api(api_with: Callable[..., Any]) -> AsyncIterator[httpx.AsyncClient]:
    async with api_with() as client:
        yield client


async def register(
    api: httpx.AsyncClient, email: str = EMAIL, password: str = PASSWORD
) -> httpx.Response:
    return await api.post("/v1/auth/register", json={"email": email, "password": password})


async def login(
    api: httpx.AsyncClient, email: str = EMAIL, password: str = PASSWORD
) -> httpx.Response:
    return await api.post("/v1/auth/login", json={"email": email, "password": password})


async def refresh(api: httpx.AsyncClient, token: str) -> httpx.Response:
    return await api.post("/v1/auth/refresh", json={"refresh_token": token})


async def me(api: httpx.AsyncClient, access: str | None) -> httpx.Response:
    headers = {} if access is None else {"Authorization": f"Bearer {access}"}
    return await api.get("/v1/auth/me", headers=headers)


async def users(sessions: async_sessionmaker[AsyncSession]) -> list[User]:
    async with sessions() as session:
        return list((await session.scalars(select(User))).all())


async def tokens_of(sessions: async_sessionmaker[AsyncSession]) -> list[RefreshToken]:
    async with sessions() as session:
        result = await session.scalars(select(RefreshToken).order_by(RefreshToken.created_at))
        return list(result.all())


# ---------------------------------------------------------------- register


async def test_register_signs_the_new_contributor_in(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    response = await register(api, email="  New.User@Example.TN ")

    assert response.status_code == 201
    body = response.json()
    assert body["token_type"] == "bearer"
    assert (body["expires_in"], body["refresh_expires_in"]) == (900, 30 * 86_400)
    [user] = await users(sessions)
    assert (user.email, user.role, user.is_active) == (
        "new.user@example.tn",
        UserRole.CONTRIBUTOR,
        True,
    )
    assert user.password_hash.startswith("$argon2id$")
    assert PASSWORD not in user.password_hash
    assert user.last_login_at is not None

    who = await me(api, body["access_token"])
    assert who.status_code == 200
    assert who.json()["email"] == "new.user@example.tn"
    assert who.json()["role"] == "contributor"
    [stored] = await tokens_of(sessions)
    assert stored.token_hash != body["refresh_token"]  # only the hash is stored


async def test_register_twice_is_a_conflict(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    await register(api)
    again = await register(api, email=EMAIL.upper(), password="another long password")

    assert again.status_code == 409
    assert "already exists" in again.json()["detail"]
    assert len(await users(sessions)) == 1


async def test_concurrent_registrations_of_one_email(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    statuses = sorted(
        r.status_code for r in await asyncio.gather(register(api), register(api), register(api))
    )
    assert statuses[0] == 201
    assert set(statuses[1:]) == {409}
    assert len(await users(sessions)) == 1


@pytest.mark.parametrize(
    ("body", "fragment"),
    [
        ({"email": "not-an-email", "password": PASSWORD}, "email"),
        ({"email": EMAIL, "password": "short"}, "at least 10"),
        ({"email": EMAIL, "password": "x" * 129}, "128"),
        ({"email": EMAIL}, "password"),
        ({"email": EMAIL, "password": PASSWORD, "role": "admin"}, "role"),
    ],
)
async def test_register_validation(
    api: httpx.AsyncClient,
    sessions: async_sessionmaker[AsyncSession],
    body: dict[str, Any],
    fragment: str,
) -> None:
    response = await api.post("/v1/auth/register", json=body)
    assert response.status_code == 422
    assert fragment in response.text
    assert await users(sessions) == []


# ---------------------------------------------------------------- login


async def test_login(api: httpx.AsyncClient) -> None:
    await register(api)

    response = await login(api, email=" CONTRIBUTOR@example.tn")

    assert response.status_code == 200
    assert (await me(api, response.json()["access_token"])).status_code == 200


@pytest.mark.parametrize(
    ("email", "password"),
    [(EMAIL, "wrong password!"), ("nobody@example.tn", PASSWORD), ("not-an-email", PASSWORD)],
)
async def test_wrong_credentials_get_one_answer(
    api: httpx.AsyncClient, email: str, password: str
) -> None:
    await register(api)

    response = await login(api, email=email, password=password)

    assert response.status_code == 401
    assert response.json()["detail"] == "wrong email or password"


async def test_inactive_accounts_cannot_sign_in_or_refresh(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    tokens = (await register(api)).json()
    async with sessions() as session:
        await session.execute(update(User).values(is_active=False))
        await session.commit()

    assert (await login(api)).status_code == 401
    assert (await refresh(api, tokens["refresh_token"])).status_code == 401
    assert (await me(api, tokens["access_token"])).status_code == 401


async def test_each_login_starts_a_session(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    await register(api)
    await login(api)

    families = {t.family_id for t in await tokens_of(sessions)}
    assert len(families) == 2


async def test_login_upgrades_an_outdated_password_hash(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    weak = PasswordHasher(time_cost=1, memory_cost=8, parallelism=1).hash(PASSWORD)
    async with sessions() as session:
        session.add(User(email=EMAIL, password_hash=weak))
        await session.commit()

    assert (await login(api)).status_code == 200
    [user] = await users(sessions)
    assert user.password_hash != weak
    assert not needs_rehash(user.password_hash)
    assert (await login(api)).status_code == 200


# ---------------------------------------------------------------- refresh


async def test_refresh_rotates_the_token(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    first = (await register(api)).json()

    response = await refresh(api, first["refresh_token"])

    assert response.status_code == 200
    second = response.json()
    assert second["refresh_token"] != first["refresh_token"]
    assert (await me(api, second["access_token"])).status_code == 200
    old, new = await tokens_of(sessions)
    assert old.used_at is not None
    assert new.used_at is None
    assert old.family_id == new.family_id
    assert (await refresh(api, second["refresh_token"])).status_code == 200


async def test_reusing_a_refresh_token_revokes_its_whole_family(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    first = (await register(api)).json()
    other_device = (await login(api)).json()
    second = (await refresh(api, first["refresh_token"])).json()

    # The first token again: someone copied it.
    reused = await refresh(api, first["refresh_token"])

    assert reused.status_code == 401
    assert reused.headers["WWW-Authenticate"] == "Bearer"
    # The legitimate successor is revoked too...
    assert (await refresh(api, second["refresh_token"])).status_code == 401
    # ...but another session of the same user is untouched.
    assert (await refresh(api, other_device["refresh_token"])).status_code == 200
    revoked = [t for t in await tokens_of(sessions) if t.revoked_at is not None]
    assert len(revoked) == 2


async def test_concurrent_refreshes_of_one_token(api: httpx.AsyncClient) -> None:
    token = (await register(api)).json()["refresh_token"]

    results = await asyncio.gather(*(refresh(api, token) for _ in range(3)))

    assert sorted(r.status_code for r in results) == [200, 401, 401]


async def test_expired_unknown_and_revoked_refresh_tokens(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    token = (await register(api)).json()["refresh_token"]
    async with sessions() as session:
        await session.execute(
            update(RefreshToken).values(expires_at=datetime.now(UTC) - timedelta(seconds=1))
        )
        await session.commit()

    assert (await refresh(api, token)).status_code == 401
    assert (await refresh(api, "not-a-token")).status_code == 401
    assert (await api.post("/v1/auth/refresh", json={"refresh_token": ""})).status_code == 422


# ---------------------------------------------------------------- logout


async def test_logout_ends_the_session(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    first = (await register(api)).json()
    second = (await refresh(api, first["refresh_token"])).json()

    response = await api.post("/v1/auth/logout", json={"refresh_token": second["refresh_token"]})

    assert response.status_code == 204
    assert (await refresh(api, second["refresh_token"])).status_code == 401
    assert all(t.revoked_at is not None for t in await tokens_of(sessions))


async def test_logout_with_an_unknown_token_still_succeeds(api: httpx.AsyncClient) -> None:
    response = await api.post("/v1/auth/logout", json={"refresh_token": "never-issued"})
    assert response.status_code == 204


# ---------------------------------------------------------------- current user


async def test_me_needs_a_valid_access_token(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    await register(api)
    [user] = await users(sessions)
    long_ago = datetime.now(UTC) - timedelta(hours=1)
    expired = create_access_token(
        user.id, UserRole.CONTRIBUTOR, secret=DEV_JWT_SECRET, now=long_ago,
        ttl=timedelta(minutes=15),
    )  # fmt: skip
    other_key = create_access_token(
        user.id, UserRole.CONTRIBUTOR, secret="x" * 40, now=datetime.now(UTC),
        ttl=timedelta(minutes=15),
    )  # fmt: skip

    for access in (None, "garbage", expired, other_key):
        response = await me(api, access)
        assert response.status_code == 401
        assert response.headers["WWW-Authenticate"] == "Bearer"
    basic = await api.get("/v1/auth/me", headers={"Authorization": "Basic dXNlcjpwYXNz"})
    assert basic.status_code == 401


async def test_deleted_users_are_signed_out(
    api: httpx.AsyncClient, sessions: async_sessionmaker[AsyncSession]
) -> None:
    access = (await register(api)).json()["access_token"]
    async with sessions() as session:
        await session.execute(text("DELETE FROM users"))
        await session.commit()

    assert (await me(api, access)).status_code == 401


# ---------------------------------------------------------------- rate limits


async def test_failed_logins_per_email_are_limited(api_with: Callable[..., Any]) -> None:
    async with api_with(login_max_failures_per_email=2, login_window_seconds=600) as api:
        await register(api)
        assert (await login(api, password="wrong one!!")).status_code == 401
        assert (await login(api, password="wrong two!!")).status_code == 401

        blocked = await login(api)  # even the right password, until the window ends
        assert blocked.status_code == 429
        assert 0 < int(blocked.headers["Retry-After"]) <= 600
        # Other accounts are not affected.
        await register(api, email="someone@example.tn")
        assert (await login(api, email="someone@example.tn")).status_code == 200


async def test_a_successful_login_clears_the_failures(api_with: Callable[..., Any]) -> None:
    async with api_with(login_max_failures_per_email=2) as api:
        await register(api)
        assert (await login(api, password="wrong one!!")).status_code == 401
        assert (await login(api)).status_code == 200
        assert (await login(api, password="wrong two!!")).status_code == 401
        assert (await login(api)).status_code == 200


async def test_login_attempts_per_ip_are_limited(api_with: Callable[..., Any]) -> None:
    async with api_with(login_max_attempts_per_ip=3) as api:
        await register(api)
        for _ in range(3):
            assert (await login(api)).status_code == 200
        assert (await login(api)).status_code == 429


async def test_registrations_per_ip_are_limited(api_with: Callable[..., Any]) -> None:
    async with api_with(register_max_per_ip=2, register_window_seconds=3600) as api:
        assert (await register(api, email="one@example.tn")).status_code == 201
        assert (await register(api, email="two@example.tn")).status_code == 201

        blocked = await register(api, email="three@example.tn")
        assert blocked.status_code == 429
        assert 3500 < int(blocked.headers["Retry-After"]) <= 3600


async def test_rate_limits_let_requests_through_when_redis_is_down() -> None:
    limiter = RateLimiter(Redis.from_url("redis://localhost:1/0", socket_connect_timeout=0.5))
    assert (await limiter.hit("k", limit=1, window=60)).allowed
    assert (await limiter.hit("k", limit=1, window=60)).allowed
    assert (await limiter.check("k", limit=1)).allowed
    await limiter.reset("k")  # no error
