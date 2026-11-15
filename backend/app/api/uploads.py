"""Presigned upload URLs for contribution photos (signed-in contributors only)."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status

from app.api.auth import CurrentUser
from app.core.config import Settings
from app.core.storage import Storage
from app.modules.auth.rate_limit import RateLimiter
from app.modules.contributions.schemas import UploadRequest, UploadTicket
from app.modules.contributions.uploads import (
    UploadRateLimitedError,
    UploadService,
    UploadTooLargeError,
)
from app.modules.products.schemas import ErrorResponse

router = APIRouter(prefix="/v1/uploads", tags=["contributions"])


def get_upload_service(request: Request) -> UploadService:
    settings: Settings = request.app.state.settings
    storage: Storage = request.app.state.storage
    return UploadService(storage.uploads, RateLimiter(request.app.state.redis), settings)


@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    summary="Get a URL to upload a contribution photo",
    description=(
        "Returns a presigned URL for one `PUT` of the photo, valid for a few minutes. The "
        "upload must send exactly the declared `Content-Type` and `Content-Length`; storage "
        "rejects anything else. JPEG or PNG, up to the server's size limit."
    ),
    responses={
        status.HTTP_401_UNAUTHORIZED: {
            "model": ErrorResponse,
            "description": "Missing, invalid or expired token",
        },
        status.HTTP_422_UNPROCESSABLE_CONTENT: {
            "model": ErrorResponse,
            "description": "Not JPEG or PNG, too large, or an invalid request",
        },
        status.HTTP_429_TOO_MANY_REQUESTS: {
            "model": ErrorResponse,
            "description": "Too many uploads; see Retry-After",
        },
    },
)
async def create_upload(
    body: UploadRequest,
    user: CurrentUser,
    service: Annotated[UploadService, Depends(get_upload_service)],
) -> UploadTicket:
    try:
        return await service.create(user.id, body)
    except UploadTooLargeError as error:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, str(error)) from error
    except UploadRateLimitedError as error:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            str(error),
            headers={"Retry-After": str(error.retry_after)},
        ) from error
