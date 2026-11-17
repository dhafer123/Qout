"""Signing in to the admin panel (`/admin`): moderators only, sessions that end when the
account changes, and every page behind the sign-in."""

import base64
import json
import time
import uuid
from collections.abc import Callable
from typing import Any

import httpx
import pytest
from itsdangerous import TimestampSigner
from sqlalchemy import func, select

from app.admin.auth import SESSION_COOKIE, SIGNED_IN_AT, USER_ID
from app.core.config import DEV_ADMIN_SESSION_SECRET
from app.modules.auth.models import RefreshToken, User, UserRole
from tests.integration.admin.conftest import (
    Sessions,
    account,
    panel_sign_in,
    reload,
    set_user,
)

PAGES = [
    "/admin/",
    "/admin/moderation",
    f"/admin/moderation/{uuid.uuid4()}",
    "/admin/error-reports",
    "/admin/product/list",
    "/admin/score/list",
    "/admin/nutrition-facts/list",
    "/admin/user/list",
]


def forged_session(data: dict[str, object]) -> str:
    """A session cookie signed with the dev key, as Starlette writes them."""
    payload = base64.b64encode(json.dumps(data).encode())
    return TimestampSigner(DEV_ADMIN_SESSION_SECRET).sign(payload).decode()


@pytest.mark.parametrize("path", PAGES)
async def test_pages_need_a_sign_in(client: httpx.AsyncClient, path: str) -> None:
    response = await client.get(path)
    assert response.status_code == 302
    assert response.headers["location"] == "http://test/admin/login"


async def test_actions_need_a_sign_in(client: httpx.AsyncClient) -> None:
    response = await client.post(f"/admin/error-reports/{uuid.uuid4()}/resolve")
    assert response.status_code == 302
    response = await client.post(f"/admin/moderation/{uuid.uuid4()}", data={"action": "approve"})
    assert response.status_code == 302


async def test_moderator_signs_in_and_out(client: httpx.AsyncClient, admin: User) -> None:
    response = await panel_sign_in(client, "  Moderator@Example.tn ")

    assert response.status_code == 302
    assert response.headers["location"] == "http://test/admin/"
    cookie = response.headers["set-cookie"].lower()
    assert f"{SESSION_COOKIE}=" in cookie
    assert "path=/admin" in cookie
    assert "samesite=strict" in cookie
    assert "httponly" in cookie
    assert (await client.get("/admin/")).status_code == 200

    await client.get("/admin/logout")
    assert (await client.get("/admin/")).status_code == 302


async def test_sign_in_records_the_login_without_tokens(
    client: httpx.AsyncClient, sessions: Sessions, admin: User
) -> None:
    await panel_sign_in(client, admin.email)
    assert (await reload(sessions, User, admin.id)).last_login_at is not None
    async with sessions() as session:
        tokens = await session.scalar(select(func.count()).select_from(RefreshToken))
    assert tokens == 0


@pytest.mark.parametrize(
    ("email", "password"),
    [
        ("contributor@example.tn", "a long enough password"),  # not a moderator
        ("moderator@example.tn", "the wrong password!!"),
        ("nobody@example.tn", "a long enough password"),
        ("not an email", "a long enough password"),
    ],
)
async def test_others_are_refused_with_one_message(
    client: httpx.AsyncClient, sessions: Sessions, admin: User, email: str, password: str
) -> None:
    await account(sessions, "contributor@example.tn")
    response = await panel_sign_in(client, email, password)
    assert response.status_code == 400
    assert "Invalid credentials" in response.text
    assert (await client.get("/admin/")).status_code == 302


async def test_inactive_moderator_is_refused(client: httpx.AsyncClient, sessions: Sessions) -> None:
    await account(sessions, "gone@example.tn", UserRole.ADMIN, is_active=False)
    assert (await panel_sign_in(client, "gone@example.tn")).status_code == 400


async def test_sign_in_is_rate_limited(
    app_with: Callable[..., Any], sessions: Sessions, storage: object
) -> None:
    await account(sessions, "moderator@example.tn", UserRole.ADMIN)
    async with app_with(login_max_failures_per_email=2) as client:
        for _ in range(2):
            await panel_sign_in(client, "moderator@example.tn", "the wrong password!!")
        response = await panel_sign_in(client, "moderator@example.tn")
    assert response.status_code == 429
    assert "Too many attempts" in response.text


@pytest.mark.parametrize(
    "change", [{"role": UserRole.CONTRIBUTOR}, {"is_active": False}], ids=["demoted", "inactive"]
)
async def test_session_ends_when_the_account_changes(
    panel: httpx.AsyncClient, sessions: Sessions, admin: User, change: dict[str, object]
) -> None:
    await set_user(sessions, admin.id, **change)
    assert (await panel.get("/admin/")).status_code == 302
    await set_user(sessions, admin.id, role=UserRole.ADMIN, is_active=True)
    assert (await panel.get("/admin/")).status_code == 302  # signed out for good


async def test_session_ends_after_its_lifetime(
    panel: httpx.AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    later = time.time() + 8 * 3600
    monkeypatch.setattr("app.admin.auth.time.time", lambda: later)
    assert (await panel.get("/admin/")).status_code == 302


@pytest.mark.parametrize(
    "data",
    [
        {USER_ID: "not-a-uuid", SIGNED_IN_AT: time.time()},
        {SIGNED_IN_AT: time.time()},
        {USER_ID: str(uuid.uuid4()), SIGNED_IN_AT: time.time()},  # no such account
        {USER_ID: str(uuid.uuid4()), SIGNED_IN_AT: "yesterday"},
    ],
)
async def test_unusable_sessions_are_refused(
    client: httpx.AsyncClient, data: dict[str, object]
) -> None:
    client.cookies.set(SESSION_COOKIE, forged_session(data), path="/admin")
    assert (await client.get("/admin/")).status_code == 302


async def test_a_session_signed_with_another_key_is_ignored(
    client: httpx.AsyncClient, admin: User
) -> None:
    payload = base64.b64encode(
        json.dumps({USER_ID: str(admin.id), SIGNED_IN_AT: time.time()}).encode()
    )
    cookie = TimestampSigner("another key, at least thirty-two chars").sign(payload).decode()
    client.cookies.set(SESSION_COOKIE, cookie, path="/admin")
    assert (await client.get("/admin/")).status_code == 302


async def test_session_cookie_is_https_only_when_deployed(
    app_with: Callable[..., Any], sessions: Sessions, storage: object
) -> None:
    await account(sessions, "moderator@example.tn", UserRole.ADMIN)
    async with app_with(
        app_env="staging",
        jwt_secret="x" * 40,
        admin_session_secret="y" * 40,
        s3_access_key="staging-key",
        s3_secret_key="staging-secret",
    ) as client:
        response = await panel_sign_in(client, "moderator@example.tn")
    assert "secure" in response.headers["set-cookie"].lower()
