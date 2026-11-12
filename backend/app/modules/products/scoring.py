"""Mapping between stored products and the scoring engine (both directions)."""

import uuid

from app.modules.products.models import NutritionFacts, Score
from app.modules.scoring import InsufficientData, NutritionInput, ScoreResult
from app.modules.scoring.models import Grade
from app.modules.scoring.spec_json import expected_to_spec


def nutrition_input(facts: NutritionFacts) -> NutritionInput:
    """Engine input from stored nutrition facts.

    NUMERIC values go through `float`, which keeps any value with up to 15 significant
    digits exact; the engine then reads the float back as the same decimal.
    """

    def amount(name: str) -> float | None:
        value = getattr(facts, name)
        return None if value is None else float(value)

    return NutritionInput(
        energy_kj=amount("energy_kj"),
        sugars_g=amount("sugars_g"),
        saturated_fat_g=amount("saturated_fat_g"),
        total_fat_g=amount("total_fat_g"),
        salt_g=amount("salt_g"),
        fibre_g=amount("fibre_g"),
        protein_g=amount("protein_g"),
        fvl_percent=amount("fvl_percent"),
        non_nutritive_sweeteners=facts.non_nutritive_sweeteners,
    )


def score_row(
    result: ScoreResult,
    *,
    product_id: uuid.UUID,
    nutrition_facts_id: uuid.UUID | None,
    off_grade: Grade | None = None,
) -> Score:
    """A `scores` row for an engine result (not added to any session).

    Insufficient data: no grade, no total. Water: grade A, no total (no points).
    """
    if isinstance(result, InsufficientData):
        grade, total = None, None
    else:
        grade = result.grade
        total = None if result.breakdown is None else result.breakdown.score
    return Score(
        product_id=product_id,
        nutrition_facts_id=nutrition_facts_id,
        engine_version=result.engine_version,
        grade=grade,
        total=total,
        breakdown=expected_to_spec(result),
        off_grade=off_grade,
    )
