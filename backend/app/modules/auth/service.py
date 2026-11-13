"""Registration, login, refresh rotation with reuse detection, logout, current user.

Flushes and commits itself (each operation is one unit of work). Doesn't import FastAPI:
the router maps the errors below to HTTP statuses.
"""

import logging
import uuid
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.modules.auth.models import RefreshToken, User, UserRole
from app.modules.auth.passwords import (
    check_password,
    hash_password_async,
    needs_rehash,
    normalize_email,
    verify_password_async,
)
from app.modules.auth.rate_limit import RateLimiter
from app.modules.auth.tokens import (
    InvalidAccessTokenError,
    create_access_token,
    decode_access_token,
    hash_refresh_token,
    new_refresh_token,
)

logger = logging.getLogger(__name__)


class EmailTakenError(Exception):
    """Registration with an email that already has an account."""


class InvalidCredentialsError(Exception):
    """Wrong email or password, or an inactive account (one message for all)."""


class InvalidRefreshTokenError(Exception):
    """Unknown, expired, revoked or reused refresh token, or an inactive account."""


class NotAuthenticatedError(Exception):
    """No valid access token, or its account is gone or inactive."""


class RateLimitedError(Exception):
    def __init__(self, retry_after: int) -> None:
        super().__init__(f"too many attempts, retry in {retry_after} s")
        self.retry_after = retry_after


@dataclass(frozen=True)
class Tokens:
    access_token: str
    access_expires_in: int
    """Seconds."""
    refresh_token: str
    refresh_expires_in: int
    """Seconds."""


class AuthService:
    def __init__(
        self,
        session: AsyncSession,
        settings: Settings,
        limiter: RateLimiter,
        *,
        clock: Callable[[], datetime] | None = None,
    ) -> None:
        self._session = session
        self._settings = settings
        self._limiter = limiter
        self._clock = clock or (lambda: datetime.now(UTC))

    # ------------------------------------------------------------ register / login

    async def register(self, email: str, password: str, *, client_ip: str) -> Tokens:
        """Raises ValueError (bad email or password), EmailTakenError, RateLimitedError."""
        email = normalize_email(email)
        check_password(password)
        limit = await self._limiter.hit(
            f"register:ip:{client_ip}",
            limit=self._settings.register_max_per_ip,
            window=self._settings.register_window_seconds,
        )
        if not limit.allowed:
            raise RateLimitedError(limit.retry_after)
        if await self._user_by_email(email) is not None:
            raise EmailTakenError(email)
        user = User(email=email, password_hash=await hash_password_async(password))
        self._session.add(user)
        try:
            await self._session.flush()
        except IntegrityError as error:  # registered concurrently
            await self._session.rollback()
            raise EmailTakenError(email) from error
        user.last_login_at = self._clock()
        tokens = await self._start_family(user)
        await self._session.commit()
        logger.info("user registered", extra={"user_id": str(user.id)})
        return tokens

    async def login(self, email: str, password: str, *, client_ip: str) -> Tokens:
        """Raises InvalidCredentialsError, RateLimitedError."""
        ip_limit = await self._limiter.hit(
            f"login:ip:{client_ip}",
            limit=self._settings.login_max_attempts_per_ip,
            window=self._settings.login_window_seconds,
        )
        if not ip_limit.allowed:
            raise RateLimitedError(ip_limit.retry_after)
        try:
            email = normalize_email(email)
        except ValueError as error:
            raise InvalidCredentialsError from error
        failures_key = f"login:email:{email}"
        email_limit = await self._limiter.check(
            failures_key, limit=self._settings.login_max_failures_per_email
        )
        if not email_limit.allowed:
            raise RateLimitedError(email_limit.retry_after)

        user = await self._user_by_email(email)
        matches = await verify_password_async(
            user.password_hash if user is not None else None, password
        )
        if user is None or not matches or not user.is_active:
            await self._limiter.hit(
                failures_key,
                limit=self._settings.login_max_failures_per_email,
                window=self._settings.login_window_seconds,
            )
            raise InvalidCredentialsError
        await self._limiter.reset(failures_key)

        if needs_rehash(user.password_hash):
            user.password_hash = await hash_password_async(password)
        user.last_login_at = self._clock()
        tokens = await self._start_family(user)
        await self._session.commit()
        return tokens

    # ------------------------------------------------------------ refresh / logout

    async def refresh(self, refresh_token: str) -> Tokens:
        """Exchanges a refresh token for new tokens (the old one is used up). Raises
        InvalidRefreshTokenError; a token used before revokes its whole family."""
        now = self._clock()
        stored = await self._session.scalar(
            select(RefreshToken)
            .where(RefreshToken.token_hash == hash_refresh_token(refresh_token))
            .with_for_update()  # concurrent refreshes of one token: one wins
        )
        if stored is None or stored.revoked_at is not None or stored.expires_at <= now:
            raise InvalidRefreshTokenError
        if stored.used_at is not None:
            await self._revoke_family(stored.family_id, now)
            await self._session.commit()
            logger.warning(
                "refresh token reused: family revoked",
                extra={"user_id": str(stored.user_id), "family_id": str(stored.family_id)},
            )
            raise InvalidRefreshTokenError
        user = await self._session.get(User, stored.user_id)
        if user is None or not user.is_active:
            raise InvalidRefreshTokenError
        stored.used_at = now
        tokens = await self._issue(user, family_id=stored.family_id)
        await self._session.commit()
        return tokens

    async def logout(self, refresh_token: str) -> None:
        """Revokes the token's family (this device's session). Unknown tokens are ignored,
        so logging out never fails and reveals nothing."""
        stored = await self._session.scalar(
            select(RefreshToken).where(RefreshToken.token_hash == hash_refresh_token(refresh_token))
        )
        if stored is not None:
            await self._revoke_family(stored.family_id, self._clock())
            await self._session.commit()

    # ------------------------------------------------------------ current user

    async def current_user(self, access_token: str) -> User:
        """Raises NotAuthenticatedError."""
        try:
            claims = decode_access_token(
                access_token,
                secret=self._settings.jwt_secret.get_secret_value(),
                now=self._clock(),
            )
        except InvalidAccessTokenError as error:
            raise NotAuthenticatedError from error
        user = await self._session.get(User, claims.user_id)
        if user is None or not user.is_active:
            raise NotAuthenticatedError
        return user

    # ------------------------------------------------------------ helpers

    async def _user_by_email(self, email: str) -> User | None:
        return await self._session.scalar(select(User).where(User.email == email))

    async def _start_family(self, user: User) -> Tokens:
        return await self._issue(user, family_id=uuid.uuid4())

    async def _issue(self, user: User, *, family_id: uuid.UUID) -> Tokens:
        now = self._clock()
        access_ttl = timedelta(seconds=self._settings.access_token_ttl_seconds)
        refresh_ttl = timedelta(days=self._settings.refresh_token_ttl_days)
        refresh = new_refresh_token()
        self._session.add(
            RefreshToken(
                user_id=user.id,
                family_id=family_id,
                token_hash=hash_refresh_token(refresh),
                expires_at=now + refresh_ttl,
            )
        )
        await self._session.flush()
        access = create_access_token(
            user.id,
            UserRole(user.role),
            secret=self._settings.jwt_secret.get_secret_value(),
            now=now,
            ttl=access_ttl,
        )
        return Tokens(
            access_token=access,
            access_expires_in=int(access_ttl.total_seconds()),
            refresh_token=refresh,
            refresh_expires_in=int(refresh_ttl.total_seconds()),
        )

    async def _revoke_family(self, family_id: uuid.UUID, now: datetime) -> None:
        await self._session.execute(
            update(RefreshToken)
            .where(RefreshToken.family_id == family_id, RefreshToken.revoked_at.is_(None))
            .values(revoked_at=now)
        )
