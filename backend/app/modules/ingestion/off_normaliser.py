"""Open Food Facts product JSON -> our product and nutrition schemas.

Pure functions, no I/O. Decisions (TASKS.md, T13):
- Scoring category from OFF's own Nutri-Score 2023 classification
  (`nutriscore["2023"]`: `category_available` and the `is_*` flags, which follow the same
  Q&A definitions). No classification -> no category (not scored), never a guess.
- Inputs that depend on the category come from the same place when OFF provides them:
  fruits/vegetables/legumes % (OFF applies the fats rule that olive oil counts) and the
  number of non-nutritive sweeteners (beverages).
- Values per 100 g / 100 mL only. Data declared per serving only is refused, not converted.
- Unusable values (not a number, negative, more than 100 g per 100 g) are dropped, never
  clamped, and the product is flagged suspect.
"""

import math
from collections.abc import Mapping
from dataclasses import dataclass, field
from decimal import Decimal, InvalidOperation
from typing import Any

from pydantic import BaseModel

from app.modules.products.models import DataSource, NutritionBasis, QualityFlag
from app.modules.products.schemas import NutritionFactsCreate, ProductCreate
from app.modules.scoring import (
    REQUIRED_FIELDS,
    Category,
    Grade,
    additives_from_off,
    kj_from_kcal,
    nova_group_from_off,
    salt_from_sodium,
)

_GRAM_FIELDS = {  # our field -> OFF nutriment (per 100 g / 100 mL)
    "sugars_g": "sugars_100g",
    "saturated_fat_g": "saturated-fat_100g",
    "total_fat_g": "fat_100g",
    "fibre_g": "fiber_100g",
    "protein_g": "proteins_100g",
}
_FLAGS = (  # first match wins: water is also flagged as a beverage
    ("is_water", Category.WATER),
    ("is_beverage", Category.BEVERAGE),
    ("is_cheese", Category.CHEESE),
    ("is_fat_oil_nuts_seeds", Category.FATS_OILS_NUTS_SEEDS),
    ("is_red_meat_product", Category.RED_MEAT),
)
_GRADES = {"a": Grade.A, "b": Grade.B, "c": Grade.C, "d": Grade.D, "e": Grade.E}
_HUNDRED = Decimal(100)

# Data-quality heuristics (not scoring constants). EU energy factors (Regulation (EU)
# 1169/2011, Annex XIV) give 4.0 (fibre) to 4.25 (protein, carbohydrate) kJ per kcal;
# labels round, so allow 0.1 either side and ignore differences under 20 kJ.
_KJ_PER_KCAL_RANGE = (Decimal("3.9"), Decimal("4.35"))
_ENERGY_SLACK_KJ = Decimal(20)
# Salt and sodium both declared (OFF usually derives one from the other): allow label
# rounding, 0.01 g or 5 %.
_SALT_SLACK_G = Decimal("0.01")
_SALT_SLACK_RATIO = Decimal("0.05")


@dataclass
class _Report:
    """Problems found while normalising: suspect values, or gaps (incomplete data)."""

    suspect: list[str] = field(default_factory=list)
    gaps: list[str] = field(default_factory=list)

    def flag(self) -> QualityFlag:
        if self.suspect:
            return QualityFlag.SUSPECT
        return QualityFlag.INCOMPLETE if self.gaps else QualityFlag.COMPLETE


class NormalizedProduct(BaseModel):
    """What the lookup and import store for one OFF product."""

    product: ProductCreate
    nutrition: NutritionFactsCreate | None
    """None when OFF has no usable per-100 g values at all."""
    off_grade: Grade | None
    """OFF's own Nutri-Score grade, only when computed with the 2023 algorithm."""
    issues: list[str]
    """Why the quality flag is not `complete` (empty when it is): suspect values first."""


def normalize(ean: str, off: Mapping[str, Any]) -> NormalizedProduct:
    """Normalise the `product` object returned by `OffClient.get_product`."""
    report = _Report()
    category = _category(off)
    nutrition = _nutrition(off, category, report)
    _check_completeness(category, nutrition, report)

    product = ProductCreate(
        ean=ean,
        source=DataSource.OPEN_FOOD_FACTS,
        name=_name(off),
        brand=_brand(off),
        category=category,
        image_url=_text(off.get("image_front_url")),
        nova_group=nova_group_from_off(off.get("nova_group")),
        additives=[a.code for a in additives_from_off(_list(off.get("additives_tags")))],
        quality_flag=report.flag(),
    )
    return NormalizedProduct(
        product=product,
        nutrition=nutrition,
        off_grade=_off_grade(off),
        issues=report.suspect + report.gaps,
    )


# ---------------------------------------------------------------- category


def _nutriscore_2023(off: Mapping[str, Any]) -> Mapping[str, Any]:
    nutriscore = off.get("nutriscore")
    data = nutriscore.get("2023") if isinstance(nutriscore, Mapping) else None
    return data if isinstance(data, Mapping) else {}


def _category(off: Mapping[str, Any]) -> Category | None:
    ns = _nutriscore_2023(off)
    if not ns.get("category_available"):
        return None
    data = ns.get("data")
    flags = data if isinstance(data, Mapping) else {}
    for flag, category in _FLAGS:
        if flags.get(flag) in (1, True):
            return category
    return Category.GENERAL


def _component(off: Mapping[str, Any], component_id: str) -> Any:
    """`value` of a 2023 score component (negative or positive), or None."""
    data = _nutriscore_2023(off).get("data")
    components = data.get("components") if isinstance(data, Mapping) else None
    if not isinstance(components, Mapping):
        return None
    for side in ("negative", "positive"):
        for component in _list(components.get(side)):
            if isinstance(component, Mapping) and component.get("id") == component_id:
                return component.get("value")
    return None


# ---------------------------------------------------------------- nutrition


def _nutrition(
    off: Mapping[str, Any], category: Category | None, report: _Report
) -> NutritionFactsCreate | None:
    if off.get("no_nutrition_data") == "on":
        report.gaps.append("OFF has no nutrition data for this product")
        return None
    if off.get("nutrition_data_per") == "serving":
        report.gaps.append("nutrition declared per serving only (not converted)")
        return None
    nutriments = off.get("nutriments")
    if not isinstance(nutriments, Mapping):
        report.gaps.append("no nutriments")
        return None

    values: dict[str, Any] = {
        ours: _amount(nutriments, theirs, report) for ours, theirs in _GRAM_FIELDS.items()
    }
    values["energy_kj"] = _energy_kj(nutriments, report)
    values["salt_g"] = _salt(nutriments, report)
    values["fvl_percent"] = _fvl(off, nutriments, report)
    if category is Category.BEVERAGE:
        values["non_nutritive_sweeteners"] = _sweeteners(off)
    if all(v is None for v in values.values()):
        report.gaps.append("no usable per-100 g values")
        return None

    _sanity_checks(nutriments, values, report)
    return NutritionFactsCreate(
        basis=_basis(off, category), source=DataSource.OPEN_FOOD_FACTS, **values
    )


def _basis(off: Mapping[str, Any], category: Category | None) -> NutritionBasis:
    """The unit declared on the pack (Q&A p. 12: per 100 g if both are given); if OFF
    does not say, 100 mL for drinks and 100 g otherwise."""
    declared = off.get("nutrition_data_per")
    if declared == "100g":
        return NutritionBasis.PER_100G
    if declared == "100ml":
        return NutritionBasis.PER_100ML
    if category in (Category.BEVERAGE, Category.WATER):
        return NutritionBasis.PER_100ML
    return NutritionBasis.PER_100G


def _amount(
    nutriments: Mapping[str, Any], key: str, report: _Report, *, at_most_100: bool = True
) -> Decimal | None:
    """A per-100 value, or None if absent; unusable values are dropped and reported."""
    raw = nutriments.get(key)
    if raw is None or raw == "":
        return None
    value = _decimal(raw)
    if value is None or value < 0 or (at_most_100 and value > _HUNDRED):
        report.suspect.append(f"unusable {key}: {raw!r}")
        return None
    return value


def _decimal(raw: object) -> Decimal | None:
    if isinstance(raw, bool):
        return None
    if isinstance(raw, int):
        return Decimal(raw)
    if isinstance(raw, float):
        return Decimal(repr(raw)) if math.isfinite(raw) else None
    if isinstance(raw, str):
        try:
            value = Decimal(raw.strip().replace(",", "."))
        except InvalidOperation:
            return None
        return value if value.is_finite() else None
    return None


def _energy_kj(nutriments: Mapping[str, Any], report: _Report) -> Decimal | None:
    for key in ("energy-kj_100g", "energy_100g"):  # OFF's energy_100g is in kJ
        value = _amount(nutriments, key, report, at_most_100=False)
        if value is not None:
            return value
    kcal = _amount(nutriments, "energy-kcal_100g", report, at_most_100=False)
    return None if kcal is None else Decimal(kj_from_kcal(float(kcal)))


def _salt(nutriments: Mapping[str, Any], report: _Report) -> Decimal | None:
    salt = _amount(nutriments, "salt_100g", report)
    if salt is not None:
        return salt
    sodium = _amount(nutriments, "sodium_100g", report)
    return None if sodium is None else Decimal(repr(salt_from_sodium(float(sodium))))


def _fvl(off: Mapping[str, Any], nutriments: Mapping[str, Any], report: _Report) -> Decimal | None:
    """OFF's 2023 input (category rules applied), else declared, else estimated."""
    component = _component(off, "fruits_vegetables_legumes")
    if component is not None:
        value = _decimal(component)
        if value is not None and 0 <= value <= _HUNDRED:
            return value
        report.suspect.append(f"unusable fruits_vegetables_legumes component: {component!r}")
    for key in (
        "fruits-vegetables-legumes_100g",
        "fruits-vegetables-legumes-estimate-from-ingredients_100g",
    ):
        value = _amount(nutriments, key, report)
        if value is not None:
            return value
    return None


def _sweeteners(off: Mapping[str, Any]) -> bool | None:
    """Beverages: OFF's count of non-nutritive sweeteners (Q&A Appendix 3); None if absent."""
    count = _decimal(_component(off, "non_nutritive_sweeteners"))
    return None if count is None else count > 0


def _sanity_checks(
    nutriments: Mapping[str, Any], values: Mapping[str, Any], report: _Report
) -> None:
    fat, saturated = values["total_fat_g"], values["saturated_fat_g"]
    if fat is not None and saturated is not None and saturated > fat:
        report.suspect.append(f"saturated fat {saturated} g > total fat {fat} g")

    sugars = values["sugars_g"]
    carbohydrates = _decimal(nutriments.get("carbohydrates_100g"))
    if sugars is not None and carbohydrates is not None and sugars > carbohydrates:
        report.suspect.append(f"sugars {sugars} g > carbohydrates {carbohydrates} g")

    salt, sodium = _decimal(nutriments.get("salt_100g")), _decimal(nutriments.get("sodium_100g"))
    if salt is not None and sodium is not None and salt >= 0 and sodium >= 0:
        expected = Decimal(repr(salt_from_sodium(float(sodium))))
        slack = max(_SALT_SLACK_G, _SALT_SLACK_RATIO * max(salt, expected))
        if abs(salt - expected) > slack:
            report.suspect.append(f"salt {salt} g does not match sodium {sodium} g")

    kj, kcal = values["energy_kj"], _decimal(nutriments.get("energy-kcal_100g"))
    if kj is not None and kcal is not None and kcal > 0:
        low_ratio, high_ratio = _KJ_PER_KCAL_RANGE
        lowest, highest = low_ratio * kcal - _ENERGY_SLACK_KJ, high_ratio * kcal + _ENERGY_SLACK_KJ
        if not lowest <= kj <= highest:
            report.suspect.append(f"energy {kj} kJ does not match {kcal} kcal")


def _check_completeness(
    category: Category | None, nutrition: NutritionFactsCreate | None, report: _Report
) -> None:
    if category is None:
        report.gaps.append("OFF has no Nutri-Score category for this product")
        return
    if nutrition is None:
        if category is not Category.WATER:
            report.gaps.append("no nutrition facts")
        return
    missing = [f for f in REQUIRED_FIELDS[category] if getattr(nutrition, f) is None]
    if missing:
        report.gaps.append(f"missing: {', '.join(missing)}")


# ---------------------------------------------------------------- text and grade


def _off_grade(off: Mapping[str, Any]) -> Grade | None:
    if str(off.get("nutriscore_version")) != "2023":
        return None
    grade = off.get("nutriscore_grade")
    return _GRADES.get(grade) if isinstance(grade, str) else None


def _name(off: Mapping[str, Any]) -> str | None:
    for key in ("product_name_fr", "product_name", "generic_name", "product_name_ar"):
        name = _text(off.get(key))
        if name:
            return name
    return None


def _brand(off: Mapping[str, Any]) -> str | None:
    brands = _text(off.get("brands"))
    return _text(brands.split(",")[0]) if brands else None


def _text(value: object) -> str | None:
    """Trimmed text; OFF sometimes stores escaped quotes (d\\'olive)."""
    if not isinstance(value, str):
        return None
    cleaned = value.replace("\\'", "'").strip()
    return cleaned or None


def _list(value: object) -> list[Any]:
    return value if isinstance(value, list) else []
