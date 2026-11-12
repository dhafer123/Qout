"""Input and result types of the Nutri-Score engine.

Plain frozen dataclasses: the engine has no dependency on FastAPI, Pydantic or the database.
Nutrient values are per 100 g (per 100 mL for beverages), as declared on the label.
"""

import math
from collections.abc import Mapping
from dataclasses import dataclass, fields
from enum import StrEnum

ENGINE_VERSION = "nutriscore-2023.2"
"""Algorithm version (updated Nutri-Score, 2023) plus our own revision.

Bump the revision whenever the engine's output can change for the same input: stored scores
with an older version are rescored.
"""


class Category(StrEnum):
    """Scoring category. Choosing it is the caller's job (see docs/specs/README.md)."""

    GENERAL = "general"
    RED_MEAT = "red_meat"
    CHEESE = "cheese"
    FATS_OILS_NUTS_SEEDS = "fats_oils_nuts_seeds"
    BEVERAGE = "beverage"
    WATER = "water"


class Grade(StrEnum):
    A = "A"
    B = "B"
    C = "C"
    D = "D"
    E = "E"


_GRAM_FIELDS = frozenset(
    {"sugars_g", "saturated_fat_g", "total_fat_g", "salt_g", "fibre_g", "protein_g"}
)
_MAX_GRAMS = 100.0  # an amount per 100 g cannot exceed 100 g
_MAX_PERCENT = 100.0


@dataclass(frozen=True, slots=True, kw_only=True)
class NutritionInput:
    """Declared nutrition values. `None` means "not declared".

    Only the fields used by the category matter; missing ones make the result
    `InsufficientData`. Impossible values (negative, NaN, infinite, more than 100 g per
    100 g, a percentage above 100) raise `ValueError`.
    """

    energy_kj: float | None = None
    sugars_g: float | None = None
    saturated_fat_g: float | None = None
    total_fat_g: float | None = None
    salt_g: float | None = None
    fibre_g: float | None = None
    protein_g: float | None = None
    fvl_percent: float | None = None
    """Fruits, vegetables and legumes, % of the product (Q&A Appendix 2)."""
    non_nutritive_sweeteners: bool | None = None
    """Beverages only: contains at least one non-nutritive sweetener (Q&A Appendix 3)."""

    def __post_init__(self) -> None:
        for field in fields(self):
            value = getattr(self, field.name)
            if value is None:
                continue
            if field.name == "non_nutritive_sweeteners":
                if not isinstance(value, bool):
                    msg = f"{field.name} must be a bool, got {value!r}"
                    raise ValueError(msg)
                continue
            _check_amount(field.name, value)


def _check_amount(name: str, value: object) -> None:
    if isinstance(value, bool) or not isinstance(value, int | float):
        msg = f"{name} must be a number, got {value!r}"
        raise ValueError(msg)
    if not math.isfinite(value) or value < 0:
        msg = f"{name} must be a finite number >= 0, got {value!r}"
        raise ValueError(msg)
    if name in _GRAM_FIELDS and value > _MAX_GRAMS:
        msg = f"{name} must be <= {_MAX_GRAMS:g} g per 100 g, got {value!r}"
        raise ValueError(msg)
    if name == "fvl_percent" and value > _MAX_PERCENT:
        msg = f"{name} must be <= {_MAX_PERCENT:g} %, got {value!r}"
        raise ValueError(msg)


@dataclass(frozen=True, slots=True)
class Breakdown:
    """Points per component: the "why this score" part of a result.

    `positive_total` is the sum of all three positive components, even when protein is
    left out of the score (`protein_counted` is False). `assumed_zero` lists undeclared
    inputs that were scored as 0 points (decision 8).
    """

    negative: Mapping[str, int]
    positive: Mapping[str, int]
    negative_total: int
    positive_total: int
    protein_counted: bool
    score: int
    assumed_zero: tuple[str, ...] = ()
    """Undeclared inputs scored as 0 points (decision 8: fibre only)."""


@dataclass(frozen=True, slots=True)
class NutriScore:
    """A graded product. `breakdown` is None for water, which is always A without points."""

    category: Category
    grade: Grade
    breakdown: Breakdown | None
    engine_version: str = ENGINE_VERSION


@dataclass(frozen=True, slots=True)
class InsufficientData:
    """No grade: inputs the category needs are missing or unusable (sorted field names)."""

    category: Category
    missing: tuple[str, ...]
    engine_version: str = ENGINE_VERSION


ScoreResult = NutriScore | InsufficientData
