"""Contributions of unknown products, label parsing, score preview, and error reports."""

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status

from app.api.auth import CurrentUser, OptionalUser, client_ip, get_current_user
from app.api.deps import SessionDep
from app.core.config import Settings
from app.core.storage import Storage, StorageError
from app.modules.auth.rate_limit import RateLimiter
from app.modules.contributions.label_parser import label_parse_result, parse_label
from app.modules.contributions.nutrition import score_preview
from app.modules.contributions.reports import (
    ReportedProductNotFoundError,
    ReportRateLimitedError,
    ReportService,
)
from app.modules.contributions.schemas import (
    ContributionCreate,
    ContributionList,
    ContributionRead,
    LabelParseRequest,
    LabelParseResult,
    ReportCreate,
    ReportReceipt,
    ScorePreview,
    ScorePreviewRequest,
)
from app.modules.contributions.service import (
    ContributionNotFoundError,
    ContributionService,
    InvalidContributionError,
)
from app.modules.products.ean import InvalidEanError
from app.modules.products.schemas import ErrorResponse

router = APIRouter(tags=["contributions"])

STORAGE_RETRY_AFTER_SECONDS = 30
_UNAUTHORIZED = {"model": ErrorResponse, "description": "Missing, invalid or expired token"}


def get_contribution_service(request: Request, session: SessionDep) -> ContributionService:
    storage: Storage = request.app.state.storage
    return ContributionService(session, storage.uploads)


def get_report_service(request: Request, session: SessionDep) -> ReportService:
    settings: Settings = request.app.state.settings
    return ReportService(session, RateLimiter(request.app.state.redis), settings)


ContributionServiceDep = Annotated[ContributionService, Depends(get_contribution_service)]


@router.post(
    "/v1/contributions",
    status_code=status.HTTP_201_CREATED,
    summary="Submit a product",
    description=(
        "A product from label photos, as reviewed by the contributor. Upload the photos "
        "first (`POST /v1/uploads`, same `client_id`). Stored as `pending` until a moderator "
        "decides. Sending the same `client_id` again returns the stored contribution (200)."
    ),
    responses={
        status.HTTP_200_OK: {"model": ContributionRead, "description": "Already submitted"},
        status.HTTP_401_UNAUTHORIZED: _UNAUTHORIZED,
        status.HTTP_422_UNPROCESSABLE_CONTENT: {
            "model": ErrorResponse,
            "description": "Invalid barcode or values, or photos not uploaded by this user",
        },
        status.HTTP_503_SERVICE_UNAVAILABLE: {
            "model": ErrorResponse,
            "description": "Photo storage unavailable; retry later",
        },
    },
)
async def submit_contribution(
    body: ContributionCreate,
    user: CurrentUser,
    service: ContributionServiceDep,
    response: Response,
) -> ContributionRead:
    try:
        submitted = await service.submit(user.id, body)
    except (InvalidEanError, InvalidContributionError) as error:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, str(error)) from error
    except StorageError as error:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "photo storage unavailable",
            headers={"Retry-After": str(STORAGE_RETRY_AFTER_SECONDS)},
        ) from error
    if not submitted.created:
        response.status_code = status.HTTP_200_OK
    return ContributionRead.model_validate(submitted.contribution)


@router.get(
    "/v1/contributions",
    summary="My contributions",
    description="The signed-in user's contributions with their moderation status.",
    responses={status.HTTP_401_UNAUTHORIZED: _UNAUTHORIZED},
)
async def list_my_contributions(
    user: CurrentUser,
    service: ContributionServiceDep,
    limit: Annotated[int, Query(ge=1, le=100, description="How many, at most")] = 50,
) -> ContributionList:
    items = await service.mine(user.id, limit=limit)
    return ContributionList(items=[ContributionRead.model_validate(item) for item in items])


@router.get(
    "/v1/contributions/{contribution_id}",
    summary="One of my contributions",
    responses={
        status.HTTP_401_UNAUTHORIZED: _UNAUTHORIZED,
        status.HTTP_404_NOT_FOUND: {
            "model": ErrorResponse,
            "description": "No such contribution of this user",
        },
    },
)
async def get_my_contribution(
    contribution_id: uuid.UUID, user: CurrentUser, service: ContributionServiceDep
) -> ContributionRead:
    try:
        found = await service.get_mine(user.id, contribution_id)
    except ContributionNotFoundError as error:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(error)) from error
    return ContributionRead.model_validate(found)


@router.post(
    "/v1/labels/parse",
    summary="Read nutrition values from a label's OCR text",
    description=(
        "Rule-based parser (French, English, Arabic): values per 100 g or 100 mL, the "
        "basis, and issues (missing values, a table declared per portion only, values "
        "failing the sanity checks). Nothing is stored; the contributor reviews the values."
    ),
    dependencies=[Depends(get_current_user)],
    responses={status.HTTP_401_UNAUTHORIZED: _UNAUTHORIZED},
)
async def parse_label_text(body: LabelParseRequest) -> LabelParseResult:
    return label_parse_result(parse_label(body.ocr_text))


@router.post(
    "/v1/score/preview",
    summary="Score nutrition values without saving",
    dependencies=[Depends(get_current_user)],
    description=(
        "The grade and breakdown the server's engine gives these values, e.g. while a "
        "contributor reviews a label. Nothing is stored."
    ),
    responses={status.HTTP_401_UNAUTHORIZED: _UNAUTHORIZED},
)
async def preview_score(body: ScorePreviewRequest) -> ScorePreview:
    return score_preview(body.category, body.nutrition)


@router.post(
    "/v1/reports",
    status_code=status.HTTP_201_CREATED,
    summary="Report an error on a product",
    description=(
        "No account needed; the user is recorded when a valid token is sent. Sending the "
        "same `client_id` again is acknowledged (200) without storing it twice."
    ),
    responses={
        status.HTTP_200_OK: {"model": ReportReceipt, "description": "Already received"},
        status.HTTP_404_NOT_FOUND: {"model": ErrorResponse, "description": "Unknown product"},
        status.HTTP_422_UNPROCESSABLE_CONTENT: {
            "model": ErrorResponse,
            "description": "Invalid report (no reason, `other` without a comment, ...)",
        },
        status.HTTP_429_TOO_MANY_REQUESTS: {
            "model": ErrorResponse,
            "description": "Too many reports; see Retry-After",
        },
    },
)
async def report_error(
    body: ReportCreate,
    request: Request,
    response: Response,
    user: OptionalUser,
    service: Annotated[ReportService, Depends(get_report_service)],
) -> ReportReceipt:
    try:
        received = await service.submit(
            body, user_id=None if user is None else user.id, client_ip=client_ip(request)
        )
    except InvalidEanError as error:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, str(error)) from error
    except ReportedProductNotFoundError as error:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(error)) from error
    except ReportRateLimitedError as error:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            str(error),
            headers={"Retry-After": str(error.retry_after)},
        ) from error
    if not received.created:
        response.status_code = status.HTTP_200_OK
    return ReportReceipt(
        client_id=received.report.client_id, received_at=received.report.created_at
    )
