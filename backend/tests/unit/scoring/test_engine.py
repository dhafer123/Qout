"""Score rules per category, missing data, water, and the shape of results."""

import dataclasses
from typing import Any

import pytest

from app.modules.scoring import (
    REQUIRED_FIELDS,
    Breakdown,
    Category,
    Grade,
    InsufficientData,
    NutriScore,
    NutritionInput,
    score,
)

ZERO_FOOD = {
    "energy_kj": 0,
    "sugars_g": 0,
    "saturated_fat_g": 0,
    "salt_g": 0,
    "fibre_g": 0,
    "protein_g": 0,
    "fvl_percent": 0,
}
ZERO_FATS = {**{k: v for k, v in ZERO_FOOD.items() if k != "energy_kj"}, "total_fat_g": 10}
ZERO_BEVERAGE = {**ZERO_FOOD, "non_nutritive_sweeteners": False}
BASE: dict[Category, dict[str, Any]] = {
    Category.GENERAL: ZERO_FOOD,
    Category.RED_MEAT: ZERO_FOOD,
    Category.CHEESE: ZERO_FOOD,
    Category.FATS_OILS_NUTS_SEEDS: ZERO_FATS,
    Category.BEVERAGE: ZERO_BEVERAGE,
}


def graded(category: Category, **values: Any) -> tuple[Grade, Breakdown]:
    """Score an all-zero product of `category` with `values` overridden."""
    result = score(category, NutritionInput(**{**BASE[category], **values}))
    assert isinstance(result, NutriScore)
    assert result.breakdown is not None
    return result.grade, result.breakdown


# ---------------------------------------------------------------- water


def test_water_is_always_a_without_points() -> None:
    result = score(Category.WATER, NutritionInput())
    assert result == NutriScore(Category.WATER, Grade.A, None)


def test_water_ignores_any_values() -> None:
    result = score(Category.WATER, NutritionInput(sugars_g=50, salt_g=4))
    assert result == NutriScore(Category.WATER, Grade.A, None)


# ---------------------------------------------------------------- missing data


@pytest.mark.parametrize(
    ("category", "field"),
    [(c, f) for c, base in BASE.items() for f in base],
    ids=str,
)
def test_each_required_field_is_reported_when_missing(category: Category, field: str) -> None:
    values = {k: v for k, v in BASE[category].items() if k != field}
    result = score(category, NutritionInput(**values))
    assert result == InsufficientData(category, (field,))


@pytest.mark.parametrize("category", list(BASE))
def test_nothing_declared_lists_every_required_field_sorted(category: Category) -> None:
    result = score(category, NutritionInput())
    assert isinstance(result, InsufficientData)
    assert result.missing == tuple(sorted(REQUIRED_FIELDS[category]))
    assert set(result.missing) == set(BASE[category])


def test_fats_with_zero_total_fat_is_unusable() -> None:
    values = {k: v for k, v in ZERO_FATS.items() if k != "saturated_fat_g"}
    result = score(Category.FATS_OILS_NUTS_SEEDS, NutritionInput(**{**values, "total_fat_g": 0}))
    assert result == InsufficientData(
        Category.FATS_OILS_NUTS_SEEDS, ("saturated_fat_g", "total_fat_g")
    )


def test_inputs_the_category_does_not_use_are_ignored() -> None:
    plain = graded(Category.GENERAL)
    extra = graded(Category.GENERAL, total_fat_g=50, non_nutritive_sweeteners=True)
    assert extra == plain


def test_fats_do_not_need_energy() -> None:
    assert "energy_kj" not in REQUIRED_FIELDS[Category.FATS_OILS_NUTS_SEEDS]
    grade, b = graded(Category.FATS_OILS_NUTS_SEEDS, energy_kj=None)
    assert (b.score, grade) == (0, Grade.B)


# ---------------------------------------------------------------- general foods


def test_general_n_below_11_subtracts_protein() -> None:
    # N = 10: salt 2.0 g -> 9, sugars 3.5 -> 1. Protein 13 g -> 5.
    _, b = graded(Category.GENERAL, salt_g=2.0, sugars_g=3.5, protein_g=13)
    assert (b.negative_total, b.positive_total, b.protein_counted, b.score) == (10, 5, True, 5)


def test_general_n_from_11_ignores_protein() -> None:
    # N = 11: salt 2.1 g -> 10, sugars 3.5 -> 1. Protein 13 g -> 5 (ignored), fibre 4.2 -> 2.
    grade, b = graded(Category.GENERAL, salt_g=2.1, sugars_g=3.5, protein_g=13, fibre_g=4.2)
    assert (b.negative_total, b.positive_total, b.protein_counted) == (11, 7, False)
    assert (b.score, grade) == (11 - 2, Grade.C)


def test_general_best_and_worst() -> None:
    grade, b = graded(Category.GENERAL, protein_g=20, fibre_g=10, fvl_percent=100)
    assert (b.score, grade) == (-17, Grade.A)
    grade, b = graded(Category.GENERAL, energy_kj=4000, sugars_g=60, saturated_fat_g=20, salt_g=5)
    assert (b.score, grade) == (55, Grade.E)


# ---------------------------------------------------------------- red meat and cheese


def test_red_meat_protein_is_capped_at_2() -> None:
    assert graded(Category.RED_MEAT, protein_g=25)[1].positive["protein"] == 2
    assert graded(Category.GENERAL, protein_g=25)[1].positive["protein"] == 7


def test_red_meat_n_from_11_ignores_protein() -> None:
    _, b = graded(Category.RED_MEAT, salt_g=2.1, sugars_g=3.5, protein_g=25)
    assert (b.protein_counted, b.score) == (False, 11)


def test_cheese_always_subtracts_protein() -> None:
    _, b = graded(Category.CHEESE, salt_g=2.1, sugars_g=3.5, protein_g=25)
    assert (b.negative_total, b.protein_counted, b.score) == (11, True, 11 - 7)
    _, general = graded(Category.GENERAL, salt_g=2.1, sugars_g=3.5, protein_g=25)
    assert general.score == 11


# ---------------------------------------------------------------- fats, oils, nuts, seeds


def test_fats_energy_from_saturates_is_37_kj_per_gram() -> None:
    # 3.24 g x 37 = 119.88 kJ (0 points); 3.25 g x 37 = 120.25 kJ (1 point).
    _, low = graded(Category.FATS_OILS_NUTS_SEEDS, saturated_fat_g=3.24, total_fat_g=100)
    _, high = graded(Category.FATS_OILS_NUTS_SEEDS, saturated_fat_g=3.25, total_fat_g=100)
    assert low.negative["energy_from_saturates"] == 0
    assert high.negative["energy_from_saturates"] == 1


def test_fats_ratio_uses_exact_decimals() -> None:
    # 0.58 * 100 is 57.99999999999999 in binary floats; the ratio is exactly 58 % (9 points).
    assert 0.58 * 100 < 58
    _, b = graded(Category.FATS_OILS_NUTS_SEEDS, saturated_fat_g=0.58, total_fat_g=1)
    assert b.negative["saturated_fat_ratio"] == 9


def test_fats_ratio_on_threshold_gets_higher_points() -> None:
    _, b = graded(Category.FATS_OILS_NUTS_SEEDS, saturated_fat_g=1.6, total_fat_g=10)
    assert b.negative["saturated_fat_ratio"] == 2  # 16 % -> 2 points


def test_fats_n_from_7_ignores_protein() -> None:
    # saturated 4 g of 100 g fat: 148 kJ -> 1 point, ratio 4 % -> 0. Salt 1.3 -> 6. N = 7.
    _, b = graded(
        Category.FATS_OILS_NUTS_SEEDS,
        saturated_fat_g=4,
        total_fat_g=100,
        salt_g=1.3,
        protein_g=13,
    )
    assert (b.negative_total, b.protein_counted, b.score) == (7, False, 7)
    _, below = graded(Category.FATS_OILS_NUTS_SEEDS, salt_g=1.3, protein_g=13)
    assert (below.negative_total, below.protein_counted, below.score) == (6, True, 6 - 5)


def test_fats_grade_a_needs_minus_6() -> None:
    # protein 13 -> 5, fibre 3.1 -> 1: score -6 -> A; with fibre 3 -> -5 -> B.
    grade, b = graded(Category.FATS_OILS_NUTS_SEEDS, protein_g=13, fibre_g=3.1)
    assert (b.score, grade) == (-6, Grade.A)
    grade, b = graded(Category.FATS_OILS_NUTS_SEEDS, protein_g=13, fibre_g=3)
    assert (b.score, grade) == (-5, Grade.B)


# ---------------------------------------------------------------- beverages


def test_beverage_sweeteners_add_4_points() -> None:
    _, without = graded(Category.BEVERAGE)
    grade, b = graded(Category.BEVERAGE, non_nutritive_sweeteners=True)
    assert without.negative["non_nutritive_sweeteners"] == 0
    assert b.negative["non_nutritive_sweeteners"] == 4
    assert (b.score, grade) == (4, Grade.C)


def test_beverage_always_subtracts_protein() -> None:
    _, b = graded(Category.BEVERAGE, energy_kj=400, sugars_g=12, protein_g=3.5)
    assert (b.negative_total, b.protein_counted, b.score) == (20, True, 13)


def test_beverage_is_never_a() -> None:
    grade, b = graded(Category.BEVERAGE, protein_g=3.5, fibre_g=8, fvl_percent=100)
    assert (b.score, grade) == (-18, Grade.B)


# ---------------------------------------------------------------- result shape


def test_result_is_read_only() -> None:
    result = score(Category.GENERAL, NutritionInput(**ZERO_FOOD))
    assert isinstance(result, NutriScore)
    assert result.breakdown is not None
    with pytest.raises(TypeError):
        result.breakdown.negative["sugars"] = 99  # type: ignore[index]
    with pytest.raises(dataclasses.FrozenInstanceError):
        result.grade = Grade.E  # type: ignore[misc]


@pytest.mark.parametrize(
    ("category", "negative"),
    [
        (Category.GENERAL, {"energy", "sugars", "saturated_fat", "salt"}),
        (Category.RED_MEAT, {"energy", "sugars", "saturated_fat", "salt"}),
        (Category.CHEESE, {"energy", "sugars", "saturated_fat", "salt"}),
        (
            Category.FATS_OILS_NUTS_SEEDS,
            {"energy_from_saturates", "sugars", "saturated_fat_ratio", "salt"},
        ),
        (
            Category.BEVERAGE,
            {"energy", "sugars", "saturated_fat", "salt", "non_nutritive_sweeteners"},
        ),
    ],
)
def test_component_names(category: Category, negative: set[str]) -> None:
    _, b = graded(category)
    assert set(b.negative) == negative
    assert set(b.positive) == {"protein", "fibre", "fvl"}
