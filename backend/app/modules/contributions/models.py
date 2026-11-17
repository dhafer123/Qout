"""ORM models for contributions (unknown products added from label photos) and error
reports on products.

No ORM relationships, like the other modules: services query explicitly.
"""

import uuid
from datetime import datetime
from enum import StrEnum
from typing import Any

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.core.models import Base, IdTimestampMixin, str_enum
from app.modules.products.models import EAN_PATTERN, NutritionBasis
from app.modules.scoring.models import Category

CLIENT_ID_PATTERN = "^[0-9a-f]{32}$"
REPORT_COMMENT_MAX_LENGTH = 500


class ContributionStatus(StrEnum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class ParserUsed(StrEnum):
    """What filled in the fields before the contributor reviewed them."""

    RULES = "rules"  # rule-based label parser (T26)
    LLM = "llm"  # LLM fallback parser (T28)
    MANUAL = "manual"  # typed by the contributor


class FallbackStatus(StrEnum):
    """A request to the LLM fallback parser (T28)."""

    PENDING = "pending"
    DONE = "done"  # read and passed the checks: values to review
    NEEDS_MANUAL_ENTRY = "needs_manual_entry"


class FallbackReason(StrEnum):
    """Why the LLM fallback gave no values (the contributor types them)."""

    DISABLED = "disabled"  # the fallback is turned off
    RATE_LIMITED = "rate_limited"  # too many readings asked for by this user
    TIMEOUT = "timeout"  # no answer in time (queue wait included)
    UNAVAILABLE = "unavailable"  # the LLM service (or the job queue) failed
    REFUSED = "refused"  # the model declined
    INVALID_OUTPUT = "invalid_output"  # not the expected JSON, or truncated
    UNGROUNDED_VALUE = "ungrounded_value"  # a value that isn't in the OCR text
    FAILED_CHECKS = "failed_checks"  # same sanity checks as the rules parser


class Contribution(IdTimestampMixin, Base):
    """A product as a contributor submitted it: photos, OCR text and the fields they
    reviewed. Approval (moderation) turns it into a verified product."""

    __tablename__ = "contributions"
    __table_args__ = (
        UniqueConstraint("user_id", "client_id"),
        CheckConstraint(f"ean ~ '{EAN_PATTERN}'", name="ean_digits"),
        Index("ix_contributions_status_created_at", "status", "created_at"),
    )

    user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    """The contributor; None once their account is deleted (the history stays)."""
    client_id: Mapped[uuid.UUID] = mapped_column(index=True)
    """The app's id for the contribution (also in its photo keys): a resend is the same
    contribution. Indexed on its own for the upload cleanup, which finds contributions
    from photo keys (`user_id` is None once the account is deleted)."""
    ean: Mapped[str] = mapped_column(String(14), index=True)
    name: Mapped[str | None] = mapped_column(Text)
    brand: Mapped[str | None] = mapped_column(Text)
    category: Mapped[Category] = mapped_column(str_enum(Category, "contribution_category"))
    basis: Mapped[NutritionBasis] = mapped_column(
        str_enum(NutritionBasis, "contribution_nutrition_basis")
    )
    nutrition: Mapped[dict[str, Any]] = mapped_column(JSONB)
    """Declared amounts per 100 g / 100 mL as exact decimal strings (`"1.5"`), booleans for
    flags; a missing key is not declared."""
    submitted_values: Mapped[dict[str, Any] | None] = mapped_column(JSONB)
    """The contributor's own name, brand, category, basis and nutrition, saved when a
    moderator first edits them (None: never edited)."""
    photos: Mapped[dict[str, str]] = mapped_column(JSONB)
    """Photo kind (`front`, `nutrition`, `ingredients`) -> key in the private bucket. Kept
    as history once the photos are deleted (`photos_deleted_at`)."""
    photos_deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    """When the cleanup deleted the photos from storage (rejected contributions)."""
    ocr_text: Mapped[dict[str, str]] = mapped_column(JSONB)
    """Photo kind -> text read on the phone (ML Kit)."""
    parser_used: Mapped[ParserUsed] = mapped_column(str_enum(ParserUsed, "contribution_parser"))
    status: Mapped[ContributionStatus] = mapped_column(
        str_enum(ContributionStatus, "contribution_status"),
        server_default=ContributionStatus.PENDING.value,
    )
    reviewed_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL")
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    review_note: Mapped[str | None] = mapped_column(Text)
    """Why it was rejected (shown to the contributor), or a moderator's remark."""
    product_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("products.id", ondelete="SET NULL")
    )
    """The product created or updated by approval."""


class LabelFallback(IdTimestampMixin, Base):
    """One request to the LLM fallback parser (T28): the nutrition table's OCR text, then
    the reading (`done`) or why there is none (`needs_manual_entry`)."""

    __tablename__ = "label_fallbacks"
    __table_args__ = (
        CheckConstraint("(status = 'done') = (result IS NOT NULL)", name="result_when_done"),
        CheckConstraint(
            "(status = 'needs_manual_entry') = (reason IS NOT NULL)", name="reason_when_failed"
        ),
        CheckConstraint(
            "(status = 'pending') = (completed_at IS NULL)", name="completed_unless_pending"
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    """Who asked; only they can read it."""
    ocr_text: Mapped[str] = mapped_column(Text)
    """The text sent to the model (nothing else is)."""
    status: Mapped[FallbackStatus] = mapped_column(
        str_enum(FallbackStatus, "label_fallback_status"),
        server_default=FallbackStatus.PENDING.value,
    )
    reason: Mapped[FallbackReason | None] = mapped_column(
        str_enum(FallbackReason, "label_fallback_reason")
    )
    result: Mapped[dict[str, Any] | None] = mapped_column(JSONB)
    """The accepted reading (`LabelReading`, `parser_used` `llm`)."""
    model: Mapped[str | None] = mapped_column(String(100))
    """The model that answered."""
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class ReportReason(StrEnum):
    NAME = "name"
    NUTRITION = "nutrition"
    GRADE = "grade"
    ADDITIVES = "additives"
    OTHER = "other"


class ReportStatus(StrEnum):
    OPEN = "open"
    RESOLVED = "resolved"
    DISMISSED = "dismissed"


class ErrorReport(IdTimestampMixin, Base):
    """ "Report an error" from the result screen. Anonymous unless sent with a token."""

    __tablename__ = "error_reports"
    __table_args__ = (
        CheckConstraint(f"client_id ~ '{CLIENT_ID_PATTERN}'", name="client_id_hex"),
        CheckConstraint(f"ean ~ '{EAN_PATTERN}'", name="ean_digits"),
        CheckConstraint("cardinality(reasons) > 0", name="has_reasons"),
        CheckConstraint(
            f"char_length(comment) <= {REPORT_COMMENT_MAX_LENGTH}", name="comment_length"
        ),
        Index("ix_error_reports_status_created_at", "status", "created_at"),
    )

    client_id: Mapped[str] = mapped_column(String(32), unique=True)
    """Generated by the app (32 hex digits): a resent report is stored once."""
    ean: Mapped[str] = mapped_column(String(14))
    product_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("products.id", ondelete="SET NULL"), index=True
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    reasons: Mapped[list[str]] = mapped_column(ARRAY(String(16)))
    comment: Mapped[str | None] = mapped_column(Text)
    product_updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    """The product's `updated_at` as the reporter saw it: which version was wrong."""
    reported_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    """When the user sent it (the app queues reports while offline)."""
    status: Mapped[ReportStatus] = mapped_column(
        str_enum(ReportStatus, "report_status"), server_default=ReportStatus.OPEN.value
    )
    resolved_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL")
    )
    """The moderator who resolved or dismissed it."""
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
