"""Ranking of better alternatives (pure functions)."""

from decimal import Decimal

import pytest

from app.modules.products.alternatives import (
    SIMILARITY_NUTRIENTS,
    Candidate,
    better_grades,
    nutrient_distance,
    rank_alternatives,
    similarity_scales,
)
from app.modules.scoring import Category, Grade

D = Decimal


def nutrients(**values: str | None) -> dict[str, Decimal | None]:
    base: dict[str, str | None] = {
        "energy_kj": "1000",
        "sugars_g": "10",
        "saturated_fat_g": "2",
        "salt_g": "1",
        "protein_g": "5",
        "fibre_g": "2",
    }
    base.update(values)
    return {k: None if v is None else D(v) for k, v in base.items()}


PRODUCT = Candidate(
    ean="6190000000001",
    grade=Grade.D,
    total=15,
    food_categories=("en:snacks", "en:biscuits", "en:chocolate-biscuits"),
    nutrients=nutrients(),
)


def candidate(ean: str, grade: Grade = Grade.B, total: int | None = 2, **kw: object) -> Candidate:
    fields: dict[str, object] = {
        "food_categories": ("en:snacks", "en:biscuits"),
        "nutrients": nutrients(),
    }
    fields.update(kw)
    return Candidate(ean=ean, grade=grade, total=total, **fields)  # type: ignore[arg-type]


def rank(*candidates: Candidate, product: Candidate = PRODUCT, limit: int = 10) -> list[str]:
    ranked = rank_alternatives(product, Category.GENERAL, candidates, limit=limit)
    return [c.ean for c in ranked]


# ---------------------------------------------------------------- grades


@pytest.mark.parametrize(
    ("grade", "expected"),
    [
        (Grade.A, ()),
        (Grade.B, (Grade.A,)),
        (Grade.C, (Grade.A, Grade.B)),
        (Grade.E, (Grade.A, Grade.B, Grade.C, Grade.D)),
    ],
)
def test_better_grades(grade: Grade, expected: tuple[Grade, ...]) -> None:
    assert better_grades(grade) == expected


# ---------------------------------------------------------------- similarity


def test_scales_come_from_the_point_tables() -> None:
    assert similarity_scales(Category.GENERAL) == {
        "energy_kj": D(3350),
        "sugars_g": D(51),
        "saturated_fat_g": D(10),
        "salt_g": D(4),
        "protein_g": D(17),
        "fibre_g": D("7.4"),
    }
    for category in (Category.RED_MEAT, Category.CHEESE, Category.FATS_OILS_NUTS_SEEDS):
        assert similarity_scales(category) == similarity_scales(Category.GENERAL)


def test_beverages_use_the_beverage_tables() -> None:
    scales = similarity_scales(Category.BEVERAGE)
    assert (scales["energy_kj"], scales["sugars_g"], scales["protein_g"]) == (
        D(390),
        D(11),
        D("3.0"),
    )
    assert scales["salt_g"] == D(4)


def test_scales_cover_every_compared_nutrient() -> None:
    for category in Category:
        assert set(similarity_scales(category)) == set(SIMILARITY_NUTRIENTS)


def test_distance_is_the_mean_scaled_gap() -> None:
    scales = similarity_scales(Category.GENERAL)
    assert nutrient_distance(nutrients(), nutrients(), scales) == 0
    # Salt 1 g vs 3 g: gap 2 / 4 = 0.5, over 6 nutrients.
    assert nutrient_distance(nutrients(), nutrients(salt_g="3"), scales) == D("0.5") / 6


def test_distance_gap_capped_at_one() -> None:
    scales = similarity_scales(Category.GENERAL)
    far = nutrient_distance(nutrients(), nutrients(salt_g="100"), scales)
    assert far == D(1) / 6


def test_distance_skips_undeclared_nutrients() -> None:
    scales = similarity_scales(Category.GENERAL)
    a = nutrients(fibre_g=None, salt_g="1")
    b = nutrients(protein_g=None, salt_g="3")
    # Compared: energy, sugars, saturated fat, salt -> salt gap 0.5 over 4.
    assert nutrient_distance(a, b, scales) == D("0.5") / 4


def test_no_shared_nutrient_no_distance() -> None:
    scales = similarity_scales(Category.GENERAL)
    assert nutrient_distance({}, nutrients(), scales) is None
    assert nutrient_distance(nutrients(salt_g=None), {"salt_g": D(1)}, scales) is None


# ---------------------------------------------------------------- candidates


def test_only_strictly_better_grades() -> None:
    assert rank(
        candidate("a", Grade.A),
        candidate("c", Grade.C),
        candidate("d", Grade.D),
        candidate("e", Grade.E),
    ) == ["a", "c"]


def test_never_the_product_itself() -> None:
    assert rank(candidate(PRODUCT.ean, Grade.A)) == []


def test_needs_a_shared_food_category() -> None:
    assert rank(
        candidate("other", food_categories=("en:sauces",)),
        candidate("none", food_categories=()),
        candidate("snack", food_categories=("en:snacks",)),
    ) == ["snack"]


def test_product_without_food_categories_matches_any() -> None:
    bare = Candidate(ean="1", grade=Grade.D, total=15, nutrients=nutrients())
    assert rank(
        candidate("x", food_categories=("en:sauces",)),
        candidate("y", food_categories=()),
        product=bare,
    ) == ["x", "y"]


# ---------------------------------------------------------------- order


def test_more_shared_categories_first() -> None:
    assert rank(
        candidate("snacks", food_categories=("en:snacks",)),
        candidate("chocolate", food_categories=PRODUCT.food_categories),
        candidate("biscuits", food_categories=("en:snacks", "en:biscuits")),
    ) == ["chocolate", "biscuits", "snacks"]


def test_then_closer_nutrients() -> None:
    assert rank(
        candidate("far", nutrients=nutrients(sugars_g="40")),
        candidate("near", nutrients=nutrients(sugars_g="12")),
        candidate("same", nutrients=nutrients()),
    ) == ["same", "near", "far"]


def test_comparable_profiles_before_unknown_ones() -> None:
    assert rank(
        candidate("unknown", nutrients={}),
        candidate("far", nutrients=nutrients(sugars_g="50", salt_g="4")),
    ) == ["far", "unknown"]


def test_then_better_score_then_ean() -> None:
    assert rank(
        candidate("b3", total=3),
        candidate("b1", total=1),
        candidate("none", total=None),
        candidate("a1", total=1),
    ) == ["a1", "b1", "b3", "none"]


def test_grade_alone_does_not_outrank_similarity() -> None:
    # A closer B beats a distant A: the point is a realistic swap.
    assert rank(
        candidate("a-far", Grade.A, total=-5, nutrients=nutrients(sugars_g="45")),
        candidate("b-near", Grade.B, total=2),
    ) == ["b-near", "a-far"]


def test_limit() -> None:
    many = [candidate(f"{i:02}") for i in range(8)]
    assert rank(*many, limit=3) == ["00", "01", "02"]
    assert rank(*many, limit=0) == []


def test_beverage_scales_change_the_order() -> None:
    # Energy +180 kJ: 180/3350 = 0.05 as a food, 180/390 = 0.46 as a beverage.
    # Sugars +4 g: 4/51 = 0.08 as a food, 4/11 = 0.36 as a beverage.
    product = Candidate(
        ean="p", grade=Grade.E, total=12, nutrients=nutrients(energy_kj="200", sugars_g="9")
    )
    energy_far = candidate("energy", nutrients=nutrients(energy_kj="380", sugars_g="9"))
    sugar_far = candidate("sugar", nutrients=nutrients(energy_kj="200", sugars_g="13"))

    as_food = rank_alternatives(product, Category.GENERAL, [energy_far, sugar_far], limit=2)
    as_drink = rank_alternatives(product, Category.BEVERAGE, [energy_far, sugar_far], limit=2)
    assert [c.ean for c in as_food] == ["energy", "sugar"]
    assert [c.ean for c in as_drink] == ["sugar", "energy"]
