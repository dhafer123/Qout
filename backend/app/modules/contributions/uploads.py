"""Presigned upload URLs for contribution photos.

The app uploads photos straight to object storage (private bucket) with a URL signed for
one PUT of the declared type and size, so the API never handles the bytes and storage
itself rejects any other type or size. Keys name the uploader and the contribution:

    contributions/{user_id}/{contribution_id}/{kind}-{random}.{jpg|png}

so a submission (T25) can check that it only refers to its own user's photos. The random
part keeps a retried upload from overwriting a photo another request already used.
"""

import secrets
import uuid
from collections.abc import Callable
from datetime import UTC, datetime, timedelta

from app.core.config import Settings
from app.core.storage import Bucket
from app.modules.auth.rate_limit import RateLimiter
from app.modules.contributions.schemas import (
    PhotoContentType,
    PhotoKind,
    UploadRequest,
    UploadTicket,
)

EXTENSIONS = {PhotoContentType.JPEG: "jpg", PhotoContentType.PNG: "png"}
KEY_PREFIX = "contributions"


class UploadTooLargeError(ValueError):
    def __init__(self, size: int, limit: int) -> None:
        super().__init__(f"photo too large: {size} bytes, at most {limit}")


class UploadRateLimitedError(Exception):
    def __init__(self, retry_after: int) -> None:
        super().__init__("too many uploads; try again later")
        self.retry_after = retry_after


def contribution_prefix(user_id: uuid.UUID, contribution_id: uuid.UUID) -> str:
    """Folder holding one user's photos for one contribution (ends with `/`)."""
    return f"{KEY_PREFIX}/{user_id}/{contribution_id}/"


def upload_key(
    user_id: uuid.UUID,
    contribution_id: uuid.UUID,
    kind: PhotoKind,
    content_type: PhotoContentType,
    token: str,
) -> str:
    prefix = contribution_prefix(user_id, contribution_id)
    return f"{prefix}{kind.value}-{token}.{EXTENSIONS[content_type]}"


class UploadService:
    def __init__(
        self,
        bucket: Bucket,
        limiter: RateLimiter,
        settings: Settings,
        *,
        now: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self._bucket = bucket
        self._limiter = limiter
        self._settings = settings
        self._now = now

    async def create(self, user_id: uuid.UUID, request: UploadRequest) -> UploadTicket:
        """Raises UploadTooLargeError, UploadRateLimitedError. Signing sends no request."""
        settings = self._settings
        if request.size_bytes > settings.upload_max_bytes:
            raise UploadTooLargeError(request.size_bytes, settings.upload_max_bytes)
        limit = await self._limiter.hit(
            f"upload:user:{user_id}",
            limit=settings.upload_max_per_user,
            window=settings.upload_window_seconds,
        )
        if not limit.allowed:
            raise UploadRateLimitedError(limit.retry_after)

        key = upload_key(
            user_id,
            request.contribution_id,
            request.kind,
            request.content_type,
            secrets.token_hex(8),
        )
        issued_at = self._now()
        url = await self._bucket.presign_put(
            key,
            content_type=request.content_type.value,
            content_length=request.size_bytes,
            expires_in=settings.upload_url_ttl_seconds,
        )
        expires_at = issued_at + timedelta(seconds=settings.upload_url_ttl_seconds)
        return UploadTicket(key=key, url=url, expires_at=expires_at)
