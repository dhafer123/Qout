"""Contributed nutrition: from the request, to the stored contribution, to the engine and
to a product's nutrition facts. Pure functions.

Amounts arrive as floats and are kept as the shortest decimal that prints the same
(`Decimal(repr(x))`): what the contributor typed, and what the engine compares.
"""

from decimal import Decimal
from typing import Any

from app.modules.contributions.schemas import NutritionValues, ScorePreview
from app.modules.products.models import AMOUNT_COLUMNS
from app.modules.products.scoring import grade_and_total
from app.modules.scoring import Category, NutritionInput, score
from app.modules.scoring.spec_json import expected_to_spec

FLAG = "non_nutritive_sweeteners"


def stored_nutrition(values: NutritionValues) -> dict[str, Any]:
    """Declared values only, amounts as decimal strings (exact in JSON)."""
    record: dict[str, Any] = {}
    for name in AMOUNT_COLUMNS:
        value = getattr(values, name)
        if value is not None:
            record[name] = str(Decimal(repr(value)))
    if values.non_nutritive_sweeteners is not None:
        record[FLAG] = values.non_nutritive_sweeteners
    return record


def facts_values(record: dict[str, Any]) -> dict[str, Any]:
    """Column values for `NutritionFacts` from a stored contribution (missing: None)."""
    values: dict[str, Any] = {
        name: None if record.get(name) is None else Decimal(record[name]) for name in AMOUNT_COLUMNS
    }
    values[FLAG] = record.get(FLAG)
    return values


def engine_input(values: NutritionValues) -> NutritionInput:
    """The request schema enforces the engine's bounds (no negative amounts, at most
    100 g per 100 g, finite numbers), so this never raises."""
    return NutritionInput(**values.model_dump())


def score_preview(category: Category, values: NutritionValues) -> ScorePreview:
    result = score(category, engine_input(values))
    grade, total = grade_and_total(result)
    return ScorePreview(
        engine_version=result.engine_version,
        grade=grade,
        total=total,
        breakdown=expected_to_spec(result),
    )
