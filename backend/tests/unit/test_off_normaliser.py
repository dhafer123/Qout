"""Open Food Facts normaliser on recorded (and a few hand-edited) OFF responses."""

import json
from datetime import UTC, datetime
from decimal import Decimal
from pathlib import Path
from typing import Any

import pytest

from app.modules.ingestion.off_normaliser import NormalizedProduct, normalize
from app.modules.products.models import (
    DataSource,
    NutritionBasis,
    NutritionFacts,
    QualityFlag,
)
from app.modules.products.scoring import nutrition_input
from app.modules.scoring import Category, Grade, NutriScore, score

FIXTURES = Path(__file__).resolve().parents[1] / "fixtures" / "off"


def load(name: str) -> dict[str, Any]:
    data: dict[str, Any] = json.loads((FIXTURES / f"{name}.json").read_text(encoding="utf-8"))
    return data


def normalized(name: str) -> NormalizedProduct:
    fixture = load(name)
    return normalize(fixture["ean"], fixture["product"])


QC, QI, QS = QualityFlag.COMPLETE, QualityFlag.INCOMPLETE, QualityFlag.SUSPECT
G, M = NutritionBasis.PER_100G, NutritionBasis.PER_100ML

# name: (category, quality, OFF grade, basis or None, some amounts, issue fragments)
EXPECTED: dict[
    str,
    tuple[
        Category | None, QualityFlag, Grade | None, NutritionBasis | None, dict[str, str], list[str]
    ],
] = {
    "general-complete-spread": (
        Category.GENERAL,
        QC,
        Grade.E,
        G,
        {"energy_kj": "2252", "sugars_g": "56.3", "salt_g": "0.107", "fibre_g": "0"},
        [],
    ),
    "general-per-serving-biscuits": (
        Category.GENERAL,
        QS,
        Grade.D,
        G,
        {"energy_kj": "1912.1", "fibre_g": "9.3"},
        ["energy 1912.1 kJ does not match 431 kcal"],
    ),
    "general-stock-concentrate": (
        Category.RED_MEAT,
        QI,
        Grade.B,
        None,
        {},
        ["no usable per-100 g values", "no nutrition facts"],
    ),
    "general-no-category": (
        Category.BEVERAGE,
        QI,
        None,
        None,
        {},
        ["OFF has no nutrition data for this product"],
    ),
    "general-infant-formula": (
        Category.BEVERAGE,
        QI,
        None,
        G,
        {"sugars_g": "0"},
        ["missing: energy_kj, salt_g, protein_g, fvl_percent, non_nutritive_sweeteners"],
    ),
    "beverage-sugary-cola": (
        Category.BEVERAGE,
        QC,
        Grade.E,
        G,
        {"sugars_g": "10.6", "energy_kj": "180"},
        [],
    ),
    "beverage-sweetened-cola-zero": (
        Category.BEVERAGE,
        QC,
        Grade.C,
        G,
        {"energy_kj": "0.9", "salt_g": "0.02"},
        [],
    ),
    "beverage-orange-soda": (Category.BEVERAGE, QC, Grade.E, M, {"fvl_percent": "4"}, []),
    "beverage-energy-drink": (
        Category.BEVERAGE,
        QS,
        Grade.E,
        G,
        {"energy_kj": "194"},
        ["energy 194 kJ does not match 463 kcal"],
    ),
    "water-tunisian-safia": (Category.WATER, QC, Grade.A, M, {"salt_g": "0.0055"}, []),
    "water-tunisian-hayet": (Category.WATER, QC, Grade.A, M, {"salt_g": "0.003905"}, []),
    "cheese-tunisian-processed": (
        Category.CHEESE,
        QC,
        Grade.D,
        G,
        {"saturated_fat_g": "30.3", "salt_g": "1"},
        [],
    ),
    "cheese-tunisian-spread": (
        Category.GENERAL,
        QC,
        Grade.D,
        G,
        {"sugars_g": "2.5"},
        [],
    ),
    "cheese-tunisian-ricotta": (
        Category.CHEESE,
        QI,
        None,
        G,
        {"total_fat_g": "15"},
        ["missing: sugars_g, saturated_fat_g, salt_g"],
    ),
    "fats-tunisian-olive-oil": (
        Category.FATS_OILS_NUTS_SEEDS,
        QC,
        Grade.B,
        G,
        {"saturated_fat_g": "19.3", "total_fat_g": "91.2", "fvl_percent": "100"},
        [],
    ),
    "fats-tunisian-olive-oil-2": (
        Category.FATS_OILS_NUTS_SEEDS,
        QC,
        Grade.B,
        M,
        {"fvl_percent": "100"},
        [],
    ),
    "red-meat-beef-patty": (
        Category.RED_MEAT,
        QC,
        Grade.B,
        G,
        {"protein_g": "20"},
        [],
    ),
    "edited-garbage-values": (
        Category.GENERAL,
        QS,
        Grade.E,
        G,
        {"energy_kj": "2252", "fibre_g": "2.5", "salt_g": "0.107"},
        [
            "unusable sugars_100g: 'abc'",
            "unusable proteins_100g: 150",
            "unusable salt_100g: -1",
            "missing: sugars_g, protein_g",
        ],
    ),
    "edited-per-serving-only": (
        Category.GENERAL,
        QI,
        Grade.D,
        None,
        {},
        ["nutrition declared per serving only (not converted)"],
    ),
    "edited-salt-sodium-mismatch": (
        Category.GENERAL,
        QS,
        Grade.E,
        G,
        {"salt_g": "0.107"},
        ["salt 0.107 g does not match sodium 1.0 g"],
    ),
    "edited-impossible-fat-and-sugar": (
        Category.CHEESE,
        QS,
        Grade.D,
        G,
        {},
        ["saturated fat 35 g > total fat 30.3 g", "sugars 5 g > carbohydrates 0.2 g"],
    ),
    "edited-kcal-and-sodium-only": (
        Category.GENERAL,
        QC,
        Grade.E,
        G,
        {"energy_kj": "2264", "salt_g": "0.107"},
        [],
    ),
    "edited-no-classification": (
        None,
        QI,
        None,
        G,
        {"sugars_g": "56.3"},
        ["OFF has no Nutri-Score category for this product"],
    ),
}


def test_every_fixture_has_expectations() -> None:
    names = {path.stem for path in FIXTURES.glob("*.json")}
    assert names == set(EXPECTED) | {"not-found"}
    assert len([n for n in names if not n.startswith("edited-")]) >= 15


def test_not_found_fixture() -> None:
    fixture = load("not-found")
    assert (fixture["ean"], fixture["product"]) == ("6190000000019", None)


def test_edited_fixtures_say_what_changed() -> None:
    for name in EXPECTED:
        if name.startswith("edited-"):
            fixture = load(name)
            assert fixture["edited_from"] in EXPECTED
            assert fixture["edits"]


@pytest.mark.parametrize("name", sorted(EXPECTED))
def test_fixture(name: str) -> None:
    category, quality, off_grade, basis, amounts, issues = EXPECTED[name]
    result = normalized(name)

    assert result.product.category == category
    assert result.product.quality_flag == quality
    assert result.off_grade == off_grade
    assert result.product.source is DataSource.OPEN_FOOD_FACTS
    assert result.product.ean == load(name)["ean"]
    if basis is None:
        assert result.nutrition is None
    else:
        assert result.nutrition is not None
        assert result.nutrition.basis == basis
        for field, value in amounts.items():
            assert getattr(result.nutrition, field) == Decimal(value), field
    for fragment in issues:
        assert fragment in result.issues
    assert (result.issues == []) == (quality is QC)


@pytest.mark.parametrize(
    "name", sorted(n for n, e in EXPECTED.items() if e[1] is QC and e[0] is not None)
)
def test_complete_products_get_offs_own_grade(name: str) -> None:
    """End-to-end check of normaliser + engine against OFF's 2023 computation."""
    result = normalized(name)
    assert result.product.category is not None
    assert result.nutrition is not None
    stored = NutritionFacts(**result.nutrition.model_dump())
    graded = score(result.product.category, nutrition_input(stored))
    assert isinstance(graded, NutriScore)
    assert graded.grade == result.off_grade


def test_product_fields() -> None:
    oil = normalized("fats-tunisian-olive-oil").product
    assert (oil.name, oil.brand, oil.nova_group) == (
        "Huile d'olive vierge extra",
        "TERRA DELYSSA",
        2,
    )
    assert oil.image_url is not None
    assert oil.image_url.startswith("https://images.openfoodfacts.org/")

    cola = normalized("beverage-sweetened-cola-zero")
    assert cola.product.additives == ["E150d", "E331", "E338", "E950", "E951"]
    assert cola.nutrition is not None
    assert cola.nutrition.non_nutritive_sweeteners is True
    sugary = normalized("beverage-sugary-cola").nutrition
    assert sugary is not None
    assert sugary.non_nutritive_sweeteners is False
    assert normalized("general-complete-spread").nutrition.non_nutritive_sweeteners is None  # type: ignore[union-attr]

    assert normalized("edited-garbage-values").product.nova_group is None  # "7"
    assert normalized("cheese-tunisian-ricotta").product.name == "Ricotta"
    assert normalized("beverage-energy-drink").product.name == "Red Bull Energy Drink"


# ---------------------------------------------------------------- edge cases


def minimal(**overrides: Any) -> dict[str, Any]:
    """A small valid general-food OFF product."""
    product: dict[str, Any] = {
        "nutrition_data_per": "100g",
        "nutriments": {
            "energy-kj_100g": 1000,
            "sugars_100g": 5,
            "saturated-fat_100g": 1,
            "fat_100g": 2,
            "salt_100g": 0.5,
            "fiber_100g": 3,
            "proteins_100g": 4,
            "fruits-vegetables-legumes-estimate-from-ingredients_100g": 10,
        },
        "nutriscore": {"2023": {"category_available": 1, "data": {}}},
    }
    product.update(overrides)
    return product


def test_minimal_product_is_complete() -> None:
    result = normalize("6194001800104", minimal())
    assert (result.product.category, result.product.quality_flag) == (Category.GENERAL, QC)
    assert result.nutrition is not None
    assert result.nutrition.fvl_percent == 10


@pytest.mark.parametrize(
    "nutriscore",
    [None, "broken", {"2023": "broken"}, {"2023": {}}, {"2023": {"category_available": 0}}],
)
def test_no_usable_classification(nutriscore: Any) -> None:
    assert normalize("6194001800104", minimal(nutriscore=nutriscore)).product.category is None


@pytest.mark.parametrize(
    ("flags", "category"),
    [
        ({"is_water": True, "is_beverage": True}, Category.WATER),
        ({"is_beverage": 1}, Category.BEVERAGE),
        ({"is_cheese": True}, Category.CHEESE),
        ({"is_fat_oil_nuts_seeds": 1}, Category.FATS_OILS_NUTS_SEEDS),
        ({"is_red_meat_product": 1}, Category.RED_MEAT),
        ({"is_cheese": 0, "is_beverage": False}, Category.GENERAL),
        ({"is_cheese": "yes"}, Category.GENERAL),
    ],
)
def test_category_flags(flags: dict[str, Any], category: Category) -> None:
    off = minimal(nutriscore={"2023": {"category_available": 1, "data": flags}})
    assert normalize("6194001800104", off).product.category is category


def test_classification_without_data_object_is_general() -> None:
    off = minimal(nutriscore={"2023": {"category_available": 1, "data": "broken"}})
    assert normalize("6194001800104", off).product.category is Category.GENERAL


def test_fvl_prefers_offs_component_then_declared_then_estimate() -> None:
    def with_components(positive: Any) -> dict[str, Any]:
        data = {"components": {"negative": [], "positive": positive}}
        return minimal(nutriscore={"2023": {"category_available": 1, "data": data}})

    component = with_components([{"id": "fruits_vegetables_legumes", "value": 100}])
    component["nutriments"]["fruits-vegetables-legumes_100g"] = 50
    assert normalize("6194001800104", component).nutrition.fvl_percent == 100  # type: ignore[union-attr]

    declared = minimal()
    declared["nutriments"]["fruits-vegetables-legumes_100g"] = 50
    assert normalize("6194001800104", declared).nutrition.fvl_percent == 50  # type: ignore[union-attr]

    garbage = with_components([{"id": "fruits_vegetables_legumes", "value": 140}, "junk"])
    result = normalize("6194001800104", garbage)
    assert result.nutrition.fvl_percent == 10  # type: ignore[union-attr]
    assert "unusable fruits_vegetables_legumes component: 140" in result.issues

    broken = minimal(nutriscore={"2023": {"category_available": 1, "data": {"components": "junk"}}})
    assert normalize("6194001800104", broken).nutrition.fvl_percent == 10  # type: ignore[union-attr]


def test_beverage_without_sweetener_count_is_incomplete() -> None:
    off = minimal(nutriscore={"2023": {"category_available": 1, "data": {"is_beverage": 1}}})
    result = normalize("6194001800104", off)
    assert result.nutrition is not None
    assert result.nutrition.non_nutritive_sweeteners is None
    assert "missing: non_nutritive_sweeteners" in result.issues


@pytest.mark.parametrize(
    ("raw", "expected"),
    [(5, "5"), (5.25, "5.25"), ("5.25", "5.25"), (" 5,5 ", "5.5"), ("1e1", "10")],
)
def test_number_forms(raw: Any, expected: str) -> None:
    off = minimal()
    off["nutriments"]["sugars_100g"] = raw
    assert normalize("6194001800104", off).nutrition.sugars_g == Decimal(expected)  # type: ignore[union-attr]


@pytest.mark.parametrize("raw", [True, "NaN", "inf", float("nan"), [5], {"v": 5}, -0.5, 100.5])
def test_unusable_numbers_are_dropped(raw: Any) -> None:
    off = minimal()
    off["nutriments"]["sugars_100g"] = raw
    result = normalize("6194001800104", off)
    assert result.nutrition.sugars_g is None  # type: ignore[union-attr]
    assert result.product.quality_flag is QS


def test_empty_or_null_values_are_just_missing() -> None:
    off = minimal()
    off["nutriments"]["sugars_100g"] = None
    off["nutriments"]["fiber_100g"] = ""
    result = normalize("6194001800104", off)
    assert result.product.quality_flag is QI
    assert result.issues == ["missing: sugars_g"]  # undeclared fibre is fine (decision 8)


def test_energy_has_no_100_limit_but_kcal_fallback_converts() -> None:
    off = minimal()
    off["nutriments"] = {"energy-kcal_100g": 900, "fat_100g": 100}
    result = normalize("6194001800104", off)
    assert result.nutrition.energy_kj == 3780  # type: ignore[union-attr]


def test_energy_consistency_bounds() -> None:
    def issues(kj: float, kcal: float) -> list[str]:
        off = minimal()
        off["nutriments"]["energy-kj_100g"] = kj
        off["nutriments"]["energy-kcal_100g"] = kcal
        return [i for i in normalize("6194001800104", off).issues if i.startswith("energy")]

    assert issues(1000, 239) == []  # 4.18 kJ/kcal
    assert issues(410, 100) == []  # 4.1: within the EU factor range
    assert issues(370, 100) == []  # 3.7 but within 20 kJ of 3.9
    assert issues(369, 100) != []
    assert issues(455, 100) == []  # 4.55: within 20 kJ of 4.35
    assert issues(456, 100) != []
    assert issues(5, 0) == []  # kcal 0: no ratio to check


def test_salt_sodium_rounding_is_tolerated() -> None:
    off = minimal()
    off["nutriments"]["salt_100g"] = 0.5
    off["nutriments"]["sodium_100g"] = 0.21  # x 2.5 = 0.525: 5 % of 0.525 > 0.025
    assert normalize("6194001800104", off).product.quality_flag is QC
    off["nutriments"]["sodium_100g"] = 0.23  # 0.575
    assert normalize("6194001800104", off).product.quality_flag is QS


@pytest.mark.parametrize("nutriments", [None, "junk", []])
def test_missing_nutriments(nutriments: Any) -> None:
    result = normalize("6194001800104", minimal(nutriments=nutriments))
    assert result.nutrition is None
    assert "no nutriments" in result.issues


def test_nothing_usable() -> None:
    result = normalize("6194001800104", minimal(nutriments={"vitamin-c_100g": 0.1}))
    assert result.nutrition is None
    assert result.issues == ["no usable per-100 g values", "no nutrition facts"]


def test_water_without_values_is_complete() -> None:
    off = minimal(
        nutriments={}, nutriscore={"2023": {"category_available": 1, "data": {"is_water": 1}}}
    )
    result = normalize("6194001800104", off)
    assert (result.product.category, result.product.quality_flag) == (Category.WATER, QI)
    assert result.issues == ["no usable per-100 g values"]


def test_basis_defaults_by_category_when_undeclared() -> None:
    beverage = {"2023": {"category_available": 1, "data": {"is_beverage": 1}}}
    drink = minimal(nutrition_data_per=None, nutriscore=beverage)
    assert normalize("6194001800104", drink).nutrition.basis is M  # type: ignore[union-attr]
    food = minimal(nutrition_data_per=None)
    assert normalize("6194001800104", food).nutrition.basis is G  # type: ignore[union-attr]


@pytest.mark.parametrize(
    ("fields", "name"),
    [
        ({"product_name_fr": " Harissa ", "product_name": "Harissa paste"}, "Harissa"),
        ({"product_name_fr": "", "product_name": "Harissa paste"}, "Harissa paste"),
        ({"generic_name": "Piment", "product_name_ar": "هريسة"}, "Piment"),
        ({"product_name_ar": "هريسة"}, "هريسة"),
        ({"product_name": "Huile d\\'olive"}, "Huile d'olive"),
        ({"product_name": 42}, None),
        ({}, None),
    ],
)
def test_name_fallbacks(fields: dict[str, Any], name: str | None) -> None:
    assert normalize("6194001800104", minimal(**fields)).product.name == name


@pytest.mark.parametrize(
    ("brands", "brand"),
    [("Délice, Milkana", "Délice"), (" Safia ", "Safia"), ("", None), (None, None), (",x", None)],
)
def test_brand(brands: Any, brand: str | None) -> None:
    assert normalize("6194001800104", minimal(brands=brands)).product.brand == brand


@pytest.mark.parametrize(
    ("version", "grade", "expected"),
    [
        ("2023", "b", Grade.B),
        (2023, "e", Grade.E),
        ("2023", "unknown", None),
        ("2023", "not-applicable", None),
        ("2023", None, None),
        ("2021", "b", None),
        (None, "b", None),
    ],
)
def test_off_grade(version: Any, grade: Any, expected: Grade | None) -> None:
    off = minimal(nutriscore_version=version, nutriscore_grade=grade)
    assert normalize("6194001800104", off).off_grade == expected


def test_additives_ignore_garbage() -> None:
    off = minimal(additives_tags=["en:e330", "junk", 5, "en:e330"])
    assert normalize("6194001800104", off).product.additives == ["E330"]
    assert normalize("6194001800104", minimal(additives_tags="en:e330")).product.additives == []


def test_components_without_fvl_fall_back_to_the_estimate() -> None:
    data = {"components": {"negative": [{"id": "sugars", "value": 5}], "positive": []}}
    off = minimal(nutriscore={"2023": {"category_available": 1, "data": data}})
    assert normalize("6194001800104", off).nutrition.fvl_percent == 10  # type: ignore[union-attr]


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        (1_750_000_000, datetime(2025, 6, 15, 15, 6, 40, tzinfo=UTC)),
        (1_750_000_000.5, datetime(2025, 6, 15, 15, 6, 40, 500_000, tzinfo=UTC)),
        (None, None),
        ("1750000000", None),
        (True, None),
        (0, None),  # 1970: before Open Food Facts existed
        (10**20, None),
        (float("inf"), None),
        (float("nan"), None),
    ],
)
def test_source_modified_at(raw: Any, expected: datetime | None) -> None:
    off = minimal(last_modified_t=raw)
    assert normalize("6194001800104", off).product.source_modified_at == expected


# ---------------------------------------------------------------- schema 1003+ (bulk exports)

EXPORT_FIXTURES = FIXTURES.parent / "off_export"


def schema1004(name: str) -> dict[str, Any]:
    product: dict[str, Any] = json.loads(
        (EXPORT_FIXTURES / f"{name}.json").read_text(encoding="utf-8")
    )
    return product


def test_schema_1004_recorded_product_gets_offs_grade() -> None:
    off = schema1004("schema1004-general-sweet-spread")
    assert (off["schema_version"], off["nutriments"]) == (1004, {})

    result = normalize(off["code"], off)

    assert (result.product.category, result.product.quality_flag) == (Category.GENERAL, QC)
    nutrition = result.nutrition
    assert nutrition is not None
    assert nutrition.basis == G
    assert (nutrition.energy_kj, nutrition.sugars_g, nutrition.saturated_fat_g) == (
        Decimal(2206),
        Decimal("48.7"),
        Decimal(17),
    )
    assert (nutrition.salt_g, nutrition.fibre_g, nutrition.protein_g) == (
        Decimal("0.4"),
        Decimal("0.5"),
        Decimal("6.3"),
    )
    assert nutrition.fvl_percent == 0
    graded = score(Category.GENERAL, nutrition_input(NutritionFacts(**nutrition.model_dump())))
    assert isinstance(graded, NutriScore)
    assert graded.grade == result.off_grade == Grade.E


def test_schema_1004_estimates_are_not_declared_values() -> None:
    off = schema1004("schema1004-general-estimated-fibre")
    aggregated = off["nutrition"]["aggregated_set"]["nutrients"]
    assert aggregated["fiber"]["source"] == "estimate"

    nutrition = normalize(off["code"], off).nutrition

    assert nutrition is not None
    assert nutrition.fibre_g is None  # estimated from the ingredients: not declared
    assert nutrition.fvl_percent == Decimal("6.8")  # OFF's own 2023 input (an estimate)
    assert nutrition.sugars_g == Decimal(13)


def aggregated(
    nutrients: dict[str, Any], *, per: str = "100g", preparation: str = "as_sold"
) -> dict[str, Any]:
    return {
        "nutriments": {},
        "nutrition": {
            "aggregated_set": {"per": per, "preparation": preparation, "nutrients": nutrients}
        },
        "nutriscore": {"2023": {"category_available": 1, "data": {}}},
    }


def g(value: Any, **extra: Any) -> dict[str, Any]:
    return {"value": value, "unit": "g", "source": "packaging", **extra}


def test_schema_1004_mapping() -> None:
    off = aggregated(
        {
            "energy-kcal": {"value": 100, "unit": "kcal"},
            "sugars": g(5),
            "fiber": g(2, modifier="<"),
            "sodium": g(0.4),
            "fruits-vegetables-legumes": {"value": 30, "unit": "%", "source": "estimate"},
            "proteins": {"unit": "g", "value_computed": 3},  # no declared value
            "fat": "garbage",
            "vitamin-c": {"value": 12, "unit": "mg"},  # not read
        },
        per="100ml",
    )
    result = normalize("6194001800104", off)
    nutrition = result.nutrition
    assert nutrition is not None
    assert (nutrition.basis, nutrition.energy_kj, nutrition.sugars_g) == (M, 420, 5)
    assert (nutrition.fibre_g, nutrition.salt_g, nutrition.fvl_percent) == (2, 1, 30)
    assert (nutrition.protein_g, nutrition.total_fat_g) == (None, None)
    assert result.product.quality_flag == QI
    assert not any("unit" in issue for issue in result.issues)


def test_schema_1004_unexpected_unit_is_suspect() -> None:
    result = normalize("6194001800104", aggregated({"salt": {"value": 400, "unit": "mg"}}))
    assert result.product.quality_flag == QS
    assert "unexpected unit for salt: 'mg'" in result.issues
    assert result.nutrition is None or result.nutrition.salt_g is None


def test_schema_1004_prepared_values_are_not_used() -> None:
    result = normalize("6194001800104", aggregated({"sugars": g(5)}, preparation="prepared"))
    assert result.nutrition is None
    assert "nutrition declared for the prepared product only (not used)" in result.issues


def test_schema_1004_per_serving_is_refused() -> None:
    result = normalize("6194001800104", aggregated({"sugars": g(5)}, per="serving"))
    assert result.nutrition is None
    assert "nutrition declared per serving only (not converted)" in result.issues


@pytest.mark.parametrize("nutrition", [{}, {"aggregated_set": None}, {"input_sets": []}])
def test_schema_1004_without_aggregated_values(nutrition: dict[str, Any]) -> None:
    off = {**aggregated({}), "nutrition": nutrition}
    assert normalize("6194001800104", off).nutrition is None


def test_schema_1004_nutrients_not_a_mapping() -> None:
    off = aggregated({})
    off["nutrition"]["aggregated_set"]["nutrients"] = ["sugars"]
    assert normalize("6194001800104", off).nutrition is None


@pytest.mark.parametrize("flag", [True, "on"])
def test_schema_1004_no_nutrition_on_packaging(flag: Any) -> None:
    off = {**aggregated({}), "nutrition": {"no_nutrition_data_on_packaging": flag}}
    result = normalize("6194001800104", off)
    assert result.nutrition is None
    assert "OFF has no nutrition data for this product" in result.issues


def test_old_shape_wins_when_both_are_present() -> None:
    off = minimal(nutrition={"aggregated_set": {"per": "100g", "preparation": "as_sold",
                                                "nutrients": {"sugars": g(99)}}})  # fmt: skip
    assert normalize("6194001800104", off).nutrition.sugars_g == 5  # type: ignore[union-attr]


@pytest.mark.parametrize(
    ("name", "expected"),
    [
        ("cheese-tunisian-processed", True),  # OFF estimated an input, e.g. fruit/veg share
        ("general-complete-spread", False),
        ("cheese-tunisian-ricotta", None),  # OFF has no grade
    ],
)
def test_off_grade_estimated(name: str, expected: bool | None) -> None:
    assert normalized(name).off_grade_estimated is expected


@pytest.mark.parametrize(
    ("estimated", "expected"), [(1, True), (0, False), (True, True), ("1", None), (None, None)]
)
def test_off_grade_estimated_values(estimated: Any, expected: bool | None) -> None:
    data = {"category_available": 1, "data": {}, "estimated": estimated}
    off = minimal(nutriscore={"2023": data}, nutriscore_version="2023", nutriscore_grade="c")
    assert normalize("6194001800104", off).off_grade_estimated is expected
