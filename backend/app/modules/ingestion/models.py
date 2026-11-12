"""Bookkeeping for bulk imports: one row per imported file (and country list).

A run is committed together with every batch of products, so `checkpoint_line` always
says how far the file has been imported; an interrupted run resumes from there.
"""

from datetime import datetime
from enum import StrEnum

from sqlalchemy import ARRAY, CheckConstraint, DateTime, Index, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.models import Base, IdTimestampMixin, str_enum


class ImportKind(StrEnum):
    FULL = "full"
    """The full Open Food Facts export."""
    DELTA = "delta"
    """A daily delta file."""


class ImportStatus(StrEnum):
    RUNNING = "running"
    """In progress, or interrupted (worker stopped): resumed by the next run."""
    COMPLETED = "completed"
    FAILED = "failed"
    """Stopped by an error (see `error`); resumed by the next run."""


COUNTER_COLUMNS = (
    "lines",
    "selected",
    "inserted",
    "updated",
    "unchanged",
    "skipped",
    "rejected",
    "failed",
)


class ImportRun(IdTimestampMixin, Base):
    __tablename__ = "import_runs"
    __table_args__ = (
        Index("ix_import_runs_kind_source", "kind", "source"),
        CheckConstraint("checkpoint_line >= 0", name="checkpoint_non_negative"),
        *(CheckConstraint(f"{c} >= 0", name=f"{c}_non_negative") for c in COUNTER_COLUMNS),
    )

    kind: Mapped[ImportKind] = mapped_column(str_enum(ImportKind, "import_kind"))
    source: Mapped[str] = mapped_column(String(255))
    """The file: its name, plus the ETag for the full export (rebuilt daily under the
    same name)."""
    countries: Mapped[list[str]] = mapped_column(ARRAY(String(64)))
    """OFF country tags imported, sorted."""
    status: Mapped[ImportStatus] = mapped_column(str_enum(ImportStatus, "import_status"))
    checkpoint_line: Mapped[int] = mapped_column(Integer, server_default="0")
    """Lines of the file fully imported and committed."""
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    error: Mapped[str | None] = mapped_column(Text)

    # Counters, cumulative over resumes. `selected`: products sold in an imported country
    # with a valid barcode; `skipped`: not from OFF or older than the stored data;
    # `rejected`: unusable lines; `failed`: products that raised an error while storing.
    lines: Mapped[int] = mapped_column(Integer, server_default="0")
    selected: Mapped[int] = mapped_column(Integer, server_default="0")
    inserted: Mapped[int] = mapped_column(Integer, server_default="0")
    updated: Mapped[int] = mapped_column(Integer, server_default="0")
    unchanged: Mapped[int] = mapped_column(Integer, server_default="0")
    skipped: Mapped[int] = mapped_column(Integer, server_default="0")
    rejected: Mapped[int] = mapped_column(Integer, server_default="0")
    failed: Mapped[int] = mapped_column(Integer, server_default="0")
