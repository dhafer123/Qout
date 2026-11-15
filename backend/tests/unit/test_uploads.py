"""Upload URLs for contribution photos: key naming, size limit, rate limit (fakes only; the
real storage is covered in tests/integration/test_uploads_api.py)."""

import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from typing import Any, cast

import pytest

from app.core.config import Settings
from app.core.storage import Bucket
from app.modules.auth.rate_limit import Limit, RateLimiter
from app.modules.contributions.schemas import PhotoContentType, PhotoKind, UploadRequest
from app.modules.contributions.uploads import (
    UploadRateLimitedError,
    UploadService,
    UploadTooLargeError,
    contribution_prefix,
    upload_key,
)

USER = uuid.UUID("11111111-1111-4111-8111-111111111111")
CONTRIBUTION = uuid.UUID("22222222-2222-4222-8222-222222222222")
NOW = datetime(2026, 11, 15, 12, 0, tzinfo=UTC)


@dataclass
class FakeBucket:
    calls: list[dict[str, Any]] = field(default_factory=list)

    async def presign_put(
        self, key: str, *, content_type: str, content_length: int, expires_in: int
    ) -> str:
        self.calls.append(
            {
                "key": key,
                "content_type": content_type,
                "content_length": content_length,
                "expires_in": expires_in,
            }
        )
        return f"https://storage.example/{key}?signed"


@dataclass
class FakeLimiter:
    allowed: bool = True
    hits: list[tuple[str, int, int]] = field(default_factory=list)

    async def hit(self, key: str, *, limit: int, window: int) -> Limit:
        self.hits.append((key, limit, window))
        return Limit(allowed=self.allowed, retry_after=0 if self.allowed else 42)


def make_settings(**values: object) -> Settings:
    base: dict[str, object] = {
        "database_url": "postgresql+asyncpg://user:pw@db.example:5432/qout",
        "redis_url": "redis://cache.example:6379/0",
        "upload_max_bytes": 4096,
        "upload_url_ttl_seconds": 120,
        "upload_max_per_user": 7,
        "upload_window_seconds": 600,
    }
    return Settings(_env_file=None, **(base | values))  # type: ignore[arg-type]


def service(bucket: FakeBucket, limiter: FakeLimiter) -> UploadService:
    return UploadService(
        cast(Bucket, bucket), cast(RateLimiter, limiter), make_settings(), now=lambda: NOW
    )


def request(**values: object) -> UploadRequest:
    base: dict[str, object] = {
        "contribution_id": CONTRIBUTION,
        "kind": PhotoKind.NUTRITION,
        "content_type": PhotoContentType.JPEG,
        "size_bytes": 1000,
    }
    return UploadRequest.model_validate(base | values)


def test_key_names_user_contribution_and_kind() -> None:
    key = upload_key(USER, CONTRIBUTION, PhotoKind.FRONT, PhotoContentType.PNG, "abc123")

    assert key == f"contributions/{USER}/{CONTRIBUTION}/front-abc123.png"
    assert key.startswith(contribution_prefix(USER, CONTRIBUTION))


@pytest.mark.parametrize(
    ("content_type", "extension"),
    [(PhotoContentType.JPEG, "jpg"), (PhotoContentType.PNG, "png")],
)
def test_extension_follows_content_type(content_type: PhotoContentType, extension: str) -> None:
    key = upload_key(USER, CONTRIBUTION, PhotoKind.INGREDIENTS, content_type, "t")

    assert key.endswith(f"/ingredients-t.{extension}")


async def test_ticket_signs_the_declared_type_and_size() -> None:
    bucket, limiter = FakeBucket(), FakeLimiter()

    ticket = await service(bucket, limiter).create(USER, request())

    [call] = bucket.calls
    assert call == {
        "key": ticket.key,
        "content_type": "image/jpeg",
        "content_length": 1000,
        "expires_in": 120,
    }
    assert ticket.key.startswith(f"contributions/{USER}/{CONTRIBUTION}/nutrition-")
    assert ticket.url == f"https://storage.example/{ticket.key}?signed"
    assert ticket.expires_at == NOW + timedelta(seconds=120)
    assert limiter.hits == [(f"upload:user:{USER}", 7, 600)]


async def test_keys_are_unique_per_request() -> None:
    upload = service(FakeBucket(), FakeLimiter())

    keys = {(await upload.create(USER, request())).key for _ in range(20)}

    assert len(keys) == 20


async def test_size_limit_is_inclusive() -> None:
    bucket = FakeBucket()
    upload = service(bucket, FakeLimiter())

    await upload.create(USER, request(size_bytes=4096))
    with pytest.raises(UploadTooLargeError, match="4097 bytes, at most 4096"):
        await upload.create(USER, request(size_bytes=4097))

    assert len(bucket.calls) == 1


async def test_too_large_does_not_count_against_the_rate_limit() -> None:
    limiter = FakeLimiter()

    with pytest.raises(UploadTooLargeError):
        await service(FakeBucket(), limiter).create(USER, request(size_bytes=5000))

    assert limiter.hits == []


async def test_rate_limited() -> None:
    bucket = FakeBucket()

    with pytest.raises(UploadRateLimitedError) as error:
        await service(bucket, FakeLimiter(allowed=False)).create(USER, request())

    assert error.value.retry_after == 42
    assert bucket.calls == []


@pytest.mark.parametrize(
    "values",
    [
        {"content_type": "image/gif"},
        {"content_type": "image/webp"},
        {"kind": "back"},
        {"size_bytes": 0},
        {"unexpected": True},
    ],
)
def test_request_validation(values: dict[str, object]) -> None:
    with pytest.raises(ValueError, match="validation error"):
        request(**values)
