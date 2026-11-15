"""Copy products' front photos from their source (Open Food Facts) into our public bucket.

The app never calls OFF, so the photo it shows must come from our storage. An OFF product
needs copying while `source_image_url` differs from `image_copied_from`, or when the
source dropped its photo but we still hold one (contributed products get their photo from
moderation instead). For each such product:

- the photo is downloaded (OFF's User-Agent, rate-limited, retried on timeouts, connection
  errors, 429 and 5xx), at most `max_bytes`, and must really be a JPEG or PNG;
- stored as `products/{ean}/front-{sha256[:16]}.{jpg|png}`: the name changes with the
  content, so it can be cached forever, and an unchanged photo keeps its key;
- the row is updated only if the source URL did not change meanwhile (else the next run
  copies the newer one), the replaced object is deleted, the cached response dropped.

A photo the source no longer has (404, 410, other 4xx) or that is unusable (not an image,
too large) is remembered as copied with no key, so it is not fetched again until the
source URL changes. Temporary failures leave the product for the next run.
"""

import hashlib
import logging
import uuid
from dataclasses import dataclass

import httpx
from sqlalchemy import ColumnElement, and_, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.storage import Bucket, StorageError
from app.modules.ingestion.off_client import RateLimiter, RetryPolicy
from app.modules.products.cache import ProductCache
from app.modules.products.models import DataSource, Product

logger = logging.getLogger(__name__)

CACHE_CONTROL = "public, max-age=31536000, immutable"
_RETRY_STATUSES = frozenset({429, 500, 502, 503, 504})
_SIGNATURES = {b"\xff\xd8\xff": ("image/jpeg", "jpg"), b"\x89PNG\r\n\x1a\n": ("image/png", "png")}


class UnusableImageError(Exception):
    """The source has no usable photo at this URL: don't ask again for the same URL."""


class ImageFetchError(Exception):
    """Temporary failure (still failing after retries): try again on the next run."""


@dataclass(frozen=True)
class Image:
    data: bytes
    content_type: str
    extension: str


@dataclass(frozen=True)
class ImageCopySettings:
    retry: RetryPolicy
    max_bytes: int
    """Larger photos are unusable."""
    limiter: RateLimiter | None = None
    """Spaces requests to the source (OFF's rate limit)."""
    batch_size: int = 100


@dataclass
class ImageCopyStats:
    copied: int = 0
    removed: int = 0
    """Products whose source dropped the photo: our copy deleted."""
    unusable: int = 0
    failed: int = 0
    """Temporary failures (source or storage), retried on the next run."""


def image_key(ean: str, image: Image) -> str:
    digest = hashlib.sha256(image.data).hexdigest()[:16]
    return f"products/{ean}/front-{digest}.{image.extension}"


def sniff(data: bytes) -> tuple[str, str] | None:
    """(content type, extension) from the file's first bytes, or None."""
    for signature, kind in _SIGNATURES.items():
        if data.startswith(signature):
            return kind
    return None


async def fetch_image(
    http: httpx.AsyncClient,
    url: str,
    *,
    retry: RetryPolicy,
    max_bytes: int,
    limiter: RateLimiter | None = None,
) -> Image:
    """Raises UnusableImageError (permanent) or ImageFetchError (temporary)."""
    for attempt in range(retry.max_retries + 1):
        if attempt:
            await retry.sleep(retry.backoff(attempt - 1))
        if limiter is not None:
            await limiter.acquire()
        try:
            data = await _download(http, url, max_bytes)
        except (httpx.TransportError, _RetryableStatusError) as error:
            logger.info("image download failed", extra={"url": url, "error": repr(error)})
            continue
        kind = sniff(data)
        if kind is None:
            raise UnusableImageError(f"not a JPEG or PNG: {url}")
        return Image(data=data, content_type=kind[0], extension=kind[1])
    raise ImageFetchError(f"could not download {url}")


class _RetryableStatusError(Exception):
    pass


async def _download(http: httpx.AsyncClient, url: str, max_bytes: int) -> bytes:
    # No redirects: the URL was checked to be on an OFF host; a redirect could lead anywhere.
    async with http.stream("GET", url, follow_redirects=False) as response:
        if response.status_code in _RETRY_STATUSES:
            raise _RetryableStatusError(response.status_code)
        if response.status_code != httpx.codes.OK:
            raise UnusableImageError(f"{url} answered {response.status_code}")
        chunks: list[bytes] = []
        size = 0
        async for chunk in response.aiter_bytes():
            size += len(chunk)
            if size > max_bytes:
                raise UnusableImageError(f"{url} is larger than {max_bytes} bytes")
            chunks.append(chunk)
    return b"".join(chunks)


def needs_copy() -> ColumnElement[bool]:
    """Open Food Facts products whose stored photo doesn't match their source. Other
    products (contributions) get their photo from moderation, never from this job."""
    has_source = and_(
        Product.source_image_url.is_not(None),
        Product.source_image_url.is_distinct_from(Product.image_copied_from),
    )
    dropped = and_(
        Product.source_image_url.is_(None),
        or_(Product.image_key.is_not(None), Product.image_copied_from.is_not(None)),
    )
    return and_(Product.source == DataSource.OPEN_FOOD_FACTS, or_(has_source, dropped))


@dataclass(frozen=True)
class _Pending:
    id: uuid.UUID
    ean: str
    source: str | None
    key: str | None


class ProductImageCopier:
    def __init__(
        self,
        sessions: async_sessionmaker[AsyncSession],
        http: httpx.AsyncClient,
        bucket: Bucket,
        cache: ProductCache,
        settings: ImageCopySettings,
    ) -> None:
        self._sessions = sessions
        self._http = http
        self._bucket = bucket
        self._cache = cache
        self._settings = settings

    async def run(self) -> ImageCopyStats:
        """One pass over every product needing a copy (keyset by id)."""
        stats = ImageCopyStats()
        after: uuid.UUID | None = None
        while batch := await self._pending(after):
            for pending in batch:
                await self._copy(pending, stats)
            after = batch[-1].id
        logger.info("product images copied", extra=vars(stats))
        return stats

    async def _pending(self, after: uuid.UUID | None) -> list[_Pending]:
        query = (
            select(Product.id, Product.ean, Product.source_image_url, Product.image_key)
            .where(needs_copy())
            .order_by(Product.id)
            .limit(self._settings.batch_size)
        )
        if after is not None:
            query = query.where(Product.id > after)
        async with self._sessions() as session:
            rows = (await session.execute(query)).all()
        return [_Pending(id=r[0], ean=r[1], source=r[2], key=r[3]) for r in rows]

    async def _copy(self, pending: _Pending, stats: ImageCopyStats) -> None:
        if pending.source is None:
            saved = await self._save(pending, key=None)
            if saved and pending.key is not None:
                stats.removed += 1
            return
        try:
            image = await fetch_image(
                self._http,
                pending.source,
                retry=self._settings.retry,
                max_bytes=self._settings.max_bytes,
                limiter=self._settings.limiter,
            )
        except UnusableImageError as error:
            logger.info("product image unusable", extra={"ean": pending.ean, "error": str(error)})
            if await self._save(pending, key=None):
                stats.unusable += 1
            return
        except ImageFetchError:
            stats.failed += 1
            return

        key = image_key(pending.ean, image)
        try:
            await self._bucket.put(
                key, image.data, content_type=image.content_type, cache_control=CACHE_CONTROL
            )
        except StorageError:
            logger.warning("product image not stored", extra={"ean": pending.ean}, exc_info=True)
            stats.failed += 1
            return
        if await self._save(pending, key=key):
            stats.copied += 1
        elif key != pending.key:
            await self._delete(key)  # the source changed meanwhile: not used

    async def _save(self, pending: _Pending, *, key: str | None) -> bool:
        """Record the copy unless the source URL changed meanwhile; then drop the replaced
        object and the cached response."""
        statement = (
            update(Product)
            .where(
                Product.id == pending.id,
                Product.source_image_url.is_not_distinct_from(pending.source),
            )
            .values(image_key=key, image_copied_from=pending.source)
        )
        async with self._sessions() as session:
            result = await session.execute(statement)
            await session.commit()
        if result.rowcount == 0:  # type: ignore[attr-defined]
            return False
        if pending.key is not None and pending.key != key:
            await self._delete(pending.key)
        await self._cache.invalidate(pending.ean)
        return True

    async def _delete(self, key: str) -> None:
        try:
            await self._bucket.delete(key)
        except StorageError:
            # An orphan in the public bucket is harmless; nothing refers to it any more.
            logger.warning("old product image not deleted", extra={"key": key}, exc_info=True)
