"""Moderation endpoints (admins only). The admin panel (T31) is built on them; the app's
generated client leaves `/v1/admin/` out."""

import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status

from app.api.auth import AdminUser, get_admin_user
from app.api.contributions import STORAGE_RETRY_AFTER_SECONDS
from app.api.deps import SessionDep
from app.core.config import Settings
from app.core.storage import Storage, StorageError
from app.modules.contributions.models import ContributionStatus, ReportStatus
from app.modules.contributions.moderation import (
    ContributionNotPendingError,
    ModerationService,
)
from app.modules.contributions.schemas import (
    ContributionReview,
    ContributionReviewList,
    ErrorReportList,
    ErrorReportRead,
    ReviewDecision,
)
from app.modules.contributions.service import ContributionNotFoundError
from app.modules.products.cache import ProductCache
from app.modules.products.schemas import ErrorResponse

router = APIRouter(prefix="/v1/admin", tags=["moderation"], dependencies=[Depends(get_admin_user)])

_ACCESS: dict[int | str, dict[str, Any]] = {
    status.HTTP_401_UNAUTHORIZED: {
        "model": ErrorResponse,
        "description": "Missing, invalid or expired token",
    },
    status.HTTP_403_FORBIDDEN: {"model": ErrorResponse, "description": "Not a moderator"},
}
_DECISION: dict[int | str, dict[str, Any]] = {
    **_ACCESS,
    status.HTTP_404_NOT_FOUND: {"model": ErrorResponse, "description": "No such contribution"},
    status.HTTP_409_CONFLICT: {"model": ErrorResponse, "description": "Already decided"},
}
Limit = Annotated[int, Query(ge=1, le=200, description="How many, at most")]


def get_moderation(request: Request, session: SessionDep) -> ModerationService:
    settings: Settings = request.app.state.settings
    storage: Storage = request.app.state.storage
    cache = ProductCache(
        request.app.state.redis,
        ttl_seconds=settings.product_cache_ttl_seconds,
        not_found_ttl_seconds=settings.product_not_found_ttl_seconds,
    )
    return ModerationService(session, storage, cache)


Moderation = Annotated[ModerationService, Depends(get_moderation)]


@router.get("/contributions", summary="Contributions to moderate", responses=_ACCESS)
async def list_contributions(
    moderation: Moderation,
    status_filter: Annotated[
        ContributionStatus, Query(alias="status", description="Which ones")
    ] = ContributionStatus.PENDING,
    limit: Limit = 50,
) -> ContributionReviewList:
    items = await moderation.contributions(status_filter, limit=limit)
    return ContributionReviewList(items=[ContributionReview.model_validate(item) for item in items])


@router.post(
    "/contributions/{contribution_id}/approve",
    summary="Approve a contribution",
    description=(
        "Creates or updates the product as verified (source `contribution`), adds the "
        "contributed nutrition as a new version, scores it and makes the front photo the "
        "product photo."
    ),
    responses=_DECISION
    | {
        status.HTTP_503_SERVICE_UNAVAILABLE: {
            "model": ErrorResponse,
            "description": "Photo storage unavailable; retry later",
        },
    },
)
async def approve_contribution(
    contribution_id: uuid.UUID,
    body: ReviewDecision,
    admin: AdminUser,
    moderation: Moderation,
) -> ContributionReview:
    try:
        decided = await moderation.approve(contribution_id, admin.id, body.note)
    except ContributionNotFoundError as error:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(error)) from error
    except ContributionNotPendingError as error:
        raise HTTPException(status.HTTP_409_CONFLICT, str(error)) from error
    except StorageError as error:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "photo storage unavailable",
            headers={"Retry-After": str(STORAGE_RETRY_AFTER_SECONDS)},
        ) from error
    return ContributionReview.model_validate(decided)


@router.post(
    "/contributions/{contribution_id}/reject",
    summary="Reject a contribution",
    description="The product, if any, is left unchanged. The note is shown to the contributor.",
    responses=_DECISION,
)
async def reject_contribution(
    contribution_id: uuid.UUID,
    body: ReviewDecision,
    admin: AdminUser,
    moderation: Moderation,
) -> ContributionReview:
    try:
        decided = await moderation.reject(contribution_id, admin.id, body.note)
    except ContributionNotFoundError as error:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(error)) from error
    except ContributionNotPendingError as error:
        raise HTTPException(status.HTTP_409_CONFLICT, str(error)) from error
    return ContributionReview.model_validate(decided)


@router.get("/reports", summary="Error reports to look at", responses=_ACCESS)
async def list_reports(
    moderation: Moderation,
    status_filter: Annotated[
        ReportStatus, Query(alias="status", description="Which ones")
    ] = ReportStatus.OPEN,
    limit: Limit = 50,
) -> ErrorReportList:
    items = await moderation.reports(status_filter, limit=limit)
    return ErrorReportList(items=[ErrorReportRead.model_validate(item) for item in items])
