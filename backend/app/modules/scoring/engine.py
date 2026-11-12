"""Nutri-Score computation (updated algorithm, 2023): N points, P points, score, grade.

Rules (Q&A V11 pp. 26-32; docs/specs/README.md "Where each rule lives"):
- general foods and red meat: N < 11 -> N - P; otherwise N - fibre - FVL (protein ignored);
- red meat: protein points capped at 2;
- cheese: always N - P;
- fats, oils, nuts and seeds: N < 7 -> N - P; otherwise N - fibre - FVL;
- beverages: always N - P, sweeteners add 4 to N, never A;
- water: always A, no inputs.
"""

from collections.abc import Mapping
from decimal import Decimal
from types import MappingProxyType

from app.modules.scoring import tables as t
from app.modules.scoring.conversions import to_decimal
from app.modules.scoring.models import (
    Breakdown,
    Category,
    Grade,
    InsufficientData,
    NutriScore,
    NutritionInput,
    ScoreResult,
)

_FOOD_FIELDS = (
    "energy_kj",
    "sugars_g",
    "saturated_fat_g",
    "salt_g",
    "fibre_g",
    "protein_g",
    "fvl_percent",
)
_FATS_FIELDS = (
    "total_fat_g",
    "sugars_g",
    "saturated_fat_g",
    "salt_g",
    "fibre_g",
    "protein_g",
    "fvl_percent",
)

REQUIRED_FIELDS: Mapping[Category, tuple[str, ...]] = MappingProxyType(
    {
        Category.GENERAL: _FOOD_FIELDS,
        Category.RED_MEAT: _FOOD_FIELDS,
        Category.CHEESE: _FOOD_FIELDS,
        Category.FATS_OILS_NUTS_SEEDS: _FATS_FIELDS,
        Category.BEVERAGE: (*_FOOD_FIELDS, "non_nutritive_sweeteners"),
        Category.WATER: (),
    }
)
"""Inputs each category needs; any of them missing gives `InsufficientData` (decision 5)."""


def score(category: Category, nutrition: NutritionInput) -> ScoreResult:
    """Grade a product, or list the inputs that are missing to do so."""
    if category is Category.WATER:
        return NutriScore(category, Grade.A, None)

    missing = {name for name in REQUIRED_FIELDS[category] if getattr(nutrition, name) is None}
    if category is Category.FATS_OILS_NUTS_SEEDS and nutrition.total_fat_g == 0:
        missing.add("total_fat_g")  # saturates/fat ratio undefined (decision 4)
    if missing:
        return InsufficientData(category, tuple(sorted(missing)))

    values = {
        name: to_decimal(getattr(nutrition, name))
        for name in REQUIRED_FIELDS[category]
        if name != "non_nutritive_sweeteners"
    }
    match category:
        case Category.FATS_OILS_NUTS_SEEDS:
            return _score_fats(values)
        case Category.BEVERAGE:
            return _score_beverage(values, sweeteners=nutrition.non_nutritive_sweeteners is True)
        case _:
            return _score_food(category, values)


def _score_food(category: Category, v: Mapping[str, Decimal]) -> NutriScore:
    negative = {
        "energy": t.ENERGY_KJ.points(v["energy_kj"]),
        "sugars": t.SUGARS_G.points(v["sugars_g"]),
        "saturated_fat": t.SATURATED_FAT_G.points(v["saturated_fat_g"]),
        "salt": t.SALT_G.points(v["salt_g"]),
    }
    protein = t.PROTEIN_G.points(v["protein_g"])
    if category is Category.RED_MEAT:
        protein = min(protein, t.RED_MEAT_MAX_PROTEIN_POINTS)
    positive = {
        "protein": protein,
        "fibre": t.FIBRE_G.points(v["fibre_g"]),
        "fvl": t.FVL_PERCENT.points(v["fvl_percent"]),
    }
    protein_counted = (
        category is Category.CHEESE or sum(negative.values()) < t.FOODS_PROTEIN_N_LIMIT
    )
    return _graded(category, negative, positive, protein_counted, t.FOODS_GRADES)


def _score_fats(v: Mapping[str, Decimal]) -> NutriScore:
    saturated = v["saturated_fat_g"]
    negative = {
        "energy_from_saturates": t.ENERGY_FROM_SATURATES_KJ.points(
            saturated * t.KJ_PER_G_SATURATED_FAT
        ),
        "sugars": t.SUGARS_G.points(v["sugars_g"]),
        "saturated_fat_ratio": t.SATURATED_FAT_RATIO_PERCENT.points(
            saturated * 100 / v["total_fat_g"]
        ),
        "salt": t.SALT_G.points(v["salt_g"]),
    }
    positive = {
        "protein": t.PROTEIN_G.points(v["protein_g"]),
        "fibre": t.FIBRE_G.points(v["fibre_g"]),
        "fvl": t.FVL_PERCENT.points(v["fvl_percent"]),
    }
    protein_counted = sum(negative.values()) < t.FATS_PROTEIN_N_LIMIT
    return _graded(
        Category.FATS_OILS_NUTS_SEEDS, negative, positive, protein_counted, t.FATS_GRADES
    )


def _score_beverage(v: Mapping[str, Decimal], *, sweeteners: bool) -> NutriScore:
    negative = {
        "energy": t.BEVERAGE_ENERGY_KJ.points(v["energy_kj"]),
        "sugars": t.BEVERAGE_SUGARS_G.points(v["sugars_g"]),
        "saturated_fat": t.BEVERAGE_SATURATED_FAT_G.points(v["saturated_fat_g"]),
        "salt": t.SALT_G.points(v["salt_g"]),
        "non_nutritive_sweeteners": t.NON_NUTRITIVE_SWEETENERS_POINTS if sweeteners else 0,
    }
    positive = {
        "protein": t.BEVERAGE_PROTEIN_G.points(v["protein_g"]),
        "fibre": t.FIBRE_G.points(v["fibre_g"]),
        "fvl": t.BEVERAGE_FVL_PERCENT.points(v["fvl_percent"]),
    }
    return _graded(Category.BEVERAGE, negative, positive, True, t.BEVERAGE_GRADES)


def _graded(
    category: Category,
    negative: dict[str, int],
    positive: dict[str, int],
    protein_counted: bool,
    bands: t.GradeBands,
) -> NutriScore:
    negative_total = sum(negative.values())
    positive_total = sum(positive.values())
    subtracted = positive_total if protein_counted else positive_total - positive["protein"]
    total = negative_total - subtracted
    breakdown = Breakdown(
        negative=MappingProxyType(negative),
        positive=MappingProxyType(positive),
        negative_total=negative_total,
        positive_total=positive_total,
        protein_counted=protein_counted,
        score=total,
    )
    return NutriScore(category, bands.grade(total), breakdown)
