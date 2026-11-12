"""Repositories against real Postgres."""

import uuid
from decimal import Decimal

import pytest
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.products.models import (
    DataSource,
    NutritionBasis,
    NutritionFacts,
    Product,
    ProductStatus,
    ScanOutcome,
    Score,
)
from app.modules.products.repository import (
    ConcurrentVersionError,
    DuplicateEanError,
    NutritionFactsRepository,
    ProductRepository,
    ScanEventRepository,
    ScoreRepository,
)
from app.modules.products.scoring import nutrition_input, score_row
from app.modules.scoring import ENGINE_VERSION, Category, Grade, score
from tests.factories import NutritionFactsFactory, ProductFactory, ScoreFactory

# ---------------------------------------------------------------- products


async def test_add_and_get_product(db_session: AsyncSession) -> None:
    repo = ProductRepository(db_session)
    product = await repo.add(
        Product(
            ean="6194001234567",
            name="Harissa",
            brand="Le Phare du Cap Bon",
            category=Category.GENERAL,
            source=DataSource.OPEN_FOOD_FACTS,
            nova_group=3,
            additives=["E330", "E160a(i)"],
        )
    )
    db_session.expunge_all()

    by_id = await repo.get(product.id)
    by_ean = await repo.get_by_ean("6194001234567")
    assert by_id is not None
    assert by_ean is not None
    assert by_id.id == by_ean.id
    assert (by_id.name, by_id.category, by_id.status) == (
        "Harissa",
        Category.GENERAL,
        ProductStatus.UNVERIFIED,
    )
    assert by_id.additives == ["E330", "E160a(i)"]


async def test_missing_product_is_none(db_session: AsyncSession) -> None:
    repo = ProductRepository(db_session)
    assert await repo.get_by_ean("0000000000000") is None
    assert await repo.get(uuid.uuid4()) is None


async def test_duplicate_ean_raises_and_keeps_the_session_usable(
    db_session: AsyncSession,
) -> None:
    repo = ProductRepository(db_session)
    await ProductFactory.create(db_session, ean="6190000000002")

    with pytest.raises(DuplicateEanError) as excinfo:
        await repo.add(Product(ean="6190000000002", source=DataSource.MANUAL))
    assert excinfo.value.ean == "6190000000002"

    # The savepoint was rolled back: the session still works.
    other = await repo.add(Product(ean="6190000000003", source=DataSource.MANUAL))
    assert await repo.get_by_ean(other.ean) is not None


async def test_other_integrity_errors_are_not_hidden(db_session: AsyncSession) -> None:
    repo = ProductRepository(db_session)
    with pytest.raises(IntegrityError):
        await repo.add(Product(ean="123", source=DataSource.MANUAL))


async def test_update_product(db_session: AsyncSession) -> None:
    repo = ProductRepository(db_session)
    product = await ProductFactory.create(db_session)
    created = product.updated_at

    await repo.update(product, name="Renamed", status=ProductStatus.VERIFIED, nova_group=1)
    db_session.expunge_all()

    stored = await repo.get(product.id)
    assert stored is not None
    assert (stored.name, stored.status, stored.nova_group) == ("Renamed", "verified", 1)
    assert stored.updated_at > created


async def test_update_to_a_taken_ean_raises(db_session: AsyncSession) -> None:
    repo = ProductRepository(db_session)
    await ProductFactory.create(db_session, ean="6190000000004")
    product = await ProductFactory.create(db_session)
    with pytest.raises(DuplicateEanError):
        await repo.update(product, ean="6190000000004")


async def test_update_with_invalid_value_raises(db_session: AsyncSession) -> None:
    repo = ProductRepository(db_session)
    product = await ProductFactory.create(db_session)
    with pytest.raises(IntegrityError):
        await repo.update(product, nova_group=7)


async def test_update_rejects_unknown_fields(db_session: AsyncSession) -> None:
    repo = ProductRepository(db_session)
    product = await ProductFactory.create(db_session)
    with pytest.raises(TypeError, match="unknown product fields"):
        await repo.update(product, colour="red")


# ---------------------------------------------------------------- nutrition facts


def facts_for(product: Product, **amounts: str) -> NutritionFacts:
    return NutritionFacts(
        product_id=product.id,
        basis=NutritionBasis.PER_100G,
        source=DataSource.OPEN_FOOD_FACTS,
        **{name: Decimal(value) for name, value in amounts.items()},
    )


async def test_versions_count_up(db_session: AsyncSession) -> None:
    repo = NutritionFactsRepository(db_session)
    product = await ProductFactory.create(db_session)

    first = await repo.add_version(facts_for(product, sugars_g="10"))
    second = await repo.add_version(facts_for(product, sugars_g="9.5"))
    third = await repo.add_version(facts_for(product, sugars_g="9"))

    assert (first.version, second.version, third.version) == (1, 2, 3)
    latest = await repo.latest(product.id)
    assert latest is not None
    assert (latest.version, latest.sugars_g) == (3, Decimal(9))
    assert [f.version for f in await repo.versions(product.id)] == [1, 2, 3]


async def test_versions_are_per_product(db_session: AsyncSession) -> None:
    repo = NutritionFactsRepository(db_session)
    a, b = await ProductFactory.create(db_session), await ProductFactory.create(db_session)
    await repo.add_version(facts_for(a))
    await repo.add_version(facts_for(a))
    assert (await repo.add_version(facts_for(b))).version == 1


async def test_no_facts_is_none(db_session: AsyncSession) -> None:
    product = await ProductFactory.create(db_session)
    repo = NutritionFactsRepository(db_session)
    assert await repo.latest(product.id) is None
    assert await repo.versions(product.id) == []


async def test_concurrent_version_is_reported(
    db_session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Simulate another writer: the version number we computed is already taken."""
    repo = NutritionFactsRepository(db_session)
    product = await ProductFactory.create(db_session)
    await NutritionFactsFactory.create(db_session, product_id=product.id, version=1)

    async def stale_max(*_: object, **__: object) -> int:
        return 0  # what a writer that read before the insert would see

    monkeypatch.setattr(db_session, "scalar", stale_max)
    with pytest.raises(ConcurrentVersionError):
        await repo.add_version(facts_for(product))


async def test_invalid_facts_are_not_hidden(db_session: AsyncSession) -> None:
    repo = NutritionFactsRepository(db_session)
    product = await ProductFactory.create(db_session)
    with pytest.raises(IntegrityError):
        await repo.add_version(facts_for(product, salt_g="-1"))


# ---------------------------------------------------------------- scores


async def test_latest_score_is_the_most_recent(db_session: AsyncSession) -> None:
    repo = ScoreRepository(db_session)
    product = await ProductFactory.create(db_session)
    v1 = await NutritionFactsFactory.create(db_session, product_id=product.id, version=1)
    v2 = await NutritionFactsFactory.create(db_session, product_id=product.id, version=2)

    # All in one transaction: ordering must not rely on the transaction start time.
    await repo.add(
        Score(
            product_id=product.id,
            nutrition_facts_id=v1.id,
            engine_version=ENGINE_VERSION,
            grade=Grade.C,
            total=5,
            breakdown={"grade": "C"},
        )
    )
    newest = await repo.add(
        Score(
            product_id=product.id,
            nutrition_facts_id=v2.id,
            engine_version=ENGINE_VERSION,
            grade=Grade.B,
            total=2,
            breakdown={"grade": "B"},
            off_grade=Grade.B,
        )
    )

    latest = await repo.latest(product.id)
    assert latest is not None
    assert latest.id == newest.id
    assert (latest.grade, latest.total, latest.off_grade) == (Grade.B, 2, Grade.B)


async def test_latest_score_for_an_engine_version(db_session: AsyncSession) -> None:
    repo = ScoreRepository(db_session)
    product = await ProductFactory.create(db_session)
    facts = await NutritionFactsFactory.create(db_session, product_id=product.id)
    current = await ScoreFactory.create(
        db_session, product_id=product.id, nutrition_facts_id=facts.id
    )
    await ScoreFactory.create(
        db_session,
        product_id=product.id,
        nutrition_facts_id=facts.id,
        engine_version="nutriscore-2099.1",
    )

    latest_current = await repo.latest(product.id, engine_version=ENGINE_VERSION)
    assert latest_current is not None
    assert latest_current.id == current.id
    latest_any = await repo.latest(product.id)
    assert latest_any is not None
    assert latest_any.engine_version == "nutriscore-2099.1"
    assert await repo.latest(product.id, engine_version="nutriscore-1999.1") is None


async def test_latest_score_ignores_other_products(db_session: AsyncSession) -> None:
    repo = ScoreRepository(db_session)
    scored, unscored = (
        await ProductFactory.create(db_session),
        await ProductFactory.create(db_session),
    )
    await ScoreFactory.create(db_session, product_id=scored.id)
    assert await repo.latest(unscored.id) is None


async def test_insufficient_data_score(db_session: AsyncSession) -> None:
    repo = ScoreRepository(db_session)
    product = await ProductFactory.create(db_session)
    stored = await repo.add(
        Score(
            product_id=product.id,
            engine_version=ENGINE_VERSION,
            breakdown={"insufficient_data": ["fibre_g"]},
        )
    )
    db_session.expunge_all()
    latest = await repo.latest(product.id)
    assert latest is not None
    assert latest.id == stored.id
    assert (latest.grade, latest.total) == (None, None)
    assert latest.breakdown == {"insufficient_data": ["fibre_g"]}


# ---------------------------------------------------------------- scan events


async def test_record_scans(db_session: AsyncSession) -> None:
    repo = ScanEventRepository(db_session)
    product = await ProductFactory.create(db_session)

    found = await repo.record(product.ean, ScanOutcome.FOUND, product.id)
    unknown = await repo.record("6199999999999", ScanOutcome.NOT_FOUND)

    assert (found.product_id, found.outcome) == (product.id, ScanOutcome.FOUND)
    assert (unknown.product_id, unknown.outcome) == (None, ScanOutcome.NOT_FOUND)
    assert found.created_at is not None


# ---------------------------------------------------------------- end to end


async def test_score_stored_facts_and_store_the_result(db_session: AsyncSession) -> None:
    """Facts saved as NUMERIC, read back, scored, and the score saved and read back."""
    product = await ProductFactory.create(db_session, category=Category.FATS_OILS_NUTS_SEEDS)
    facts = await NutritionFactsRepository(db_session).add_version(
        facts_for(
            product,
            total_fat_g="1",
            saturated_fat_g="0.58",  # ratio exactly 58 %: 9 points
            sugars_g="0",
            salt_g="0",
            fibre_g="0",
            protein_g="0",
            fvl_percent="0",
        )
    )
    db_session.expunge_all()

    stored = await NutritionFactsRepository(db_session).latest(product.id)
    assert stored is not None
    result = score(Category.FATS_OILS_NUTS_SEEDS, nutrition_input(stored))
    repo = ScoreRepository(db_session)
    await repo.add(score_row(result, product_id=product.id, nutrition_facts_id=facts.id))
    db_session.expunge_all()

    latest = await repo.latest(product.id)
    assert latest is not None
    assert latest.breakdown["negative"]["saturated_fat_ratio"] == 9
    # 0.58 g x 37 = 21.46 kJ (0 points) + ratio 9 = N 9; no positive points.
    assert (latest.grade, latest.total) == (Grade.C, 9)
