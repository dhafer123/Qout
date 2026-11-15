"""The "Report an error" button on the result screen.

Anyone may report (scanning needs no account); the user is recorded when the app sends a
valid token. The app queues reports and may send one twice (retries): the same
`client_id` is stored once and acknowledged again, without counting against the limit.
New reports are limited per client IP.
"""

import uuid
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.modules.auth.rate_limit import RateLimiter
from app.modules.contributions.models import ErrorReport
from app.modules.contributions.schemas import ReportCreate
from app.modules.products.ean import normalize_ean
from app.modules.products.repository import ProductRepository


class ReportedProductNotFoundError(Exception):
    def __init__(self, ean: str) -> None:
        super().__init__(f"no product with barcode {ean}")


class ReportRateLimitedError(Exception):
    def __init__(self, retry_after: int) -> None:
        super().__init__("too many reports; try again later")
        self.retry_after = retry_after


@dataclass(frozen=True)
class Received:
    report: ErrorReport
    created: bool


class ReportService:
    def __init__(self, session: AsyncSession, limiter: RateLimiter, settings: Settings) -> None:
        self._session = session
        self._limiter = limiter
        self._settings = settings

    async def submit(
        self, body: ReportCreate, *, user_id: uuid.UUID | None, client_ip: str
    ) -> Received:
        """Raises InvalidEanError, ReportedProductNotFoundError, ReportRateLimitedError."""
        ean = normalize_ean(body.ean)
        stored = await self._find(body.client_id)
        if stored is not None:
            return Received(stored, created=False)
        product = await ProductRepository(self._session).get_by_ean(ean)
        if product is None:
            raise ReportedProductNotFoundError(ean)
        limit = await self._limiter.hit(
            f"report:ip:{client_ip}",
            limit=self._settings.report_max_per_ip,
            window=self._settings.report_window_seconds,
        )
        if not limit.allowed:
            raise ReportRateLimitedError(limit.retry_after)

        report = ErrorReport(
            client_id=body.client_id,
            ean=ean,
            product_id=product.id,
            user_id=user_id,
            reasons=[reason.value for reason in body.reasons],
            comment=body.comment,
            product_updated_at=body.product_updated_at,
            reported_at=body.created_at,
        )
        try:
            async with self._session.begin_nested():
                self._session.add(report)
        except IntegrityError:
            stored = await self._find(body.client_id)
            if stored is None:  # pragma: no cover - deleted in between
                raise
            return Received(stored, created=False)
        await self._session.commit()
        await self._session.refresh(report)
        return Received(report, created=True)

    async def _find(self, client_id: str) -> ErrorReport | None:
        return await self._session.scalar(
            select(ErrorReport).where(ErrorReport.client_id == client_id)
        )
