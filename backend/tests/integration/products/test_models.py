"""Database constraints of the product tables (real Postgres).

Constraints are checked with plain SQL on purpose: the ORM already validates enum values
in Python, and these tests prove the database rejects bad rows on its own.
"""

from decimal import Decimal
from typing import Any

import pytest
from sqlalchemy import select, text
from sqlalchemy.exc import DBAPIError, IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.products.models import NutritionFacts, Product, ScanEvent, Score
from app.modules.scoring import ENGINE_VERSION
from tests.factories import (
    NutritionFactsFactory,
    ProductFactory,
    ScanEventFactory,
    ScoreFactory,
)


async def violates(session: AsyncSession, sql: str, **params: Any) -> str:
    """Run `sql` in a savepoint; return the violated constraint's name."""
    with pytest.raises(IntegrityError) as excinfo:
        async with session.begin_nested():
            await session.execute(text(sql), params)
    name: str = excinfo.value.orig.__cause__.constraint_name  # type: ignore[union-attr]
    return name


INSERT_PRODUCT = (
    "INSERT INTO products (ean, source, category, status, quality_flag, nova_group) "
    "VALUES (:ean, :source, :category, :status, :quality_flag, :nova_group)"
)
VALID_PRODUCT = {
    "ean": "6191234567890",
    "source": "open_food_facts",
    "category": "general",
    "status": "unverified",
    "quality_flag": "complete",
    "nova_group": 4,
}


async def test_product_defaults(db_session: AsyncSession) -> None:
    product = await ProductFactory.create(db_session)
    await db_session.refresh(product)
    assert product.status == "unverified"
    assert product.additives == []
    assert product.category is None


async def test_valid_product_row(db_session: AsyncSession) -> None:
    await db_session.execute(text(INSERT_PRODUCT), VALID_PRODUCT)
    stored = await db_session.scalar(select(Product).where(Product.ean == "6191234567890"))
    assert stored is not None
    assert stored.nova_group == 4


@pytest.mark.parametrize(
    ("override", "constraint"),
    [
        ({"ean": "123"}, "ck_products_ean_digits"),
        ({"ean": "61912345abcde"}, "ck_products_ean_digits"),
        ({"category": "snacks"}, "ck_products_product_category"),
        ({"source": "scraper"}, "ck_products_product_source"),
        ({"status": "deleted"}, "ck_products_product_status"),
        ({"quality_flag": "great"}, "ck_products_product_quality_flag"),
        ({"nova_group": 0}, "ck_products_nova_group_range"),
        ({"nova_group": 5}, "ck_products_nova_group_range"),
    ],
)
async def test_invalid_product_rows_are_rejected(
    db_session: AsyncSession, override: dict[str, Any], constraint: str
) -> None:
    assert await violates(db_session, INSERT_PRODUCT, **(VALID_PRODUCT | override)) == constraint


async def test_ean_longer_than_14_is_rejected(db_session: AsyncSession) -> None:
    with pytest.raises(DBAPIError, match="value too long"):
        async with db_session.begin_nested():
            await db_session.execute(text(INSERT_PRODUCT), VALID_PRODUCT | {"ean": "1" * 15})


async def test_ean_is_unique(db_session: AsyncSession) -> None:
    await ProductFactory.create(db_session, ean="6190000000001")
    duplicate = VALID_PRODUCT | {"ean": "6190000000001"}
    assert await violates(db_session, INSERT_PRODUCT, **duplicate) == "uq_products_ean"


@pytest.mark.parametrize(
    ("column", "value", "constraint"),
    [
        ("sugars_g", "-0.01", "ck_nutrition_facts_sugars_g_non_negative"),
        ("energy_kj", "-1", "ck_nutrition_facts_energy_kj_non_negative"),
        ("salt_g", "100.01", "ck_nutrition_facts_salt_g_at_most_100"),
        ("fvl_percent", "101", "ck_nutrition_facts_fvl_percent_at_most_100"),
        ("total_fat_g", "-5", "ck_nutrition_facts_total_fat_g_non_negative"),
    ],
)
async def test_invalid_nutrition_amounts_are_rejected(
    db_session: AsyncSession, column: str, value: str, constraint: str
) -> None:
    product = await ProductFactory.create(db_session)
    sql = (
        f"INSERT INTO nutrition_facts (product_id, version, basis, source, {column}) "  # noqa: S608
        "VALUES (:product_id, 1, 'per_100g', 'manual', :value)"
    )
    assert (
        await violates(db_session, sql, product_id=product.id, value=Decimal(value)) == constraint
    )


async def test_energy_has_no_upper_bound(db_session: AsyncSession) -> None:
    product = await ProductFactory.create(db_session)
    facts = await NutritionFactsFactory.create(
        db_session, product_id=product.id, energy_kj=Decimal(3700)
    )
    assert facts.energy_kj == 3700


async def test_nutrition_amounts_keep_their_exact_value(db_session: AsyncSession) -> None:
    product = await ProductFactory.create(db_session)
    facts = await NutritionFactsFactory.create(
        db_session, product_id=product.id, salt_g=Decimal("0.0254"), sugars_g=Decimal("4.10")
    )
    db_session.expunge(facts)
    stored = await db_session.get(NutritionFacts, facts.id)
    assert stored is not None
    assert (stored.salt_g, str(stored.sugars_g)) == (Decimal("0.0254"), "4.10")


async def test_nutrition_version_is_unique_per_product(db_session: AsyncSession) -> None:
    product = await ProductFactory.create(db_session)
    await NutritionFactsFactory.create(db_session, product_id=product.id, version=1)
    sql = (
        "INSERT INTO nutrition_facts (product_id, version, basis, source) "
        "VALUES (:product_id, :version, 'per_100g', 'manual')"
    )
    assert await violates(db_session, sql, product_id=product.id, version=1) == (
        "uq_nutrition_facts_product_id_version"
    )
    assert await violates(db_session, sql, product_id=product.id, version=0) == (
        "ck_nutrition_facts_version_positive"
    )


async def test_score_total_needs_a_grade(db_session: AsyncSession) -> None:
    product = await ProductFactory.create(db_session)
    sql = (
        "INSERT INTO scores (product_id, engine_version, grade, total, breakdown) "
        "VALUES (:product_id, 'v', :grade, :total, '{}')"
    )
    assert await violates(db_session, sql, product_id=product.id, grade=None, total=3) == (
        "ck_scores_total_needs_grade"
    )
    assert await violates(db_session, sql, product_id=product.id, grade="F", total=1) == (
        "ck_scores_score_grade"
    )
    # Water: a grade without points; insufficient data: neither.
    await db_session.execute(text(sql), {"product_id": product.id, "grade": "A", "total": None})
    await db_session.execute(text(sql), {"product_id": product.id, "grade": None, "total": None})


async def test_one_score_per_facts_and_engine_version(db_session: AsyncSession) -> None:
    product = await ProductFactory.create(db_session)
    facts = await NutritionFactsFactory.create(db_session, product_id=product.id)
    await ScoreFactory.create(db_session, product_id=product.id, nutrition_facts_id=facts.id)
    sql = (
        "INSERT INTO scores (product_id, nutrition_facts_id, engine_version, breakdown) "
        "VALUES (:product_id, :facts_id, :version, '{}')"
    )
    assert (
        await violates(
            db_session, sql, product_id=product.id, facts_id=facts.id, version=ENGINE_VERSION
        )
        == "uq_scores_nutrition_facts_id_engine_version"
    )


async def test_deleting_a_product_cascades(db_session: AsyncSession) -> None:
    product = await ProductFactory.create(db_session)
    facts = await NutritionFactsFactory.create(db_session, product_id=product.id)
    await ScoreFactory.create(db_session, product_id=product.id, nutrition_facts_id=facts.id)
    scan = await ScanEventFactory.create(db_session, ean=product.ean, product_id=product.id)

    await db_session.delete(product)
    await db_session.flush()
    db_session.expunge_all()

    assert await db_session.scalar(select(NutritionFacts.id)) is None
    assert await db_session.scalar(select(Score.id)) is None
    kept = await db_session.get(ScanEvent, scan.id)
    assert kept is not None
    assert kept.product_id is None  # scan history survives, unlinked


async def test_scan_event_ean_is_checked(db_session: AsyncSession) -> None:
    sql = "INSERT INTO scan_events (ean, outcome) VALUES (:ean, :outcome)"
    assert await violates(db_session, sql, ean="12ab5678", outcome="found") == (
        "ck_scan_events_ean_digits"
    )
    assert await violates(db_session, sql, ean="12345678", outcome="maybe") == (
        "ck_scan_events_scan_outcome"
    )
