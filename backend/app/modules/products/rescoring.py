"""Keeping scores current: a product's score is for its latest nutrition facts and the
current engine version (`ENGINE_VERSION`).

- `ensure_current_score`: one product, used by the lookup (on read) and the rescorer.
- `Rescorer`: every outdated product in batches, e.g. after a new engine version is
  deployed (the worker queues it on startup). Up-to-date scores are never touched.

Old scores stay in the table (history, validation). Open Food Facts' grade belongs to the
nutrition it was computed from, so it is carried over to a new score of the same nutrition.
"""

import logging
import uuid
from dataclasses import dataclass

from sqlalchemy import exists, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.modules.products.models import NutritionFacts, Product, Score
from app.modules.products.repository import (
    NutritionFactsRepository,
    ProductRepository,
    ScoreRepository,
)
from app.modules.products.scoring import score_row
from app.modules.products.upsert import score_product
from app.modules.scoring import ENGINE_VERSION

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class CurrentScore:
    score: Score | None
    """None when the product's category is unknown (nothing to score with)."""
    created: bool
    """Computed now (and flushed): the caller commits."""


async def ensure_current_score(
    session: AsyncSession, product: Product, facts: NutritionFacts | None
) -> CurrentScore:
    """The score of `facts` (the latest nutrition) with the current engine, computed if
    missing. A concurrent writer storing the same score first is not an error."""
    if product.category is None:
        return CurrentScore(None, created=False)  # older scores don't apply any more
    scores = ScoreRepository(session)
    facts_id = None if facts is None else facts.id
    latest = await scores.latest(product.id, engine_version=ENGINE_VERSION)
    if latest is not None and latest.nutrition_facts_id == facts_id:
        return CurrentScore(latest, created=False)
    result = score_product(product, facts)
    if result is None:  # pragma: no cover - category checked above
        return CurrentScore(None, created=False)
    previous = await scores.latest(product.id)
    same_facts = previous is not None and previous.nutrition_facts_id == facts_id
    row = score_row(
        result,
        product_id=product.id,
        nutrition_facts_id=facts_id,
        off_grade=previous.off_grade if previous is not None and same_facts else None,
        off_grade_estimated=(
            previous.off_grade_estimated if previous is not None and same_facts else None
        ),
    )
    try:
        async with session.begin_nested():
            await scores.add(row)
    except IntegrityError:
        # Stored concurrently for the same (nutrition, engine version).
        return CurrentScore(
            await scores.latest(product.id, engine_version=ENGINE_VERSION), created=False
        )
    return CurrentScore(row, created=True)


@dataclass
class RescoreStats:
    checked: int = 0
    """Outdated products found."""
    rescored: int = 0
    failed: int = 0


class Rescorer:
    def __init__(self, sessions: async_sessionmaker[AsyncSession], *, batch_size: int) -> None:
        self._sessions = sessions
        self._batch_size = batch_size

    async def run(self) -> RescoreStats:
        """Score every product whose latest nutrition has no current-engine score."""
        stats = RescoreStats()
        after: uuid.UUID | None = None
        while batch := await self._outdated(after):
            await self._rescore(batch, stats)
            after = batch[-1]
            logger.info(
                "rescoring progress",
                extra={"engine_version": ENGINE_VERSION, **stats.__dict__},
            )
        logger.info(
            "rescoring finished", extra={"engine_version": ENGINE_VERSION, **stats.__dict__}
        )
        return stats

    async def _outdated(self, after: uuid.UUID | None) -> list[uuid.UUID]:
        """Next batch of outdated product ids (keyset by id, so failures aren't retried
        forever within a run)."""
        latest_facts = (
            select(NutritionFacts.id)
            .where(NutritionFacts.product_id == Product.id)
            .order_by(NutritionFacts.version.desc())
            .limit(1)
            .scalar_subquery()
        )
        # Latest nutrition per product first: a subquery nested inside EXISTS would not be
        # correlated with `products`.
        scorable = select(Product.id.label("id"), latest_facts.label("facts_id")).where(
            Product.category.is_not(None)
        )
        if after is not None:
            scorable = scorable.where(Product.id > after)
        latest = scorable.subquery()
        current = exists().where(
            Score.product_id == latest.c.id,
            Score.engine_version == ENGINE_VERSION,
            Score.nutrition_facts_id.is_not_distinct_from(latest.c.facts_id),
        )
        query = select(latest.c.id).where(~current).order_by(latest.c.id)
        async with self._sessions() as session:
            result = await session.scalars(query.limit(self._batch_size))
            return list(result.all())

    async def _rescore(self, product_ids: list[uuid.UUID], stats: RescoreStats) -> None:
        async with self._sessions() as session:
            products = ProductRepository(session)
            nutrition = NutritionFactsRepository(session)
            for product_id in product_ids:
                stats.checked += 1
                product = await products.get(product_id)
                if product is None:  # pragma: no cover - deleted in between
                    continue
                try:
                    async with session.begin_nested():  # a failure undoes this product only
                        facts = await nutrition.latest(product.id)
                        current = await ensure_current_score(session, product, facts)
                except Exception:
                    stats.failed += 1
                    logger.exception("rescoring failed", extra={"ean": product.ean})
                    continue
                stats.rescored += current.created
            await session.commit()
