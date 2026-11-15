"""S3-compatible object storage (RustFS locally, any S3 provider when deployed; ADR 0002).

Only the generic S3 API is used, with path-style addressing. Two buckets:

- `s3_bucket` (private): contribution photos, uploaded by the app with presigned URLs.
- `s3_public_bucket` (readable by anyone): product photos, served from `media_base_url`.

Presigned URLs are signed for `s3_presign_endpoint_url`, the address the phone uses, by a
second client that never sends requests (signing is local).
"""

from collections.abc import AsyncIterator
from contextlib import AsyncExitStack, asynccontextmanager
from dataclasses import dataclass
from typing import TYPE_CHECKING

from aiobotocore.config import AioConfig
from aiobotocore.session import get_session
from botocore.exceptions import BotoCoreError, ClientError

from app.core.config import Settings

if TYPE_CHECKING:  # stubs are a dev dependency
    from aiobotocore.session import ClientCreatorContext
    from types_aiobotocore_s3 import S3Client

_NOT_FOUND = {"404", "NoSuchKey", "NotFound"}


class StorageError(Exception):
    """The storage service failed or could not be reached."""


@dataclass(frozen=True)
class StoredObject:
    size: int
    content_type: str | None


class Bucket:
    """One bucket: write, inspect and delete objects, presign uploads."""

    def __init__(self, client: "S3Client", presign_client: "S3Client", name: str) -> None:
        self._client = client
        self._presign_client = presign_client
        self.name = name

    async def presign_put(
        self, key: str, *, content_type: str, content_length: int, expires_in: int
    ) -> str:
        """URL for one PUT of exactly this type and size (both are signed headers)."""
        return await self._presign_client.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": self.name,
                "Key": key,
                "ContentType": content_type,
                "ContentLength": content_length,
            },
            ExpiresIn=expires_in,
            HttpMethod="PUT",
        )

    async def put(
        self, key: str, data: bytes, *, content_type: str, cache_control: str | None = None
    ) -> None:
        try:
            if cache_control is None:
                await self._client.put_object(
                    Bucket=self.name, Key=key, Body=data, ContentType=content_type
                )
            else:
                await self._client.put_object(
                    Bucket=self.name,
                    Key=key,
                    Body=data,
                    ContentType=content_type,
                    CacheControl=cache_control,
                )
        except (ClientError, BotoCoreError) as error:
            raise StorageError(f"could not store {key}: {error}") from error

    async def copy_from(
        self,
        source: "Bucket",
        source_key: str,
        key: str,
        *,
        content_type: str,
        cache_control: str,
    ) -> None:
        """Copy an object from another bucket into this one, server side."""
        try:
            await self._client.copy_object(
                Bucket=self.name,
                Key=key,
                CopySource={"Bucket": source.name, "Key": source_key},
                MetadataDirective="REPLACE",
                ContentType=content_type,
                CacheControl=cache_control,
            )
        except (ClientError, BotoCoreError) as error:
            raise StorageError(f"could not copy {source_key} to {key}: {error}") from error

    async def head(self, key: str) -> StoredObject | None:
        """The object's size and type, or None if there is no such object."""
        try:
            response = await self._client.head_object(Bucket=self.name, Key=key)
        except ClientError as error:
            if error.response.get("Error", {}).get("Code") in _NOT_FOUND:
                return None
            raise StorageError(f"could not inspect {key}: {error}") from error
        except BotoCoreError as error:
            raise StorageError(f"could not inspect {key}: {error}") from error
        return StoredObject(
            size=response["ContentLength"], content_type=response.get("ContentType")
        )

    async def delete(self, key: str) -> None:
        """Deleting a missing object is not an error (S3 semantics)."""
        try:
            await self._client.delete_object(Bucket=self.name, Key=key)
        except (ClientError, BotoCoreError) as error:
            raise StorageError(f"could not delete {key}: {error}") from error


@dataclass(frozen=True)
class Storage:
    uploads: Bucket
    """Private: contribution photos."""
    public: Bucket
    """Public: product photos."""


def _config() -> AioConfig:
    return AioConfig(
        signature_version="s3v4",
        s3={"addressing_style": "path"},
        connect_timeout=3,
        read_timeout=15,
        retries={"max_attempts": 3, "mode": "standard"},
    )


@asynccontextmanager
async def open_storage(settings: Settings) -> AsyncIterator[Storage]:
    """Clients for both buckets, closed on exit. Opening sends no request."""
    session = get_session()

    def create(endpoint: str) -> "ClientCreatorContext[S3Client]":
        return session.create_client(
            "s3",
            endpoint_url=endpoint.rstrip("/"),
            region_name=settings.s3_region,
            aws_access_key_id=settings.s3_access_key.get_secret_value(),
            aws_secret_access_key=settings.s3_secret_key.get_secret_value(),
            config=_config(),
        )

    async with AsyncExitStack() as stack:
        client = await stack.enter_async_context(create(str(settings.s3_endpoint_url)))
        presign_client = await stack.enter_async_context(
            create(str(settings.s3_presign_endpoint_url))
        )
        yield Storage(
            uploads=Bucket(client, presign_client, settings.s3_bucket),
            public=Bucket(client, presign_client, settings.s3_public_bucket),
        )


def media_url(settings: Settings, key: str) -> str:
    """Public URL of an object in the public bucket."""
    return f"{settings.media_base_url}{key}"
