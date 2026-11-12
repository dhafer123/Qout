"""ORM models for products, their nutrition facts, scores and scan events.

Constraints live in the database too (CHECKs, unique EAN), so bad rows are rejected even
if they bypass the repositories. No ORM relationships: repositories query explicitly,
which keeps async code free of lazy loading.
"""

import uuid
from datetime import datetime
from decimal import Decimal
from enum import StrEnum
from typing import Any

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.core.models import Base, IdTimestampMixin
from app.modules.scoring.models import Category, Grade

EAN_PATTERN = "^[0-9]{8,14}$"


class DataSource(StrEnum):
    OPEN_FOOD_FACTS = "open_food_facts"
    CONTRIBUTION = "contribution"
    MANUAL = "manual"


class ProductStatus(StrEnum):
    UNVERIFIED = "unverified"  # imported or provisional, not reviewed
    VERIFIED = "verified"  # reviewed by a moderator (T25, T31)
    HIDDEN = "hidden"  # withdrawn, e.g. after an error report


class QualityFlag(StrEnum):
    """Data quality, set by the Open Food Facts normaliser (T13)."""

    COMPLETE = "complete"
    INCOMPLETE = "incomplete"
    SUSPECT = "suspect"


class NutritionBasis(StrEnum):
    PER_100G = "per_100g"
    PER_100ML = "per_100ml"


class ScanOutcome(StrEnum):
    FOUND = "found"
    NOT_FOUND = "not_found"


def _enum[E: StrEnum](enum: type[E], name: str) -> Enum:
    """Stored as VARCHAR + CHECK (no native PG enum: easier to extend in migrations)."""
    return Enum(
        enum,
        name=name,
        native_enum=False,
        create_constraint=True,
        length=max(len(member.value) for member in enum),
        values_callable=lambda members: [member.value for member in members],
        validate_strings=True,
    )


class Product(IdTimestampMixin, Base):
    __tablename__ = "products"
    __table_args__ = (
        CheckConstraint(f"ean ~ '{EAN_PATTERN}'", name="ean_digits"),
        CheckConstraint("nova_group BETWEEN 1 AND 4", name="nova_group_range"),
    )

    ean: Mapped[str] = mapped_column(String(14), unique=True)
    name: Mapped[str | None] = mapped_column(Text)
    brand: Mapped[str | None] = mapped_column(Text)
    category: Mapped[Category | None] = mapped_column(_enum(Category, "product_category"))
    image_url: Mapped[str | None] = mapped_column(Text)
    source: Mapped[DataSource] = mapped_column(_enum(DataSource, "product_source"))
    status: Mapped[ProductStatus] = mapped_column(
        _enum(ProductStatus, "product_status"), server_default=ProductStatus.UNVERIFIED.value
    )
    quality_flag: Mapped[QualityFlag | None] = mapped_column(
        _enum(QualityFlag, "product_quality_flag")
    )
    nova_group: Mapped[int | None] = mapped_column(SmallInteger)
    additives: Mapped[list[str]] = mapped_column(
        ARRAY(String(16)), server_default=text("'{}'::varchar[]")
    )
    """Additive codes as in the taxonomy (E330, E160a(i)); risk is looked up on read."""
    source_modified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    """When the source last changed the product (OFF `last_modified_t`). Imports never
    replace newer data with an older record."""


AMOUNT_COLUMNS = (
    "energy_kj",
    "sugars_g",
    "saturated_fat_g",
    "total_fat_g",
    "salt_g",
    "fibre_g",
    "protein_g",
    "fvl_percent",
)
_AT_MOST_100 = ("sugars_g", "saturated_fat_g", "total_fat_g", "salt_g", "fibre_g", "protein_g",
                "fvl_percent")  # fmt: skip


def _amount_checks() -> tuple[CheckConstraint, ...]:
    checks = [CheckConstraint(f"{c} >= 0", name=f"{c}_non_negative") for c in AMOUNT_COLUMNS]
    checks += [CheckConstraint(f"{c} <= 100", name=f"{c}_at_most_100") for c in _AT_MOST_100]
    return tuple(checks)


class NutritionFacts(IdTimestampMixin, Base):
    """One version of a product's declared nutrition (per 100 g or 100 mL).

    Never edited in place: a correction adds a new version. Amounts are exact NUMERIC
    values as declared (the scoring engine compares exact decimals).
    """

    __tablename__ = "nutrition_facts"
    __table_args__ = (
        UniqueConstraint("product_id", "version"),
        CheckConstraint("version >= 1", name="version_positive"),
        *_amount_checks(),
    )

    # Indexed by the (product_id, version) unique constraint.
    product_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"))
    version: Mapped[int] = mapped_column(Integer)
    basis: Mapped[NutritionBasis] = mapped_column(_enum(NutritionBasis, "nutrition_basis"))
    source: Mapped[DataSource] = mapped_column(_enum(DataSource, "nutrition_source"))
    energy_kj: Mapped[Decimal | None] = mapped_column(Numeric)
    sugars_g: Mapped[Decimal | None] = mapped_column(Numeric)
    saturated_fat_g: Mapped[Decimal | None] = mapped_column(Numeric)
    total_fat_g: Mapped[Decimal | None] = mapped_column(Numeric)
    salt_g: Mapped[Decimal | None] = mapped_column(Numeric)
    fibre_g: Mapped[Decimal | None] = mapped_column(Numeric)
    protein_g: Mapped[Decimal | None] = mapped_column(Numeric)
    fvl_percent: Mapped[Decimal | None] = mapped_column(Numeric)
    non_nutritive_sweeteners: Mapped[bool | None] = mapped_column(Boolean)


class Score(IdTimestampMixin, Base):
    """The engine's result for one nutrition facts version and engine version.

    `breakdown` is the golden `expected` block (scoring-spec/README.md): points per
    component, `{"grade": "A"}` for water (grade, no total), or
    `{"insufficient_data": [...]}` (no grade, no total).
    """

    __tablename__ = "scores"
    __table_args__ = (
        UniqueConstraint("nutrition_facts_id", "engine_version"),
        CheckConstraint("total IS NULL OR grade IS NOT NULL", name="total_needs_grade"),
        Index("ix_scores_product_id_created_at", "product_id", "created_at"),
    )

    # Real write time, not the transaction start (`now()`): several scores written in one
    # transaction (rescoring) must still order correctly for the latest-score query.
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.clock_timestamp()
    )
    product_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"))
    nutrition_facts_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("nutrition_facts.id", ondelete="CASCADE")
    )
    """None for water, which is graded without nutrition facts."""
    engine_version: Mapped[str] = mapped_column(String(32))
    grade: Mapped[Grade | None] = mapped_column(_enum(Grade, "score_grade"))
    total: Mapped[int | None] = mapped_column(Integer)
    breakdown: Mapped[dict[str, Any]] = mapped_column(JSONB)
    off_grade: Mapped[Grade | None] = mapped_column(_enum(Grade, "score_off_grade"))
    """Open Food Facts' own Nutri-Score grade, for the validation report (T16)."""


class ScanEvent(IdTimestampMixin, Base):
    """A barcode lookup. No user or device id: scanning needs no account."""

    __tablename__ = "scan_events"
    __table_args__ = (CheckConstraint(f"ean ~ '{EAN_PATTERN}'", name="ean_digits"),)

    ean: Mapped[str] = mapped_column(String(14), index=True)
    product_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("products.id", ondelete="SET NULL")
    )
    outcome: Mapped[ScanOutcome] = mapped_column(_enum(ScanOutcome, "scan_outcome"))
