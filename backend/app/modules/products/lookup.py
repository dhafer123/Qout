"""Barcode lookup: cache → our database → Open Food Facts → not found.

A product found on OFF is normalised, stored with its nutrition facts and score
(`ProductUpserter`, shared with the bulk import), and committed before it is returned.
A stored product without a score for the current engine version (or for its latest
nutrition) is scored on the way out. No FastAPI imports: the router maps the errors below
to HTTP statuses.
"""

import logging
from datetime import datetime
from typing import Any, Protocol

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.ingestion.off_client import OffError
from app.modules.ingestion.off_normaliser import normalize
from app.modules.products.cache import NOT_FOUND, ProductCache
from app.modules.products.ean import normalize_ean
from app.modules.products.models import (
    NutritionFacts,
    Product,
    ProductStatus,
    Score,
)
from app.modules.products.repository import (
    NutritionFactsRepository,
    ProductRepository,
    ScoreRepository,
)
from app.modules.products.schemas import (
    AdditiveDetail,
    NutritionDetail,
    ProductDetail,
    ScoreDetail,
)
from app.modules.products.scoring import score_row
from app.modules.products.upsert import ProductUpserter, score_product
from app.modules.scoring import ENGINE_VERSION, OverexposureRisk, additive

logger = logging.getLogger(__name__)


class ProductNotFoundError(Exception):
    def __init__(self, ean: str) -> None:
        super().__init__(f"no product with barcode {ean}")
        self.ean = ean


class ProductSourceUnavailableError(Exception):
    """The product is not stored and Open Food Facts could not be asked."""

    def __init__(self, ean: str) -> None:
        super().__init__(f"product {ean} is not stored and Open Food Facts is unavailable")
        self.ean = ean


class ProductSource(Protocol):
    """Where unknown barcodes are looked up (`OffClient`)."""

    async def get_product(self, ean: str) -> dict[str, Any] | None: ...


class ProductLookup:
    def __init__(self, session: AsyncSession, off: ProductSource, cache: ProductCache) -> None:
        self._session = session
        self._off = off
        self._cache = cache
        self._products = ProductRepository(session)
        self._nutrition = NutritionFactsRepository(session)
        self._scores = ScoreRepository(session)

    async def lookup(self, code: str) -> ProductDetail:
        """Raises InvalidEanError, ProductNotFoundError, ProductSourceUnavailableError."""
        ean = normalize_ean(code)
        cached = await self._cache.get(ean)
        if cached is NOT_FOUND:
            raise ProductNotFoundError(ean)
        if cached is not None:
            return cached

        product = await self._products.get_by_ean(ean)
        if product is None:
            product = await self._import_from_off(ean)
        if product.status == ProductStatus.HIDDEN:
            raise ProductNotFoundError(ean)
        detail = await self._detail(product)
        await self._cache.set(detail)
        return detail

    # ------------------------------------------------------------ Open Food Facts

    async def _import_from_off(self, ean: str) -> Product:
        try:
            off = await self._off.get_product(ean)
        except OffError as error:
            logger.warning("OFF lookup failed", extra={"ean": ean, "error": str(error)})
            raise ProductSourceUnavailableError(ean) from error
        if off is None:
            await self._cache.set_not_found(ean)
            raise ProductNotFoundError(ean)

        normalized = normalize(ean, off)
        result = await ProductUpserter(self._session).upsert(normalized)
        await self._session.commit()
        if result.changed:
            logger.info(
                "product imported from OFF",
                extra={
                    "ean": ean,
                    "quality_flag": result.product.quality_flag,
                    "issues": normalized.issues,
                },
            )
        return result.product

    # ------------------------------------------------------------ stored products

    async def _detail(self, product: Product) -> ProductDetail:
        facts = await self._nutrition.latest(product.id)
        stored = await self._current_score(product, facts)
        return product_detail(product, facts, stored)

    async def _current_score(self, product: Product, facts: NutritionFacts | None) -> Score | None:
        """The score of the latest nutrition with the current engine, computed if missing."""
        if product.category is None:
            return None  # unknown category: nothing to score with (older scores don't apply)
        facts_id = None if facts is None else facts.id
        latest = await self._scores.latest(product.id, engine_version=ENGINE_VERSION)
        if latest is not None and latest.nutrition_facts_id == facts_id:
            return latest
        result = score_product(product, facts)
        if result is None:  # pragma: no cover - category checked above
            return None
        previous = await self._scores.latest(product.id)
        off_grade = (
            previous.off_grade
            if previous is not None and previous.nutrition_facts_id == facts_id
            else None
        )
        row = score_row(
            result, product_id=product.id, nutrition_facts_id=facts_id, off_grade=off_grade
        )
        try:
            async with self._session.begin_nested():
                await self._scores.add(row)
        except IntegrityError:
            # A concurrent lookup stored the same (nutrition, engine version) score.
            return await self._scores.latest(product.id, engine_version=ENGINE_VERSION)
        await self._session.commit()
        return row


# ---------------------------------------------------------------- response mapping


def product_detail(
    product: Product, facts: NutritionFacts | None, stored: Score | None
) -> ProductDetail:
    changes: list[datetime] = [product.updated_at]
    changes += [] if facts is None else [facts.created_at]
    changes += [] if stored is None else [stored.created_at]
    return ProductDetail(
        ean=product.ean,
        name=product.name,
        brand=product.brand,
        image_url=product.image_url,
        category=product.category,
        source=product.source,
        status=product.status,
        quality_flag=product.quality_flag,
        nova_group=product.nova_group,
        additives=[_additive_detail(code) for code in product.additives],
        nutrition=None if facts is None else _nutrition_detail(facts),
        score=None if stored is None else _score_detail(stored),
        updated_at=max(changes),
    )


def _additive_detail(code: str) -> AdditiveDetail:
    known = additive(code)
    if known is None:
        return AdditiveDetail(code=code, name=None, overexposure_risk=OverexposureRisk.UNKNOWN)
    return AdditiveDetail(code=known.code, name=known.name, overexposure_risk=known.risk)


def _nutrition_detail(facts: NutritionFacts) -> NutritionDetail:
    return NutritionDetail(
        version=facts.version,
        basis=facts.basis,
        source=facts.source,
        energy_kj=facts.energy_kj,
        sugars_g=facts.sugars_g,
        saturated_fat_g=facts.saturated_fat_g,
        total_fat_g=facts.total_fat_g,
        salt_g=facts.salt_g,
        fibre_g=facts.fibre_g,
        protein_g=facts.protein_g,
        fvl_percent=facts.fvl_percent,
        non_nutritive_sweeteners=facts.non_nutritive_sweeteners,
    )


def _score_detail(stored: Score) -> ScoreDetail:
    return ScoreDetail(
        engine_version=stored.engine_version,
        grade=stored.grade,
        total=stored.total,
        breakdown=stored.breakdown,
        computed_at=stored.created_at,
    )
