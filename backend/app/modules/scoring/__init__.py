"""Nutri-Score engine (updated algorithm, 2023). Pure functions, no I/O.

Every threshold comes from docs/specs/ (see docs/specs/README.md). The Dart engine in
`app/` must give identical results on every `scoring-spec/golden/*.json` case.
"""

from app.modules.scoring.conversions import kj_from_kcal, salt_from_sodium
from app.modules.scoring.engine import REQUIRED_FIELDS, score
from app.modules.scoring.models import (
    ENGINE_VERSION,
    Breakdown,
    Category,
    Grade,
    InsufficientData,
    NutriScore,
    NutritionInput,
    ScoreResult,
)

__all__ = [
    "ENGINE_VERSION",
    "REQUIRED_FIELDS",
    "Breakdown",
    "Category",
    "Grade",
    "InsufficientData",
    "NutriScore",
    "NutritionInput",
    "ScoreResult",
    "kj_from_kcal",
    "salt_from_sodium",
    "score",
]
