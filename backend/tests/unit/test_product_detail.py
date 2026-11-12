"""Mapping stored rows to the lookup response (no database)."""

import json
import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

from app.modules.products.lookup import product_detail
from app.modules.products.models import NutritionFacts, ProductStatus, Score
from app.modules.products.schemas import ProductDetail
from app.modules.scoring import ENGINE_VERSION, Category, Grade, OverexposureRisk
from tests.factories import NutritionFactsFactory, ProductFactory, ScoreFactory

T0 = datetime(2026, 11, 12, 9, 0, tzinfo=UTC)


def stored_facts(product_id: uuid.UUID, created_at: datetime) -> NutritionFacts:
    return NutritionFactsFactory.build(
        id=uuid.uuid4(),
        product_id=product_id,
        salt_g=Decimal("0.107"),
        created_at=created_at,
    )


def stored_score(product_id: uuid.UUID, facts_id: uuid.UUID, created_at: datetime) -> Score:
    return ScoreFactory.build(
        id=uuid.uuid4(),
        product_id=product_id,
        nutrition_facts_id=facts_id,
        grade=Grade.B,
        total=1,
        breakdown={"grade": "B", "assumed_zero": ["fibre_g"]},
        created_at=created_at,
    )


def test_full_product() -> None:
    product = ProductFactory.build(
        id=uuid.uuid4(),
        ean="3017620422003",
        name="Nutella",
        category=Category.GENERAL,
        status=ProductStatus.UNVERIFIED,
        nova_group=4,
        additives=["E250", "E9999"],
        created_at=T0,
        updated_at=T0,
    )
    facts = stored_facts(product.id, T0 + timedelta(seconds=1))
    score = stored_score(product.id, facts.id, T0 + timedelta(seconds=2))

    detail = product_detail(product, facts, score)

    assert detail.ean == "3017620422003"
    assert detail.updated_at == T0 + timedelta(seconds=2)
    assert detail.nutrition is not None
    assert detail.nutrition.salt_g == Decimal("0.107")
    assert detail.nutrition.version == 1
    assert detail.score is not None
    assert (detail.score.grade, detail.score.total) == (Grade.B, 1)
    assert detail.score.engine_version == ENGINE_VERSION
    assert detail.score.breakdown["assumed_zero"] == ["fibre_g"]
    known, unknown = detail.additives
    assert (known.code, known.name, known.overexposure_risk) == (
        "E250",
        "Sodium nitrite",
        OverexposureRisk.HIGH,
    )
    assert (unknown.code, unknown.name, unknown.overexposure_risk) == (
        "E9999",
        None,
        OverexposureRisk.UNKNOWN,
    )


def test_without_nutrition_or_score_updated_at_is_the_product() -> None:
    product = ProductFactory.build(
        id=uuid.uuid4(),
        status=ProductStatus.UNVERIFIED,
        additives=[],
        created_at=T0,
        updated_at=T0 + timedelta(hours=1),
    )
    detail = product_detail(product, None, None)
    assert (detail.nutrition, detail.score) == (None, None)
    assert detail.updated_at == T0 + timedelta(hours=1)


def test_json_round_trip_keeps_amounts_as_numbers() -> None:
    product = ProductFactory.build(
        id=uuid.uuid4(), status=ProductStatus.UNVERIFIED, additives=[], updated_at=T0
    )
    facts = stored_facts(product.id, T0)
    detail = product_detail(product, facts, None)
    body = json.loads(detail.model_dump_json())
    assert body["nutrition"]["salt_g"] == 0.107
    assert ProductDetail.model_validate_json(detail.model_dump_json()) == detail
