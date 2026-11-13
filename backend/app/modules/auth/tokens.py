"""Access tokens (short-lived JWTs) and refresh tokens (opaque random strings).

- Access: HS256 JWT with `sub` (user id), `role`, `type: access`, issuer and audience, and
  `iat`/`exp`. Stateless: checked by signature and expiry only, so it lives briefly.
- Refresh: 256 random bits, URL-safe. Only its SHA-256 is stored (`RefreshToken`).
"""

import hashlib
import secrets
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta

import jwt

from app.modules.auth.models import UserRole

ISSUER = "qout-api"
AUDIENCE = "qout-app"
ALGORITHM = "HS256"
_ACCESS = "access"


class InvalidAccessTokenError(Exception):
    """Missing, malformed, expired, or signed with another key."""


@dataclass(frozen=True)
class AccessClaims:
    user_id: uuid.UUID
    role: UserRole
    expires_at: datetime


def create_access_token(
    user_id: uuid.UUID, role: UserRole, *, secret: str, now: datetime, ttl: timedelta
) -> str:
    claims = {
        "sub": str(user_id),
        "role": role.value,
        "type": _ACCESS,
        "iss": ISSUER,
        "aud": AUDIENCE,
        "iat": now,
        "exp": now + ttl,
    }
    return jwt.encode(claims, secret, algorithm=ALGORITHM)


def decode_access_token(token: str, *, secret: str, now: datetime) -> AccessClaims:
    """The claims of a valid access token; raises InvalidAccessTokenError otherwise."""
    try:
        claims = jwt.decode(
            token,
            secret,
            algorithms=[ALGORITHM],  # never trust the token's own `alg`
            audience=AUDIENCE,
            issuer=ISSUER,
            options={"require": ["sub", "exp", "iat", "type", "role"], "verify_exp": False},
        )
        if claims["type"] != _ACCESS:
            raise InvalidAccessTokenError("not an access token")
        expires_at = datetime.fromtimestamp(claims["exp"], tz=now.tzinfo)
        if expires_at <= now:  # checked here, against the injected clock
            raise InvalidAccessTokenError("expired")
        return AccessClaims(uuid.UUID(claims["sub"]), UserRole(claims["role"]), expires_at)
    except (jwt.InvalidTokenError, ValueError, TypeError, OverflowError) as error:
        raise InvalidAccessTokenError(str(error)) from error


def new_refresh_token() -> str:
    return secrets.token_urlsafe(32)


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()
