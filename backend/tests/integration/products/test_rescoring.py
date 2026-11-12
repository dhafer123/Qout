"""Rescorer against real Postgres: only outdated scores are recomputed."""

from collections.abc import AsyncIterator, Sequence
from datetime import datetime
from typing import Any

import pytest
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.modules.products import rescoring
from app.modules.products.models import Product, Score
from app.modules.products.rescoring import Rescorer, RescoreStats
from app.modules.scoring import ENGINE_VERSION, Category, Grade
from tests.factories import NutritionFactsFactory, ProductFactory, ScoreFactory

Sessions = async_sessionmaker[AsyncSession]
OLD = "nutriscore-2023.1"


@pytest.fixture
async def sessions(db_engine: AsyncEngine) -> AsyncIterator[Sessions]:
    """Committing sessions on empty product tables (the rescorer commits)."""

    async def clear() -> None:
        async with db_engine.begin() as connection:
            await connection.execute(text("TRUNCATE products CASCADE"))

    await clear()
    yield async_sessionmaker(db_engine, expire_on_commit=False)
    await clear()


async def general_product(
    session: AsyncSession, *, scored: bool = True, **score: Any
) -> tuple[Product, Score | None]:
    """A general food with nutrition v1 and (unless `scored=False`) a score of v1."""
    product = await ProductFactory.create(session, category=Category.GENERAL)
    facts = await NutritionFactsFactory.create(session, product_id=product.id)
    row = None
    if scored:
        row = await ScoreFactory.create(
            session, product_id=product.id, nutrition_facts_id=facts.id, **score
        )
    return product, row


async def scores_of(sessions: Sessions, product: Product) -> Sequence[Score]:
    async with sessions() as session:
        result = await session.scalars(
            select(Score).where(Score.product_id == product.id).order_by(Score.created_at)
        )
        return result.all()


async def rescore(sessions: Sessions, batch_size: int = 100) -> RescoreStats:
    return await Rescorer(sessions, batch_size=batch_size).run()


async def test_outdated_scores_are_recomputed_current_ones_untouched(sessions: Sessions) -> None:
    async with sessions() as session:
        outdated, old = await general_product(
            session, engine_version=OLD, off_grade=Grade.B, off_grade_estimated=True
        )
        current_product, current = await general_product(session)  # current engine
        await session.commit()
    assert old is not None
    assert current is not None
    current_written_at: datetime = current.created_at

    stats = await rescore(sessions)

    assert stats == RescoreStats(checked=1, rescored=1, failed=0)
    previous, new = await scores_of(sessions, outdated)
    assert (previous.id, previous.engine_version) == (old.id, OLD)
    assert (new.engine_version, new.nutrition_facts_id) == (ENGINE_VERSION, old.nutrition_facts_id)
    assert new.grade is not None
    assert (new.off_grade, new.off_grade_estimated) == (Grade.B, True)  # same nutrition
    [untouched] = await scores_of(sessions, current_product)
    assert (untouched.id, untouched.created_at) == (current.id, current_written_at)


async def test_new_nutrition_without_score_is_scored_without_offs_grade(
    sessions: Sessions,
) -> None:
    async with sessions() as session:
        product, _ = await general_product(session, off_grade=Grade.C)  # score of v1
        await NutritionFactsFactory.create(session, product_id=product.id, version=2)
        await session.commit()

    assert (await rescore(sessions)).rescored == 1

    _, new = await scores_of(sessions, product)
    assert (new.off_grade, new.off_grade_estimated) == (None, None)  # graded other values


async def test_products_without_score_or_nutrition(sessions: Sessions) -> None:
    async with sessions() as session:
        never_scored, _ = await general_product(session, scored=False)
        water = await ProductFactory.create(session, category=Category.WATER)
        await ScoreFactory.create(session, product_id=water.id, engine_version=OLD)
        unknown = await ProductFactory.create(session, category=None)
        await NutritionFactsFactory.create(session, product_id=unknown.id)
        await session.commit()

    assert await rescore(sessions) == RescoreStats(checked=2, rescored=2, failed=0)

    [scored] = await scores_of(sessions, never_scored)
    assert scored.engine_version == ENGINE_VERSION
    _, water_now = await scores_of(sessions, water)
    assert (water_now.grade, water_now.nutrition_facts_id) == (Grade.A, None)
    assert await scores_of(sessions, unknown) == []  # unknown category: nothing to score


async def test_second_run_finds_nothing(sessions: Sessions) -> None:
    async with sessions() as session:
        for _ in range(3):
            await general_product(session, engine_version=OLD)
        await session.commit()

    assert (await rescore(sessions, batch_size=2)).rescored == 3
    assert await rescore(sessions) == RescoreStats()


async def test_one_failure_does_not_stop_rescoring(
    sessions: Sessions, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    async with sessions() as session:
        broken, _ = await general_product(session, engine_version=OLD)
        fine, _ = await general_product(session, engine_version=OLD)
        await session.commit()
    original = rescoring.score_product

    def score_or_fail(product: Product, facts: Any) -> Any:
        if product.id == broken.id:
            raise ValueError("impossible nutrition")
        return original(product, facts)

    monkeypatch.setattr(rescoring, "score_product", score_or_fail)

    assert await rescore(sessions, batch_size=1) == RescoreStats(checked=2, rescored=1, failed=1)
    assert len(await scores_of(sessions, fine)) == 2
    assert len(await scores_of(sessions, broken)) == 1
    assert "rescoring failed" in caplog.text
