"""Request and response bodies of `/v1/uploads`, `/v1/contributions`, `/v1/score/preview`,
`/v1/reports` and the moderation endpoints (`/v1/admin/...`).

Nutrient amounts arrive as JSON numbers (floats) and are read as the shortest decimal that
prints the same (`Decimal(repr(x))`), like the scoring engine does.
"""

import uuid
from datetime import datetime
from enum import StrEnum
from typing import Annotated, Any, Self

from pydantic import (
    AwareDatetime,
    BaseModel,
    ConfigDict,
    Field,
    StringConstraints,
    field_validator,
    model_validator,
)

from app.modules.contributions.models import (
    CLIENT_ID_PATTERN,
    REPORT_COMMENT_MAX_LENGTH,
    ContributionStatus,
    FallbackReason,
    FallbackStatus,
    ParserUsed,
    ReportReason,
    ReportStatus,
)
from app.modules.products.models import NutritionBasis
from app.modules.scoring.models import Category, Grade

MAX_TEXT_LENGTH = 200
MAX_OCR_LENGTH = 20_000
MAX_NOTE_LENGTH = 500

Grams = Annotated[float, Field(ge=0, le=100, allow_inf_nan=False)]
Energy = Annotated[float, Field(ge=0, allow_inf_nan=False)]
PhotoKey = Annotated[str, StringConstraints(min_length=1, max_length=300)]
OcrText = Annotated[str, StringConstraints(max_length=MAX_OCR_LENGTH)]


def _clean(value: object) -> object:
    """Trimmed text; blank means not given."""
    if isinstance(value, str):
        return value.strip() or None
    return value


class PhotoKind(StrEnum):
    """Which side of the package a contribution photo shows."""

    FRONT = "front"
    NUTRITION = "nutrition"
    INGREDIENTS = "ingredients"


class PhotoContentType(StrEnum):
    JPEG = "image/jpeg"
    PNG = "image/png"


class UploadRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    contribution_id: uuid.UUID
    """Client-generated id of the contribution the photo belongs to (the outbox id)."""
    kind: PhotoKind
    content_type: PhotoContentType
    size_bytes: int = Field(gt=0)
    """Exact size of the file to upload."""


class UploadTicket(BaseModel):
    """Upload the file with `PUT url`, sending exactly the requested `Content-Type` and
    `Content-Length` (both are signed: storage rejects anything else). Then refer to the
    photo by `key` when submitting the contribution."""

    key: str
    url: str
    expires_at: datetime


# ---------------------------------------------------------------- nutrition and preview


class _Request(BaseModel):
    model_config = ConfigDict(extra="forbid")


class NutritionValues(_Request):
    """Per 100 g or 100 mL, as declared on the label; null or missing: not declared."""

    energy_kj: Energy | None = None
    sugars_g: Grams | None = None
    saturated_fat_g: Grams | None = None
    total_fat_g: Grams | None = None
    salt_g: Grams | None = None
    fibre_g: Grams | None = None
    protein_g: Grams | None = None
    fvl_percent: Grams | None = None
    """Fruits, vegetables and legumes, % of the product."""
    non_nutritive_sweeteners: bool | None = None
    """Beverages: contains a non-nutritive sweetener."""


class ScorePreviewRequest(_Request):
    category: Category
    nutrition: NutritionValues


class ScorePreview(BaseModel):
    """The score the product would get, computed by the server's engine; nothing is
    saved. Same fields as a product's score."""

    engine_version: str
    grade: Grade | None
    """None when the data is insufficient (see `breakdown.insufficient_data`)."""
    total: int | None
    breakdown: dict[str, Any]


# ---------------------------------------------------------------- contributions


class ContributionPhotos(_Request):
    """Keys returned by `POST /v1/uploads` for this contribution, once uploaded."""

    front: PhotoKey
    nutrition: PhotoKey
    ingredients: PhotoKey | None = None


class ContributionOcr(_Request):
    """Text read from each photo on the phone."""

    front: OcrText | None = None
    nutrition: OcrText | None = None
    ingredients: OcrText | None = None


class ContributionCreate(_Request):
    client_id: uuid.UUID
    """The id used for the photo uploads; sending the same contribution again (retries)
    returns the stored one."""
    ean: str = Field(max_length=32)
    name: str | None = Field(default=None, max_length=MAX_TEXT_LENGTH)
    brand: str | None = Field(default=None, max_length=MAX_TEXT_LENGTH)
    category: Category
    """Nutri-Score category, chosen by the contributor."""
    basis: NutritionBasis
    nutrition: NutritionValues
    photos: ContributionPhotos
    ocr_text: ContributionOcr = Field(default_factory=ContributionOcr)
    parser_used: ParserUsed

    _clean_text = field_validator("name", "brand", mode="before")(_clean)


class ContributionRead(BaseModel):
    """A contribution as its contributor sees it."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    client_id: uuid.UUID
    ean: str
    name: str | None
    brand: str | None
    category: Category
    status: ContributionStatus
    review_note: str | None
    """Why it was rejected, if it was."""
    created_at: datetime
    reviewed_at: datetime | None


class ContributionList(BaseModel):
    items: list[ContributionRead]
    """Newest first."""


class ContributionReview(ContributionRead):
    """Everything a moderator needs to decide."""

    user_id: uuid.UUID | None
    basis: NutritionBasis
    nutrition: dict[str, Any]
    """Declared amounts as decimal strings; missing keys are not declared."""
    photos: dict[str, str]
    ocr_text: dict[str, str]
    parser_used: ParserUsed
    reviewed_by: uuid.UUID | None
    product_id: uuid.UUID | None
    submitted_values: dict[str, Any] | None
    """What the contributor sent (name, brand, category, basis, nutrition) when a moderator
    has edited it; None if never edited."""
    photos_deleted_at: datetime | None
    """Set once the cleanup deleted the photos (rejected contributions)."""


class ContributionDetail(ContributionReview):
    photo_urls: dict[str, str]
    """Photo kind -> a link to the private photo that works for a few minutes. Empty once
    the photos are deleted."""


class ContributionEdit(_Request):
    """A moderator's corrections to a pending contribution; only the fields sent change.
    `nutrition` replaces all the values (missing ones: not declared)."""

    name: str | None = Field(default=None, max_length=MAX_TEXT_LENGTH)
    brand: str | None = Field(default=None, max_length=MAX_TEXT_LENGTH)
    category: Category | None = None
    basis: NutritionBasis | None = None
    nutrition: NutritionValues | None = None

    _clean_text = field_validator("name", "brand", mode="before")(_clean)

    @model_validator(mode="after")
    def _something_to_change(self) -> Self:
        if not self.model_fields_set:
            raise ValueError("nothing to change")
        for name in ("category", "basis", "nutrition"):
            if name in self.model_fields_set and getattr(self, name) is None:
                raise ValueError(f"{name} can't be removed")
        return self


class ContributionReviewList(BaseModel):
    items: list[ContributionReview]
    """Oldest first: the moderation queue."""


class ReviewDecision(_Request):
    note: str | None = Field(default=None, max_length=MAX_NOTE_LENGTH)
    """Shown to the contributor (e.g. why it was rejected)."""

    _clean_note = field_validator("note", mode="before")(_clean)


# ---------------------------------------------------------------- error reports


class ReportCreate(_Request):
    """As queued by the app (T20)."""

    client_id: Annotated[str, StringConstraints(pattern=CLIENT_ID_PATTERN)]
    """32 hex digits; a report sent again is stored once."""
    ean: str = Field(max_length=32)
    reasons: list[ReportReason] = Field(min_length=1, max_length=len(ReportReason))
    comment: str | None = Field(default=None, max_length=REPORT_COMMENT_MAX_LENGTH)
    """Required with `other`."""
    product_updated_at: AwareDatetime
    """The `updated_at` of the product as shown when reporting."""
    created_at: AwareDatetime
    """When the user sent the report."""

    _clean_comment = field_validator("comment", mode="before")(_clean)

    @field_validator("reasons")
    @classmethod
    def _unique_reasons(cls, reasons: list[ReportReason]) -> list[ReportReason]:
        return [reason for reason in ReportReason if reason in reasons]

    @model_validator(mode="after")
    def _other_needs_comment(self) -> Self:
        if ReportReason.OTHER in self.reasons and self.comment is None:
            raise ValueError("a comment is required with reason `other`")
        return self


class ReportReceipt(BaseModel):
    client_id: str
    received_at: datetime
    """When the server first stored it."""


class ErrorReportRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    client_id: str
    ean: str
    product_id: uuid.UUID | None
    user_id: uuid.UUID | None
    reasons: list[ReportReason]
    comment: str | None
    product_updated_at: datetime
    reported_at: datetime
    status: ReportStatus
    created_at: datetime
    resolved_by: uuid.UUID | None
    resolved_at: datetime | None


class ErrorReportList(BaseModel):
    items: list[ErrorReportRead]
    """Oldest first."""


# ---------------------------------------------------------------- label parsing


class LabelParseRequest(_Request):
    ocr_text: OcrText
    """Text read from the photo of the nutrition table (ML Kit)."""


class LabelValues(BaseModel):
    """Values read from the label, per 100 g or 100 mL; null: not found. Not checked
    against the request limits: a value can be impossible (see `issues`)."""

    energy_kj: float | None = None
    energy_kcal: float | None = None
    total_fat_g: float | None = None
    saturated_fat_g: float | None = None
    carbohydrates_g: float | None = None
    """Not used for the score; read for the checks and the review form."""
    sugars_g: float | None = None
    fibre_g: float | None = None
    protein_g: float | None = None
    salt_g: float | None = None
    sodium_g: float | None = None


class LabelIssueRead(BaseModel):
    code: str
    """`missing`, `per_portion_only`, `sugars_over_carbohydrates`, ... (a newer server may
    add codes)."""
    field: str | None
    """The value concerned (a `LabelValues` field), if any."""
    blocking: bool
    """False for warnings (e.g. `basis_unknown`); a blocking issue means the values need
    checking by hand."""


class LabelReading(BaseModel):
    """Values read from a label by one parser."""

    parser_used: ParserUsed
    """`rules` (rule-based parser) or `llm` (the fallback)."""
    ok: bool
    """True when every mandatory value was read and passed the checks. The contributor
    reviews the values either way."""
    basis: NutritionBasis | None
    values: LabelValues
    derived: list[str]
    """Fields computed from another (salt from sodium, kJ from kcal)."""
    approximate: list[str]
    """Fields written as "< x" (read as x) or "traces" (read as 0)."""
    issues: list[LabelIssueRead]


class LabelFallbackRead(BaseModel):
    """The LLM fallback parser's reading of a label, read in the background."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    status: FallbackStatus
    """`pending` (ask again shortly), `done` (see `result`) or `needs_manual_entry`."""
    reason: FallbackReason | None
    """Why there are no values, with `needs_manual_entry`."""
    result: LabelReading | None
    """With `done`: values that passed the checks, `parser_used` `llm`."""
    created_at: datetime
    completed_at: datetime | None


class LabelParseResult(LabelReading):
    """The rule-based parser's reading, and the LLM fallback when that one is not ok."""

    fallback: LabelFallbackRead | None = None
    """Set when the rules reading is not ok and the fallback is enabled: poll
    `GET /v1/labels/parse/{id}` while it is `pending`. Null otherwise."""
