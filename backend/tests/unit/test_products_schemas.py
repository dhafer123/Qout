"""Pydantic schemas of the products module, and the mapping to and from the engine."""

import json
import uuid
from datetime import UTC, datetime
from decimal import Decimal
from pathlib import Path
from typing import Any

import pytest
from pydantic import ValidationError

from app.modules.products.models import (
    DataSource,
    NutritionBasis,
    NutritionFacts,
    Product,
    ProductStatus,
    Score,
)
from app.modules.products.schemas import (
    NutritionFactsCreate,
    NutritionFactsRead,
    ProductCreate,
    ProductRead,
    ScanEventCreate,
    ScoreRead,
)
from app.modules.products.scoring import nutrition_input, score_row
from app.modules.scoring import Category, Grade, NutritionInput, score
from tests.unit.scoring.golden import GOLDEN_FILES, load

NOW = datetime(2026, 11, 12, tzinfo=UTC)

# ---------------------------------------------------------------- products


def test_product_create_defaults() -> None:
    product = ProductCreate(ean="6194001234567", source=DataSource.OPEN_FOOD_FACTS)
    assert product.status is ProductStatus.UNVERIFIED
    assert product.additives == []
    assert product.category is None


@pytest.mark.parametrize("ean", ["1234567", "123456789012345", "61940012345ab", ""])
def test_product_create_rejects_bad_eans(ean: str) -> None:
    with pytest.raises(ValidationError, match="ean"):
        ProductCreate(ean=ean, source=DataSource.MANUAL)


@pytest.mark.parametrize("ean", ["12345678", "012345678905", "6194001234567", "16194001234564"])
def test_product_create_accepts_8_to_14_digits(ean: str) -> None:
    assert ProductCreate(ean=ean, source=DataSource.MANUAL).ean == ean


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("nova_group", 0),
        ("nova_group", 5),
        ("category", "snacks"),
        ("status", "deleted"),
        ("quality_flag", "great"),
        ("source", "scraper"),
        ("colour", "red"),
    ],
)
def test_product_create_rejects_bad_values(field: str, value: Any) -> None:
    data: dict[str, Any] = {"ean": "6194001234567", "source": "manual", field: value}
    with pytest.raises(ValidationError, match=field):
        ProductCreate.model_validate(data)


def test_product_read_from_orm() -> None:
    product = Product(
        id=uuid.uuid4(),
        ean="6194001234567",
        name="Harissa",
        category=Category.GENERAL,
        source=DataSource.OPEN_FOOD_FACTS,
        status=ProductStatus.VERIFIED,
        nova_group=3,
        additives=["E330"],
        created_at=NOW,
        updated_at=NOW,
    )
    read = ProductRead.model_validate(product)
    assert (read.ean, read.category, read.status, read.additives) == (
        "6194001234567",
        Category.GENERAL,
        ProductStatus.VERIFIED,
        ["E330"],
    )
    assert read.model_dump(mode="json")["category"] == "general"


# ---------------------------------------------------------------- nutrition facts


def test_nutrition_create_keeps_exact_decimals() -> None:
    facts = NutritionFactsCreate.model_validate(
        {"basis": "per_100g", "source": "manual", "salt_g": "0.0254", "sugars_g": 4.1}
    )
    assert facts.salt_g == Decimal("0.0254")
    assert facts.sugars_g == Decimal("4.1")


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("sugars_g", -0.1),
        ("salt_g", 100.5),
        ("fvl_percent", 101),
        ("energy_kj", -1),
        ("protein_g", "NaN"),
        ("fibre_g", "Infinity"),
    ],
)
def test_nutrition_create_rejects_impossible_values(field: str, value: Any) -> None:
    with pytest.raises(ValidationError, match=field):
        NutritionFactsCreate.model_validate({"basis": "per_100g", "source": "manual", field: value})


def test_energy_has_no_gram_limit() -> None:
    facts = NutritionFactsCreate(
        basis=NutritionBasis.PER_100G, source=DataSource.MANUAL, energy_kj=Decimal(3700)
    )
    assert facts.energy_kj == 3700


def test_nutrition_read_serialises_numbers() -> None:
    facts = NutritionFacts(
        id=uuid.uuid4(),
        product_id=uuid.uuid4(),
        version=2,
        basis=NutritionBasis.PER_100ML,
        source=DataSource.OPEN_FOOD_FACTS,
        sugars_g=Decimal("4.10"),
        salt_g=None,
        created_at=NOW,
    )
    payload = NutritionFactsRead.model_validate(facts).model_dump(mode="json")
    assert payload["sugars_g"] == 4.1
    assert payload["salt_g"] is None
    assert payload["basis"] == "per_100ml"
    json.dumps(payload)  # plain JSON numbers, not strings


# ---------------------------------------------------------------- scores and scans


def test_score_read_from_orm() -> None:
    row = Score(
        id=uuid.uuid4(),
        product_id=uuid.uuid4(),
        nutrition_facts_id=None,
        engine_version="nutriscore-2023.1",
        grade=Grade.A,
        total=None,
        breakdown={"grade": "A"},
        off_grade=None,
        created_at=NOW,
    )
    read = ScoreRead.model_validate(row)
    assert (read.grade, read.total, read.breakdown) == (Grade.A, None, {"grade": "A"})


def test_scan_event_create() -> None:
    assert ScanEventCreate(ean="12345678", outcome="not_found").product_id is None  # type: ignore[arg-type]
    with pytest.raises(ValidationError):
        ScanEventCreate(ean="1234", outcome="found")  # type: ignore[arg-type]


# ---------------------------------------------------------------- engine mapping


def facts_from_golden(raw: dict[str, Any]) -> NutritionFacts:
    """Stored facts as Postgres would return them: Decimal from the JSON text."""
    amounts = {k: Decimal(str(v)) for k, v in raw.items() if k != "non_nutritive_sweeteners"}
    return NutritionFacts(
        basis=NutritionBasis.PER_100G,
        source=DataSource.MANUAL,
        non_nutritive_sweeteners=raw.get("non_nutritive_sweeteners"),
        **amounts,
    )


@pytest.mark.parametrize("path", GOLDEN_FILES, ids=lambda p: p.stem)
def test_golden_cases_through_stored_facts(path: Path) -> None:
    """Database values -> engine -> scores row reproduces every golden case."""
    case = load(path)
    product_id, facts_id = uuid.uuid4(), uuid.uuid4()
    result = score(Category(case["category"]), nutrition_input(facts_from_golden(case["input"])))
    row = score_row(result, product_id=product_id, nutrition_facts_id=facts_id)

    assert row.breakdown == case["expected"]
    expected = case["expected"]
    if "insufficient_data" in expected:
        assert (row.grade, row.total) == (None, None)
    elif "score" in expected:
        assert (row.grade, row.total) == (expected["grade"], expected["score"])
    else:  # water
        assert (row.grade, row.total) == ("A", None)
    assert (row.product_id, row.nutrition_facts_id) == (product_id, facts_id)


def test_nutrition_input_keeps_missing_fields_missing() -> None:
    facts = NutritionFacts(basis=NutritionBasis.PER_100G, source=DataSource.MANUAL)
    assert nutrition_input(facts) == NutritionInput()


def test_nutrition_input_keeps_threshold_values_exact() -> None:
    facts = facts_from_golden({"saturated_fat_g": 0.58, "total_fat_g": 1})
    assert nutrition_input(facts) == NutritionInput(saturated_fat_g=0.58, total_fat_g=1.0)


def test_score_row_records_off_grade() -> None:
    result = score(Category.WATER, NutritionInput())
    row = score_row(result, product_id=uuid.uuid4(), nutrition_facts_id=None, off_grade=Grade.A)
    assert (row.off_grade, row.engine_version) == (Grade.A, result.engine_version)
