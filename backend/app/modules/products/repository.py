"""Data access for products, nutrition facts, scores and scan events.

Repositories take an `AsyncSession` and only flush; committing is the caller's decision
(one unit of work per request or job). No FastAPI imports.
"""

import uuid
from collections.abc import Sequence
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.products.models import (
    NutritionFacts,
    Product,
    ScanEvent,
    ScanOutcome,
    Score,
)

_UNIQUE_EAN = "uq_products_ean"
_UNIQUE_VERSION = "uq_nutrition_facts_product_id_version"


class DuplicateEanError(Exception):
    def __init__(self, ean: str) -> None:
        super().__init__(f"a product with EAN {ean} already exists")
        self.ean = ean


class ConcurrentVersionError(Exception):
    """Another writer added a nutrition facts version for the same product first."""


def _violated_constraint(error: IntegrityError) -> str | None:
    cause = getattr(error.orig, "__cause__", None)
    name = getattr(cause, "constraint_name", None)
    return name if isinstance(name, str) else None


class ProductRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get(self, product_id: uuid.UUID) -> Product | None:
        return await self._session.get(Product, product_id)

    async def get_by_ean(self, ean: str) -> Product | None:
        result = await self._session.scalars(select(Product).where(Product.ean == ean))
        return result.one_or_none()

    async def add(self, product: Product) -> Product:
        """Insert a product; raises DuplicateEanError if the EAN is taken."""
        try:
            async with self._session.begin_nested():
                self._session.add(product)
        except IntegrityError as error:
            if _violated_constraint(error) == _UNIQUE_EAN:
                raise DuplicateEanError(product.ean) from error
            raise
        return product

    async def update(self, product: Product, **changes: Any) -> Product:
        """Set the given fields (unknown names are an error) and flush."""
        unknown = set(changes) - set(Product.__mapper__.attrs.keys())
        if unknown:
            msg = f"unknown product fields: {sorted(unknown)}"
            raise TypeError(msg)
        for name, value in changes.items():
            setattr(product, name, value)
        try:
            async with self._session.begin_nested():
                await self._session.flush()
        except IntegrityError as error:
            if _violated_constraint(error) == _UNIQUE_EAN:
                raise DuplicateEanError(product.ean) from error
            raise
        return product


class NutritionFactsRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def add_version(self, facts: NutritionFacts) -> NutritionFacts:
        """Store `facts` as the product's next version (1, 2, 3...).

        Versions are never edited: a correction is a new version. Raises
        ConcurrentVersionError if another writer took the same version number.
        """
        current = await self._session.scalar(
            select(func.max(NutritionFacts.version)).where(
                NutritionFacts.product_id == facts.product_id
            )
        )
        facts.version = (current or 0) + 1
        try:
            async with self._session.begin_nested():
                self._session.add(facts)
        except IntegrityError as error:
            if _violated_constraint(error) == _UNIQUE_VERSION:
                raise ConcurrentVersionError(str(facts.product_id)) from error
            raise
        return facts

    async def latest(self, product_id: uuid.UUID) -> NutritionFacts | None:
        result = await self._session.scalars(
            select(NutritionFacts)
            .where(NutritionFacts.product_id == product_id)
            .order_by(NutritionFacts.version.desc())
            .limit(1)
        )
        return result.one_or_none()

    async def versions(self, product_id: uuid.UUID) -> Sequence[NutritionFacts]:
        result = await self._session.scalars(
            select(NutritionFacts)
            .where(NutritionFacts.product_id == product_id)
            .order_by(NutritionFacts.version)
        )
        return result.all()


class ScoreRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def add(self, score: Score) -> Score:
        self._session.add(score)
        await self._session.flush()
        return score

    async def latest(
        self, product_id: uuid.UUID, *, engine_version: str | None = None
    ) -> Score | None:
        """The most recently computed score, optionally for one engine version only."""
        query = select(Score).where(Score.product_id == product_id)
        if engine_version is not None:
            query = query.where(Score.engine_version == engine_version)
        result = await self._session.scalars(
            query.order_by(Score.created_at.desc(), Score.id.desc()).limit(1)
        )
        return result.one_or_none()


class ScanEventRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def record(
        self, ean: str, outcome: ScanOutcome, product_id: uuid.UUID | None = None
    ) -> ScanEvent:
        event = ScanEvent(ean=ean, outcome=outcome, product_id=product_id)
        self._session.add(event)
        await self._session.flush()
        return event
