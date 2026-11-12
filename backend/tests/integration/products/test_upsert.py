"""ProductUpserter against real Postgres: insert, idempotent re-import, updates, rescoring."""

from collections.abc import Sequence
from datetime import UTC, datetime
from decimal import Decimal
from typing import Any

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.ingestion.off_normaliser import NormalizedProduct, normalize
from app.modules.products.models import (
    DataSource,
    NutritionFacts,
    Product,
    ProductStatus,
    Score,
)
from app.modules.products.repository import ScoreRepository
from app.modules.products.upsert import ProductUpserter, UpsertOutcome
from app.modules.scoring import ENGINE_VERSION, Category, Grade
from tests.factories import NutritionFactsFactory, ProductFactory, ScoreFactory

EAN = "6194001800104"
T0 = 1_750_000_000  # OFF last_modified_t


def off_record(
    *,
    sugars: float = 5,
    category: str | None = "general",
    grade: str | None = "c",
    modified: int | None = T0,
    nutrition: bool = True,
    **fields: Any,
) -> NormalizedProduct:
    """A normalised OFF product (general food unless `category` says otherwise)."""
    flags = {
        "general": {},
        "cheese": {"is_cheese": 1},
        "water": {"is_water": 1, "is_beverage": 1},
    }
    product: dict[str, Any] = {
        "product_name": "Biscuits",
        "nutrition_data_per": "100g",
        "nutriscore_version": "2023",
        "nutriscore_grade": grade,
        "last_modified_t": modified,
    }
    if category is not None:
        product["nutriscore"] = {"2023": {"category_available": 1, "data": flags[category]}}
    if nutrition:
        product["nutriments"] = {
            "energy-kj_100g": 1000,
            "sugars_100g": sugars,
            "saturated-fat_100g": 1,
            "fat_100g": 2,
            "salt_100g": 0.5,
            "fiber_100g": 3,
            "proteins_100g": 4,
            "fruits-vegetables-legumes-estimate-from-ingredients_100g": 10,
        }
    else:
        product["no_nutrition_data"] = "on"
    product.update(fields)
    return normalize(EAN, product)


async def upsert(session: AsyncSession, record: NormalizedProduct) -> UpsertOutcome:
    return (await ProductUpserter(session).upsert(record)).outcome


async def stored(session: AsyncSession) -> Product:
    product = await session.scalar(select(Product).where(Product.ean == EAN))
    assert product is not None
    await session.refresh(product)
    return product


async def versions(session: AsyncSession) -> Sequence[NutritionFacts]:
    result = await session.scalars(
        select(NutritionFacts)
        .join(Product, Product.id == NutritionFacts.product_id)
        .where(Product.ean == EAN)
        .order_by(NutritionFacts.version)
    )
    return result.all()


async def scores(session: AsyncSession) -> Sequence[Score]:
    result = await session.scalars(
        select(Score)
        .join(Product, Product.id == Score.product_id)
        .where(Product.ean == EAN)
        .order_by(Score.created_at)
    )
    return result.all()


# ---------------------------------------------------------------- insert and re-import


async def test_new_product_is_inserted_with_nutrition_and_score(db_session: AsyncSession) -> None:
    result = await ProductUpserter(db_session).upsert(off_record())

    assert (result.outcome, result.changed) == (UpsertOutcome.INSERTED, True)
    product = await stored(db_session)
    assert (product.name, product.category, product.source) == (
        "Biscuits",
        Category.GENERAL,
        DataSource.OPEN_FOOD_FACTS,
    )
    assert product.source_modified_at == datetime.fromtimestamp(T0, tz=UTC)
    [facts] = await versions(db_session)
    assert facts.sugars_g == Decimal(5)
    [score] = await scores(db_session)
    assert (score.nutrition_facts_id, score.engine_version) == (facts.id, ENGINE_VERSION)
    assert score.grade is not None
    assert score.off_grade == Grade.C


async def test_same_record_twice_changes_nothing(db_session: AsyncSession) -> None:
    await upsert(db_session, off_record())

    result = await ProductUpserter(db_session).upsert(off_record())

    assert (result.outcome, result.changed) == (UpsertOutcome.UNCHANGED, False)
    assert len(await versions(db_session)) == 1
    assert len(await scores(db_session)) == 1


async def test_unknown_category_is_stored_without_score(db_session: AsyncSession) -> None:
    assert await upsert(db_session, off_record(category=None)) == UpsertOutcome.INSERTED
    assert len(await versions(db_session)) == 1
    assert await scores(db_session) == []
    assert await upsert(db_session, off_record(category=None)) == UpsertOutcome.UNCHANGED


# ---------------------------------------------------------------- updates


async def test_changed_nutrition_adds_a_version_and_rescores(db_session: AsyncSession) -> None:
    await upsert(db_session, off_record(sugars=5))

    assert await upsert(db_session, off_record(sugars=40, modified=T0 + 1)) == UpsertOutcome.UPDATED

    first, second = await versions(db_session)
    assert (first.version, second.version, second.sugars_g) == (1, 2, Decimal(40))
    old, new = await scores(db_session)
    assert (old.nutrition_facts_id, new.nutrition_facts_id) == (first.id, second.id)
    assert new.total is not None
    assert old.total is not None
    assert new.total > old.total


async def test_equal_values_with_another_scale_are_unchanged(db_session: AsyncSession) -> None:
    await upsert(db_session, off_record(sugars=5))
    assert await upsert(db_session, off_record(sugars=5.0)) == UpsertOutcome.UNCHANGED


async def test_category_change_rescores_the_same_values(db_session: AsyncSession) -> None:
    await upsert(db_session, off_record(category="general"))

    assert await upsert(db_session, off_record(category="cheese")) == UpsertOutcome.UPDATED

    assert (await stored(db_session)).category == Category.CHEESE
    first, second = await versions(db_session)
    assert second.sugars_g == first.sugars_g
    _, new = await scores(db_session)
    assert new.nutrition_facts_id == second.id


async def test_category_change_without_nutrition_keeps_and_rescores_stored_values(
    db_session: AsyncSession,
) -> None:
    await upsert(db_session, off_record(category="general"))

    record = off_record(category="cheese", nutrition=False)
    assert await upsert(db_session, record) == UpsertOutcome.UPDATED

    first, second = await versions(db_session)
    assert (second.version, second.sugars_g, second.basis) == (2, first.sugars_g, first.basis)
    _, new = await scores(db_session)
    assert new.nutrition_facts_id == second.id


async def test_record_without_nutrition_keeps_stored_values(db_session: AsyncSession) -> None:
    await upsert(db_session, off_record())

    outcome = await upsert(db_session, off_record(nutrition=False))

    # The quality flag and issues change (no nutrition data), the declared values stay.
    assert outcome == UpsertOutcome.UPDATED
    assert len(await versions(db_session)) == 1
    assert len(await scores(db_session)) == 1


async def test_category_change_without_any_nutrition_rescores(db_session: AsyncSession) -> None:
    await upsert(db_session, off_record(category="water", nutrition=False))
    [water] = await scores(db_session)
    assert water.grade == Grade.A

    await upsert(db_session, off_record(category="general", nutrition=False))

    assert await versions(db_session) == []
    _, new = await scores(db_session)
    assert (new.grade, new.breakdown.keys()) == (None, {"insufficient_data"})


async def test_only_off_grade_changed_updates_the_current_score(db_session: AsyncSession) -> None:
    await upsert(db_session, off_record(grade="c"))

    assert await upsert(db_session, off_record(grade="d")) == UpsertOutcome.UPDATED

    [score] = await scores(db_session)
    assert score.off_grade == Grade.D


async def test_off_estimated_flag_is_stored_and_updated(db_session: AsyncSession) -> None:
    def record(estimated: int) -> NormalizedProduct:
        ns = {"2023": {"category_available": 1, "data": {}, "estimated": estimated}}
        return off_record(nutriscore=ns)

    await upsert(db_session, record(0))
    [score] = await scores(db_session)
    assert (score.off_grade, score.off_grade_estimated) == (Grade.C, False)

    assert await upsert(db_session, record(1)) == UpsertOutcome.UPDATED

    [score] = await scores(db_session)
    await db_session.refresh(score)
    assert score.off_grade_estimated is True


async def test_product_fields_are_updated_status_is_kept(db_session: AsyncSession) -> None:
    await upsert(db_session, off_record())
    product = await stored(db_session)
    product.status = ProductStatus.HIDDEN
    await db_session.flush()

    record = off_record(product_name="Biscuits au chocolat", brands="Saida", modified=T0 + 60)
    assert await upsert(db_session, record) == UpsertOutcome.UPDATED

    product = await stored(db_session)
    assert (product.name, product.brand, product.status) == (
        "Biscuits au chocolat",
        "Saida",
        ProductStatus.HIDDEN,
    )
    assert product.source_modified_at == datetime.fromtimestamp(T0 + 60, tz=UTC)
    assert len(await versions(db_session)) == 1
    assert len(await scores(db_session)) == 1


async def test_missing_score_for_the_current_engine_is_added(db_session: AsyncSession) -> None:
    product = await ProductFactory.create(db_session, ean=EAN, category=Category.GENERAL)
    facts = await NutritionFactsFactory.create(db_session, product_id=product.id)
    await ScoreFactory.create(
        db_session, product_id=product.id, nutrition_facts_id=facts.id, engine_version="old"
    )

    # The factory's values exactly (all zeros, total fat undeclared): no new version.
    zeros = ("energy-kj", "sugars", "saturated-fat", "salt", "fiber", "proteins")
    nutriments = {f"{name}_100g": 0 for name in zeros}
    nutriments["fruits-vegetables-legumes-estimate-from-ingredients_100g"] = 0
    await upsert(db_session, off_record(product_name=product.name, nutriments=nutriments))

    assert [v.id for v in await versions(db_session)] == [facts.id]
    current = [s for s in await scores(db_session) if s.engine_version == ENGINE_VERSION]
    assert [s.nutrition_facts_id for s in current] == [facts.id]


# ---------------------------------------------------------------- left alone


async def test_older_record_is_ignored(db_session: AsyncSession) -> None:
    await upsert(db_session, off_record(sugars=5, modified=T0))

    outcome = await upsert(db_session, off_record(sugars=40, modified=T0 - 1))

    assert outcome == UpsertOutcome.STALE
    [facts] = await versions(db_session)
    assert facts.sugars_g == Decimal(5)


@pytest.mark.parametrize("modified", [None, T0])
async def test_record_without_time_or_same_time_is_compared(
    db_session: AsyncSession, modified: int | None
) -> None:
    await upsert(db_session, off_record(sugars=5, modified=T0))
    assert await upsert(db_session, off_record(sugars=6, modified=modified)) == (
        UpsertOutcome.UPDATED
    )


@pytest.mark.parametrize("source", [DataSource.CONTRIBUTION, DataSource.MANUAL])
async def test_products_from_other_sources_are_not_overwritten(
    db_session: AsyncSession, source: DataSource
) -> None:
    await ProductFactory.create(db_session, ean=EAN, name="Ours", source=source)

    result = await ProductUpserter(db_session).upsert(off_record())

    assert (result.outcome, result.changed) == (UpsertOutcome.NOT_FROM_OFF, False)
    assert (await stored(db_session)).name == "Ours"
    assert await versions(db_session) == []


async def test_score_stored_concurrently_is_kept(
    db_session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    await upsert(db_session, off_record())

    async def no_score(*_: Any, **__: Any) -> None:
        return None  # as if another writer had not committed its score yet

    monkeypatch.setattr(ScoreRepository, "latest", no_score)
    outcome = await upsert(db_session, off_record())

    assert outcome == UpsertOutcome.UNCHANGED
    assert len(await scores(db_session)) == 1
