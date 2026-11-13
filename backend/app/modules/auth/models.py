"""ORM models for contributor accounts and their refresh tokens."""

import uuid
from datetime import datetime
from enum import StrEnum

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Index, String, true
from sqlalchemy.orm import Mapped, mapped_column

from app.core.models import Base, IdTimestampMixin, str_enum


class UserRole(StrEnum):
    CONTRIBUTOR = "contributor"
    """Adds products and reports errors (T25+)."""
    ADMIN = "admin"
    """Also moderates contributions (T31)."""


class User(IdTimestampMixin, Base):
    """An account. Only contributors need one: scanning is anonymous."""

    __tablename__ = "users"
    __table_args__ = (CheckConstraint("email = lower(email)", name="email_lowercase"),)

    email: Mapped[str] = mapped_column(String(254), unique=True)
    """Lower-cased; unique."""
    password_hash: Mapped[str] = mapped_column(String(255))
    """Argon2id hash (PHC string); the password itself is never stored."""
    role: Mapped[UserRole] = mapped_column(
        str_enum(UserRole, "user_role"), server_default=UserRole.CONTRIBUTOR.value
    )
    is_active: Mapped[bool] = mapped_column(Boolean, server_default=true())
    """Inactive accounts can neither log in nor refresh."""
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class RefreshToken(IdTimestampMixin, Base):
    """One refresh token. Logging in starts a family; each refresh uses the current token
    and adds the next one to the same family. Presenting a used token again means it was
    copied, so the whole family is revoked (reuse detection)."""

    __tablename__ = "refresh_tokens"
    __table_args__ = (Index("ix_refresh_tokens_family_id", "family_id"),)

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    family_id: Mapped[uuid.UUID]
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    """SHA-256 (hex) of the token: a database leak gives no usable token."""
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    """When it was exchanged for the next token."""
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    """Logout, or reuse detected in its family."""
