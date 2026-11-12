"""Pydantic schemas for products, nutrition facts, scores and scan events.

Separate from the ORM models (CLAUDE.md). Validation mirrors the database constraints so
bad input is rejected before it reaches Postgres. Nutrient amounts are Decimals (exact,
like the database and the engine) and serialise to JSON as numbers.
"""

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Annotated, Any

from pydantic import BaseModel, ConfigDict, Field, PlainSerializer, StringConstraints

from app.modules.products.models import (
    EAN_PATTERN,
    DataSource,
    NutritionBasis,
    ProductStatus,
    QualityFlag,
    ScanOutcome,
)
from app.modules.scoring.additives import OverexposureRisk
from app.modules.scoring.models import Category, Grade

Ean = Annotated[str, StringConstraints(pattern=EAN_PATTERN)]
NovaGroupValue = Annotated[int, Field(ge=1, le=4)]

_as_json_number = PlainSerializer(float, return_type=float, when_used="json")
Energy = Annotated[Decimal, Field(ge=0, allow_inf_nan=False), _as_json_number]
Grams = Annotated[Decimal, Field(ge=0, le=100, allow_inf_nan=False), _as_json_number]
Percent = Grams


class _Schema(BaseModel):
    model_config = ConfigDict(extra="forbid")


class _ReadSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# ---------------------------------------------------------------- products


class ProductFields(_Schema):
    name: str | None = None
    brand: str | None = None
    category: Category | None = None
    image_url: str | None = None
    quality_flag: QualityFlag | None = None
    nova_group: NovaGroupValue | None = None
    additives: list[str] = Field(default_factory=list)
    """Taxonomy codes (E330, E160a(i))."""


class ProductCreate(ProductFields):
    ean: Ean
    source: DataSource
    status: ProductStatus = ProductStatus.UNVERIFIED


class ProductRead(_ReadSchema):
    id: uuid.UUID
    ean: str
    name: str | None
    brand: str | None
    category: Category | None
    image_url: str | None
    source: DataSource
    status: ProductStatus
    quality_flag: QualityFlag | None
    nova_group: int | None
    additives: list[str]
    created_at: datetime
    updated_at: datetime


# ---------------------------------------------------------------- nutrition facts


class NutritionAmounts(_Schema):
    """Per 100 g (or 100 mL); None means not declared."""

    energy_kj: Energy | None = None
    sugars_g: Grams | None = None
    saturated_fat_g: Grams | None = None
    total_fat_g: Grams | None = None
    salt_g: Grams | None = None
    fibre_g: Grams | None = None
    protein_g: Grams | None = None
    fvl_percent: Percent | None = None
    non_nutritive_sweeteners: bool | None = None


class NutritionFactsCreate(NutritionAmounts):
    basis: NutritionBasis
    source: DataSource


class NutritionFactsRead(_ReadSchema):
    id: uuid.UUID
    product_id: uuid.UUID
    version: int
    basis: NutritionBasis
    source: DataSource
    energy_kj: Annotated[Decimal, _as_json_number] | None
    sugars_g: Annotated[Decimal, _as_json_number] | None
    saturated_fat_g: Annotated[Decimal, _as_json_number] | None
    total_fat_g: Annotated[Decimal, _as_json_number] | None
    salt_g: Annotated[Decimal, _as_json_number] | None
    fibre_g: Annotated[Decimal, _as_json_number] | None
    protein_g: Annotated[Decimal, _as_json_number] | None
    fvl_percent: Annotated[Decimal, _as_json_number] | None
    non_nutritive_sweeteners: bool | None
    created_at: datetime


# ---------------------------------------------------------------- scores and scans


class ScoreRead(_ReadSchema):
    id: uuid.UUID
    product_id: uuid.UUID
    nutrition_facts_id: uuid.UUID | None
    engine_version: str
    grade: Grade | None
    total: int | None
    breakdown: dict[str, Any]
    """The golden `expected` block: points per component, or `insufficient_data`."""
    off_grade: Grade | None
    created_at: datetime


class ScanEventCreate(_Schema):
    ean: Ean
    outcome: ScanOutcome
    product_id: uuid.UUID | None = None


# ---------------------------------------------------------------- lookup response


class AdditiveDetail(BaseModel):
    code: str
    """Taxonomy code, e.g. E330 or E160a(i)."""
    name: str | None
    overexposure_risk: OverexposureRisk
    """EFSA overexposure risk; `unknown` means not evaluated, not "no risk"."""


class NutritionDetail(BaseModel):
    """The latest declared nutrition, per 100 g or 100 mL (`basis`). None: not declared."""

    version: int
    basis: NutritionBasis
    source: DataSource
    energy_kj: Annotated[Decimal, _as_json_number] | None
    sugars_g: Annotated[Decimal, _as_json_number] | None
    saturated_fat_g: Annotated[Decimal, _as_json_number] | None
    total_fat_g: Annotated[Decimal, _as_json_number] | None
    salt_g: Annotated[Decimal, _as_json_number] | None
    fibre_g: Annotated[Decimal, _as_json_number] | None
    protein_g: Annotated[Decimal, _as_json_number] | None
    fvl_percent: Annotated[Decimal, _as_json_number] | None
    non_nutritive_sweeteners: bool | None


class ScoreDetail(BaseModel):
    engine_version: str
    grade: Grade | None
    """None when the data is insufficient (see `breakdown.insufficient_data`)."""
    total: int | None
    """Points (negative minus positive); None for water and insufficient data."""
    breakdown: dict[str, Any]
    """The golden `expected` block (scoring-spec/README.md): points per component and
    `assumed_zero`, `{"grade": "A"}` for water, or `{"insufficient_data": [fields]}`."""
    computed_at: datetime


class ProductDetail(BaseModel):
    """`GET /v1/products/{ean}`: everything the app shows for a scanned product."""

    ean: str
    """As stored: digits only, UPC-A as EAN-13."""
    name: str | None
    brand: str | None
    image_url: str | None
    category: Category | None
    source: DataSource
    status: ProductStatus
    quality_flag: QualityFlag | None
    nova_group: int | None
    additives: list[AdditiveDetail]
    nutrition: NutritionDetail | None
    score: ScoreDetail | None
    """None when the product's Nutri-Score category is unknown (nothing to score with)."""
    updated_at: datetime
    """Latest change to the product, its nutrition or its score."""


class ErrorResponse(BaseModel):
    detail: str
