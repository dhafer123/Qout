"""Fetch again, from the Open Food Facts API, products stored before a field was imported.

T40 added the serving and the allergens. Products stored earlier have them as null ("not
imported yet") and a barcode lookup never asks OFF again for a stored product, so this
backfill (`python -m app.worker run refresh-off`) asks OFF for each of them once and
stores the record with the same upsert as every import. Only products that came from OFF;
contributed products are left alone. Products OFF no longer knows, or that fail, stay null
and are counted; a later run tries them again.
"""

import logging
import uuid
from dataclasses import dataclass
from typing import Any, Protocol

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.modules.ingestion.off_client import OffError
from app.modules.ingestion.off_normaliser import normalize
from app.modules.products.cache import ProductCache
from app.modules.products.models import DataSource, Product
from app.modules.products.upsert import ProductUpserter

logger = logging.getLogger(__name__)


class ProductSource(Protocol):
    """Where products are fetched from (`OffClient`)."""

    async def get_product(self, ean: str) -> dict[str, Any] | None: ...


@dataclass
class RefreshStats:
    checked: int = 0
    updated: int = 0
    """Stored again with what was missing (or anything else that changed)."""
    unchanged: int = 0
    """OFF's record gave nothing new (e.g. older than ours: kept as stored)."""
    missing: int = 0
    """OFF no longer knows the product."""
    failed: int = 0
    """OFF could not be asked, or its record could not be stored."""


class OffRefresher:
    def __init__(
        self,
        sessions: async_sessionmaker[AsyncSession],
        source: ProductSource,
        cache: ProductCache,
        *,
        batch_size: int = 100,
    ) -> None:
        self._sessions = sessions
        self._source = source
        self._cache = cache
        self._batch_size = batch_size

    async def run(self) -> RefreshStats:
        stats = RefreshStats()
        after: uuid.UUID | None = None
        while batch := await self._next_batch(after):
            for product_id, ean in batch:
                await self._refresh(ean, stats)
                after = product_id
        logger.info("OFF refresh done", extra={"stats": stats.__dict__})
        return stats

    async def _next_batch(self, after: uuid.UUID | None) -> list[tuple[uuid.UUID, str]]:
        """Products from OFF whose allergens were never imported, by id (keyset: a
        product that stays null is not picked again in the same run)."""
        query = (
            select(Product.id, Product.ean)
            .where(Product.source == DataSource.OPEN_FOOD_FACTS, Product.allergens.is_(None))
            .order_by(Product.id)
            .limit(self._batch_size)
        )
        if after is not None:
            query = query.where(Product.id > after)
        async with self._sessions() as session:
            return [(row.id, row.ean) for row in await session.execute(query)]

    async def _refresh(self, ean: str, stats: RefreshStats) -> None:
        stats.checked += 1
        try:
            record = await self._source.get_product(ean)
        except OffError as error:
            logger.warning("OFF refresh failed", extra={"ean": ean, "error": str(error)})
            stats.failed += 1
            return
        if record is None:
            stats.missing += 1
            return
        try:
            async with self._sessions() as session:
                result = await ProductUpserter(session).upsert(normalize(ean, record))
                await session.commit()
        except Exception:  # one bad record must not stop the backfill
            logger.exception("OFF refresh could not store the product", extra={"ean": ean})
            stats.failed += 1
            return
        if result.changed:
            await self._cache.invalidate(ean)
            stats.updated += 1
        else:
            stats.unchanged += 1
