"""Request and response bodies of `/v1/auth`."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.modules.auth.models import UserRole
from app.modules.auth.passwords import MAX_EMAIL_LENGTH, MAX_PASSWORD_LENGTH


class _Request(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Credentials(_Request):
    """Registration and login. Emails are compared lower-cased."""

    email: str = Field(max_length=MAX_EMAIL_LENGTH)
    password: str = Field(max_length=MAX_PASSWORD_LENGTH)
    """At least 10 characters when registering."""


class RefreshRequest(_Request):
    refresh_token: str = Field(min_length=1, max_length=256)


class TokenPair(BaseModel):
    """Send `access_token` as `Authorization: Bearer ...`; when it expires, exchange
    `refresh_token` (single use) at `/v1/auth/refresh` for a new pair."""

    access_token: str
    token_type: str = "bearer"  # noqa: S105 - the OAuth token type, not a secret
    expires_in: int
    """Access token lifetime, seconds."""
    refresh_token: str
    refresh_expires_in: int
    """Refresh token lifetime, seconds."""


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    role: UserRole
    created_at: datetime
