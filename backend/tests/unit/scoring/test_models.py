"""NutritionInput validation and result types."""

import dataclasses
import math
from typing import Any

import pytest

from app.modules.scoring import (
    ENGINE_VERSION,
    Category,
    Grade,
    InsufficientData,
    NutriScore,
    NutritionInput,
)

AMOUNT_FIELDS = [
    "energy_kj",
    "sugars_g",
    "saturated_fat_g",
    "total_fat_g",
    "salt_g",
    "fibre_g",
    "protein_g",
    "fvl_percent",
]
GRAM_FIELDS = ["sugars_g", "saturated_fat_g", "total_fat_g", "salt_g", "fibre_g", "protein_g"]


def test_all_fields_default_to_not_declared() -> None:
    nutrition = NutritionInput()
    assert all(getattr(nutrition, f.name) is None for f in dataclasses.fields(nutrition))


def test_accepts_valid_values() -> None:
    nutrition = NutritionInput(
        energy_kj=3700,
        sugars_g=100,
        saturated_fat_g=0,
        total_fat_g=100,
        salt_g=2.5,
        fibre_g=3,
        protein_g=12.5,
        fvl_percent=100,
        non_nutritive_sweeteners=False,
    )
    assert nutrition.salt_g == 2.5


@pytest.mark.parametrize("field", AMOUNT_FIELDS)
@pytest.mark.parametrize("bad", [-0.1, math.nan, math.inf, -math.inf])
def test_rejects_negative_and_non_finite(field: str, bad: float) -> None:
    with pytest.raises(ValueError, match=field):
        NutritionInput(**{field: bad})


@pytest.mark.parametrize("field", GRAM_FIELDS)
def test_rejects_more_than_100_g(field: str) -> None:
    NutritionInput(**{field: 100})
    with pytest.raises(ValueError, match="<= 100 g"):
        NutritionInput(**{field: 100.01})


def test_rejects_percentage_above_100() -> None:
    with pytest.raises(ValueError, match="<= 100 %"):
        NutritionInput(fvl_percent=100.5)


def test_energy_has_no_upper_bound_in_grams() -> None:
    assert NutritionInput(energy_kj=3700).energy_kj == 3700


@pytest.mark.parametrize("bad", [True, "1", [1]])
def test_rejects_non_numbers(bad: Any) -> None:
    with pytest.raises(ValueError, match="must be a number"):
        NutritionInput(sugars_g=bad)


def test_rejects_non_bool_sweetener_flag() -> None:
    bad: Any = 1
    with pytest.raises(ValueError, match="must be a bool"):
        NutritionInput(non_nutritive_sweeteners=bad)


def test_inputs_are_immutable() -> None:
    nutrition = NutritionInput(sugars_g=1)
    with pytest.raises(dataclasses.FrozenInstanceError):
        nutrition.sugars_g = 2  # type: ignore[misc]


def test_results_carry_the_engine_version() -> None:
    assert NutriScore(Category.WATER, Grade.A, None).engine_version == ENGINE_VERSION
    missing = InsufficientData(Category.GENERAL, ("fibre_g",))
    assert missing.engine_version == ENGINE_VERSION


def test_category_values_match_the_golden_cases() -> None:
    assert {c.value for c in Category} == {
        "general",
        "red_meat",
        "cheese",
        "fats_oils_nuts_seeds",
        "beverage",
        "water",
    }
