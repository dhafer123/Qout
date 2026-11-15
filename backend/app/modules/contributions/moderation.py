"""Moderation: approve or reject pending contributions; list contributions and reports.

Approving a contribution makes its product verified, whether the product is new or came
from Open Food Facts:

- the product takes the contributed name and brand (kept when not given), category,
  source `contribution` (so OFF imports leave it alone from now on) and status `verified`;
- the contributed nutrition becomes a new nutrition version, scored with the engine;
- the front photo is copied from the private bucket into the public one and becomes the
  product photo (the previous one is deleted);
- the cached lookup response (or "not found") is dropped.

Rejecting only records the decision: the product, if any, is unchanged.
"""

import logging
import uuid
from collections.abc import Sequence
from datetime import UTC, datetime
from pathlib import PurePosixPath

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.storage import Storage, StorageError
from app.modules.contributions.models import (
    Contribution,
    ContributionStatus,
    ErrorReport,
    ReportStatus,
)
from app.modules.contributions.nutrition import facts_values
from app.modules.contributions.service import ContributionNotFoundError
from app.modules.products.cache import ProductCache
from app.modules.products.images import CACHE_CONTROL
from app.modules.products.models import (
    DataSource,
    NutritionFacts,
    Product,
    ProductStatus,
)
from app.modules.products.repository import NutritionFactsRepository, ProductRepository
from app.modules.products.rescoring import ensure_current_score

logger = logging.getLogger(__name__)

_CONTENT_TYPES = {".jpg": "image/jpeg", ".png": "image/png"}


class ContributionNotPendingError(Exception):
    def __init__(self, contribution: Contribution) -> None:
        super().__init__(f"contribution {contribution.id} is already {contribution.status}")


def product_photo_key(contribution: Contribution, front_key: str) -> str:
    """Key of an approved front photo in the public bucket (unique per contribution, so
    it can be cached forever)."""
    extension = PurePosixPath(front_key).suffix
    return f"products/{contribution.ean}/contribution-{contribution.id.hex}{extension}"


class ModerationService:
    def __init__(self, session: AsyncSession, storage: Storage, cache: ProductCache) -> None:
        self._session = session
        self._storage = storage
        self._cache = cache
        self._products = ProductRepository(session)
        self._nutrition = NutritionFactsRepository(session)

    # ------------------------------------------------------------ queues

    async def contributions(
        self, status: ContributionStatus, *, limit: int
    ) -> Sequence[Contribution]:
        """Oldest first."""
        query = (
            select(Contribution)
            .where(Contribution.status == status)
            .order_by(Contribution.created_at, Contribution.id)
            .limit(limit)
        )
        return (await self._session.scalars(query)).all()

    async def reports(self, status: ReportStatus, *, limit: int) -> Sequence[ErrorReport]:
        """Oldest first."""
        query = (
            select(ErrorReport)
            .where(ErrorReport.status == status)
            .order_by(ErrorReport.created_at, ErrorReport.id)
            .limit(limit)
        )
        return (await self._session.scalars(query)).all()

    # ------------------------------------------------------------ decisions

    async def approve(
        self, contribution_id: uuid.UUID, reviewer_id: uuid.UUID, note: str | None
    ) -> Contribution:
        """Raises ContributionNotFoundError, ContributionNotPendingError, StorageError."""
        contribution = await self._pending(contribution_id)
        product = await self._products.get_by_ean(contribution.ean)
        old_photo = None if product is None else product.image_key
        new_photo = await self._copy_front_photo(contribution)
        try:
            product = await self._save_product(contribution, product, new_photo)
            facts = await self._nutrition.add_version(
                NutritionFacts(
                    product_id=product.id,
                    basis=contribution.basis,
                    source=DataSource.CONTRIBUTION,
                    **facts_values(contribution.nutrition),
                )
            )
            await ensure_current_score(self._session, product, facts)
            self._decide(contribution, ContributionStatus.APPROVED, reviewer_id, note)
            contribution.product_id = product.id
            await self._session.commit()
        except Exception:
            await self._session.rollback()
            if new_photo is not None:
                await self._delete_photo(new_photo)
            raise
        if old_photo is not None and new_photo is not None and old_photo != new_photo:
            await self._delete_photo(old_photo)
        await self._cache.invalidate(contribution.ean)
        logger.info(
            "contribution approved",
            extra={"contribution_id": str(contribution.id), "ean": contribution.ean},
        )
        return contribution

    async def reject(
        self, contribution_id: uuid.UUID, reviewer_id: uuid.UUID, note: str | None
    ) -> Contribution:
        """Raises ContributionNotFoundError, ContributionNotPendingError."""
        contribution = await self._pending(contribution_id)
        self._decide(contribution, ContributionStatus.REJECTED, reviewer_id, note)
        await self._session.commit()
        return contribution

    # ------------------------------------------------------------ helpers

    async def _pending(self, contribution_id: uuid.UUID) -> Contribution:
        """The contribution, locked until commit (two moderators can't both decide)."""
        query = select(Contribution).where(Contribution.id == contribution_id).with_for_update()
        contribution = await self._session.scalar(query)
        if contribution is None:
            raise ContributionNotFoundError(contribution_id)
        if contribution.status != ContributionStatus.PENDING:
            error = ContributionNotPendingError(contribution)
            await self._session.rollback()  # release the row lock
            raise error
        return contribution

    def _decide(
        self,
        contribution: Contribution,
        status: ContributionStatus,
        reviewer_id: uuid.UUID,
        note: str | None,
    ) -> None:
        contribution.status = status
        contribution.reviewed_by = reviewer_id
        contribution.reviewed_at = datetime.now(UTC)
        contribution.review_note = note

    async def _copy_front_photo(self, contribution: Contribution) -> str | None:
        """The product photo's key in the public bucket, or None when the uploaded front
        photo is gone (the product keeps its current photo)."""
        front = contribution.photos["front"]  # required on submission
        if await self._storage.uploads.head(front) is None:
            logger.warning(
                "contribution front photo missing", extra={"contribution_id": str(contribution.id)}
            )
            return None
        key = product_photo_key(contribution, front)
        await self._storage.public.copy_from(
            self._storage.uploads,
            front,
            key,
            # Submission only accepts .jpg and .png keys (`photo_key_problem`).
            content_type=_CONTENT_TYPES[PurePosixPath(front).suffix],
            cache_control=CACHE_CONTROL,
        )
        return key

    async def _save_product(
        self, contribution: Contribution, product: Product | None, photo: str | None
    ) -> Product:
        photo_fields = (
            {}
            if photo is None
            else {"image_key": photo, "source_image_url": None, "image_copied_from": None}
        )
        if product is None:
            return await self._products.add(
                Product(
                    ean=contribution.ean,
                    name=contribution.name,
                    brand=contribution.brand,
                    category=contribution.category,
                    source=DataSource.CONTRIBUTION,
                    status=ProductStatus.VERIFIED,
                    **photo_fields,
                )
            )
        return await self._products.update(
            product,
            name=contribution.name or product.name,
            brand=contribution.brand or product.brand,
            category=contribution.category,
            source=DataSource.CONTRIBUTION,
            status=ProductStatus.VERIFIED,
            # Computed from OFF's data, which no longer describes this product.
            quality_flag=None,
            **photo_fields,
        )

    async def _delete_photo(self, key: str) -> None:
        try:
            await self._storage.public.delete(key)
        except StorageError:
            logger.warning("product photo not deleted", extra={"key": key}, exc_info=True)
