"""Signing in to the admin panel: moderators (role `admin`) only.

The panel signs in with the same email and password as the app, through the same checks
(Argon2, login rate limits, inactive accounts refused), but issues no tokens: the session
is a signed cookie holding the user id and the sign-in time. It is `SameSite=strict` (no
cross-site form posts reach the panel signed in), limited to `/admin`, HTTPS only when
deployed, and ends `ADMIN_SESSION_TTL_SECONDS` after signing in. Every request reads the
account again, so a moderator who is deactivated or loses the role is out at once.
"""

import logging
import time
import uuid
from collections.abc import Callable
from typing import Any

from sqladmin.authentication import AuthenticationBackend
from starlette import status
from starlette.requests import Request
from starlette.responses import Response

from app.admin.context import main_state, sessions_of, settings_of
from app.api.auth import client_ip
from app.core.config import Settings
from app.modules.auth.models import User, UserRole
from app.modules.auth.rate_limit import RateLimiter
from app.modules.auth.service import AuthService, InvalidCredentialsError, RateLimitedError

logger = logging.getLogger(__name__)

SESSION_COOKIE = "qout_admin"
USER_ID = "user_id"  # read by sqladmin's `get_user_id`
SIGNED_IN_AT = "signed_in_at"


def _now() -> float:
    return time.time()  # looked up on each call (tests move the clock)


def session_valid(signed_in_at: object, now: float, ttl_seconds: int) -> bool:
    """A session started at `signed_in_at` (epoch seconds) is still open at `now`."""
    if not isinstance(signed_in_at, int | float) or isinstance(signed_in_at, bool):
        return False
    return signed_in_at <= now < signed_in_at + ttl_seconds


def may_moderate(user: User | None) -> bool:
    return user is not None and user.is_active and user.role == UserRole.ADMIN


class AdminAuth(AuthenticationBackend):
    def __init__(self, settings: Settings, *, clock: Callable[[], float] | None = None) -> None:
        super().__init__(
            secret_key=settings.admin_session_secret.get_secret_value(),
            session_cookie=SESSION_COOKIE,
            max_age=settings.admin_session_ttl_seconds,
            path="/admin",
            same_site="strict",
            https_only=settings.deployed,
        )
        self._clock = clock or _now
        self.templates: Any = None
        """The panel's templates, set once the panel is built (login errors)."""

    async def login(self, request: Request) -> Response | bool:
        form = await request.form()
        email, password = str(form.get("username", "")), str(form.get("password", ""))
        async with sessions_of(request)() as session:
            service = AuthService(
                session, settings_of(request), RateLimiter(main_state(request).redis)
            )
            try:
                user = await service.verify_credentials(
                    email, password, client_ip=client_ip(request)
                )
            except InvalidCredentialsError:
                return False
            except RateLimitedError as error:
                return await self._login_error(
                    request,
                    f"Too many attempts. Try again in {max(1, error.retry_after // 60)} min.",
                    status.HTTP_429_TOO_MANY_REQUESTS,
                )
        if not may_moderate(user):
            logger.info("admin panel refused a non-moderator", extra={"user_id": str(user.id)})
            return False  # same message as a wrong password
        request.session.clear()
        request.session.update({USER_ID: str(user.id), SIGNED_IN_AT: self._clock()})
        logger.info("admin panel sign-in", extra={"user_id": str(user.id)})
        return True

    async def logout(self, request: Request) -> Response | bool:
        request.session.clear()
        return True

    async def authenticate(self, request: Request) -> Response | bool:
        settings = settings_of(request)
        if not session_valid(
            request.session.get(SIGNED_IN_AT), self._clock(), settings.admin_session_ttl_seconds
        ):
            request.session.clear()
            return False
        try:
            user_id = uuid.UUID(str(request.session.get(USER_ID)))
        except ValueError:
            request.session.clear()
            return False
        async with sessions_of(request)() as session:
            user = await session.get(User, user_id)
        if not may_moderate(user):
            request.session.clear()
            return False
        return True

    async def _login_error(self, request: Request, message: str, status_code: int) -> Response:
        response: Response = await self.templates.TemplateResponse(
            request, "sqladmin/login.html", {"error": message}, status_code=status_code
        )
        return response
