"""Nutri-Score engine (updated algorithm, 2023) and extra signals (NOVA, additives).

Every threshold comes from docs/specs/ (see docs/specs/README.md). The Dart engine in
`app/` must give identical results on every `scoring-spec/golden/*.json` case.
"""

from app.modules.scoring.additives import (
    Additive,
    OverexposureRisk,
    additive,
    additives_from_off,
)
from app.modules.scoring.conversions import kj_from_kcal, salt_from_sodium
from app.modules.scoring.engine import REQUIRED_FIELDS, ZERO_IF_UNDECLARED, score
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
from app.modules.scoring.nova import NovaGroup, nova_group_from_off

__all__ = [
    "ENGINE_VERSION",
    "REQUIRED_FIELDS",
    "ZERO_IF_UNDECLARED",
    "Additive",
    "Breakdown",
    "Category",
    "Grade",
    "InsufficientData",
    "NovaGroup",
    "NutriScore",
    "NutritionInput",
    "OverexposureRisk",
    "ScoreResult",
    "additive",
    "additives_from_off",
    "kj_from_kcal",
    "nova_group_from_off",
    "salt_from_sodium",
    "score",
]
