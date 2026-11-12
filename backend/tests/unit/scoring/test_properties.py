"""Property-based tests (hypothesis): monotonicity, determinism, output always valid.

"Within the rules": more of a negative nutrient never improves the score and more of a
positive one never worsens it. Total fat in the fats category is not in either list: more
total fat lowers the saturates/fat ratio, which the rules reward on purpose.
"""

from typing import Any

from hypothesis import given
from hypothesis import strategies as st
from jsonschema import Draft202012Validator

from app.modules.scoring import Category, NutriScore, NutritionInput, score
from tests.unit.scoring.golden import SCHEMA_PATH, load, to_expected

SCHEMA_VALIDATOR = Draft202012Validator(load(SCHEMA_PATH))

GRAMS = st.floats(min_value=0, max_value=100, allow_nan=False)
ENERGY = st.floats(min_value=0, max_value=4000, allow_nan=False)
PERCENT = st.floats(min_value=0, max_value=100, allow_nan=False)
LIMITS = {"energy_kj": 4000.0, "fvl_percent": 100.0}

FOOD_CATEGORIES = [Category.GENERAL, Category.RED_MEAT, Category.CHEESE]
FOOD_INPUT = st.fixed_dictionaries(
    {
        "energy_kj": ENERGY,
        "sugars_g": GRAMS,
        "saturated_fat_g": GRAMS,
        "salt_g": GRAMS,
        "fibre_g": GRAMS,
        "protein_g": GRAMS,
        "fvl_percent": PERCENT,
    }
)
FATS_INPUT = st.fixed_dictionaries(
    {
        "total_fat_g": st.floats(min_value=0.01, max_value=100, allow_nan=False),
        "sugars_g": GRAMS,
        "saturated_fat_g": GRAMS,
        "salt_g": GRAMS,
        "fibre_g": GRAMS,
        "protein_g": GRAMS,
        "fvl_percent": PERCENT,
    }
)
BEVERAGE_INPUT = st.fixed_dictionaries(
    {
        "energy_kj": ENERGY,
        "sugars_g": GRAMS,
        "saturated_fat_g": GRAMS,
        "salt_g": GRAMS,
        "fibre_g": GRAMS,
        "protein_g": GRAMS,
        "fvl_percent": PERCENT,
        "non_nutritive_sweeteners": st.booleans(),
    }
)

# (category, input strategy, nutrients to limit, nutrients that help)
CASES = st.one_of(
    st.tuples(
        st.sampled_from(FOOD_CATEGORIES),
        FOOD_INPUT,
        st.just(("energy_kj", "sugars_g", "saturated_fat_g", "salt_g")),
        st.just(("fibre_g", "protein_g", "fvl_percent")),
    ),
    st.tuples(
        st.just(Category.FATS_OILS_NUTS_SEEDS),
        FATS_INPUT,
        st.just(("sugars_g", "saturated_fat_g", "salt_g")),
        st.just(("fibre_g", "protein_g", "fvl_percent")),
    ),
    st.tuples(
        st.just(Category.BEVERAGE),
        BEVERAGE_INPUT,
        st.just(("energy_kj", "sugars_g", "saturated_fat_g", "salt_g")),
        st.just(("fibre_g", "protein_g", "fvl_percent")),
    ),
)

Case = tuple[Category, dict[str, Any], tuple[str, ...], tuple[str, ...]]


def total(category: Category, values: dict[str, Any]) -> int:
    result = score(category, NutritionInput(**values))
    assert isinstance(result, NutriScore)
    assert result.breakdown is not None
    return result.breakdown.score


def increased(values: dict[str, Any], field: str, delta: float) -> dict[str, Any]:
    limit = LIMITS.get(field, 100.0)
    return {**values, field: min(values[field] + delta, limit)}


@given(CASES, st.data(), st.floats(min_value=0, max_value=4000, allow_nan=False))
def test_more_of_a_nutrient_to_limit_never_improves_the_score(
    case: Case, data: st.DataObject, delta: float
) -> None:
    category, values, to_limit, _ = case
    field = data.draw(st.sampled_from(to_limit))
    assert total(category, increased(values, field, delta)) >= total(category, values)


@given(CASES, st.data(), st.floats(min_value=0, max_value=100, allow_nan=False))
def test_more_of_a_helpful_nutrient_never_worsens_the_score(
    case: Case, data: st.DataObject, delta: float
) -> None:
    category, values, _, helpful = case
    field = data.draw(st.sampled_from(helpful))
    assert total(category, increased(values, field, delta)) <= total(category, values)


@given(BEVERAGE_INPUT)
def test_sweeteners_never_improve_a_beverage(values: dict[str, Any]) -> None:
    without = total(Category.BEVERAGE, {**values, "non_nutritive_sweeteners": False})
    with_sweeteners = total(Category.BEVERAGE, {**values, "non_nutritive_sweeteners": True})
    assert with_sweeteners == without + 4


@given(CASES)
def test_score_is_deterministic(case: Case) -> None:
    category, values, _, _ = case
    first = score(category, NutritionInput(**values))
    second = score(category, NutritionInput(**dict(reversed(list(values.items())))))
    assert first == second


@given(CASES)
def test_result_is_a_valid_golden_case(case: Case) -> None:
    """Point ranges, red meat cap, beverage grades, totals: everything the schema checks."""
    category, values, _, _ = case
    result = score(category, NutritionInput(**values))
    golden = {
        "id": f"{category.value}--generated",
        "description": "generated",
        "source": "hypothesis",
        "category": category.value,
        "input": values,
        "expected": to_expected(result),
    }
    errors = [e.message for e in SCHEMA_VALIDATOR.iter_errors(golden)]
    assert errors == []
    expected = golden["expected"]
    assert expected["negative_total"] == sum(expected["negative"].values())
    assert expected["positive_total"] == sum(expected["positive"].values())


def without_fibre(values: dict[str, Any]) -> dict[str, Any]:
    return {k: v for k, v in values.items() if k != "fibre_g"}


@given(CASES)
def test_undeclared_fibre_scores_like_fibre_zero(case: Case) -> None:
    """Decision 8: an undeclared fibre value counts as 0 points."""
    category, values, _, _ = case
    assert total(category, without_fibre(values)) == total(category, {**values, "fibre_g": 0.0})


@given(CASES)
def test_declaring_fibre_never_worsens_the_score(case: Case) -> None:
    """So a grade with undeclared fibre is never better than the true one."""
    category, values, _, _ = case
    assert total(category, values) <= total(category, without_fibre(values))
