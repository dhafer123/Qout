"""Request and response bodies of `/v1/uploads`."""

import uuid
from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field


class PhotoKind(StrEnum):
    """Which side of the package a contribution photo shows."""

    FRONT = "front"
    NUTRITION = "nutrition"
    INGREDIENTS = "ingredients"


class PhotoContentType(StrEnum):
    JPEG = "image/jpeg"
    PNG = "image/png"


class UploadRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    contribution_id: uuid.UUID
    """Client-generated id of the contribution the photo belongs to (the outbox id)."""
    kind: PhotoKind
    content_type: PhotoContentType
    size_bytes: int = Field(gt=0)
    """Exact size of the file to upload."""


class UploadTicket(BaseModel):
    """Upload the file with `PUT url`, sending exactly the requested `Content-Type` and
    `Content-Length` (both are signed: storage rejects anything else). Then refer to the
    photo by `key` when submitting the contribution."""

    key: str
    url: str
    expires_at: datetime
