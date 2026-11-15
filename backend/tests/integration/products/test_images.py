"""Copying product photos into the public bucket: real Postgres, Redis and RustFS; Open Food
Facts' image server mocked with respx (storage talks through aiohttp, which respx leaves
alone). Also the worker job and its lock."""

from collections.abc import AsyncIterator, Callable, Iterator
from typing import Any

import httpx
import pytest
import respx
from redis.asyncio import Redis
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.core.config import Settings
from app.core.storage import Storage, StoredObject, media_url, open_storage
from app.modules.ingestion.off_client import RetryPolicy
from app.modules.products import images
from app.modules.products.cache import ProductCache, cache_key
from app.modules.products.images import (
    CACHE_CONTROL,
    Image,
    ImageCopySettings,
    ImageCopyStats,
    ProductImageCopier,
    image_key,
)
from app.modules.products.models import DataSource, Product
from app.worker import jobs
from tests.factories import ProductFactory
from tests.integration.conftest import IntegrationEnv

Sessions = async_sessionmaker[AsyncSession]
OFF = "https://images.openfoodfacts.org/images/products"
URL = f"{OFF}/619/150/722/0214/front_fr.90.400.jpg"
NEWER = f"{OFF}/619/150/722/0214/front_fr.91.400.jpg"
JPEG = b"\xff\xd8\xff\xe0" + b"a front photo" * 10
OTHER_JPEG = b"\xff\xd8\xff\xe0" + b"another photo" * 10
PNG = b"\x89PNG\r\n\x1a\n" + b"png photo"


async def no_sleep(_: float) -> None:
    return None


@pytest.fixture
async def redis(integration_env: IntegrationEnv) -> AsyncIterator[Redis]:
    client = Redis.from_url(str(integration_env.redis_url))
    yield client
    await client.aclose()


async def _clear(engine: AsyncEngine, redis: Redis) -> None:
    async with engine.begin() as connection:
        await connection.execute(text("TRUNCATE products CASCADE"))
    keys = [key async for key in redis.scan_iter(match="qout:product:*")]
    if keys:
        await redis.delete(*keys)


@pytest.fixture
async def sessions(db_engine: AsyncEngine, redis: Redis) -> AsyncIterator[Sessions]:
    await _clear(db_engine, redis)
    yield async_sessionmaker(db_engine, expire_on_commit=False)
    await _clear(db_engine, redis)


@pytest.fixture
def off() -> Iterator[respx.MockRouter]:
    with respx.mock(assert_all_called=False) as router:
        yield router


@pytest.fixture
def cache(redis: Redis) -> ProductCache:
    return ProductCache(redis, ttl_seconds=60, not_found_ttl_seconds=60)


@pytest.fixture
async def http() -> AsyncIterator[httpx.AsyncClient]:
    """Follows redirects like the worker's client (bulk files need them); photos must not."""
    async with httpx.AsyncClient(
        headers={"User-Agent": "Qout/test"}, follow_redirects=True
    ) as client:
        yield client


@pytest.fixture
def copier(
    sessions: Sessions, http: httpx.AsyncClient, storage: Storage, cache: ProductCache
) -> Callable[..., ProductImageCopier]:
    def _copier(**values: Any) -> ProductImageCopier:
        settings: dict[str, Any] = {
            "retry": RetryPolicy(max_retries=1, sleep=no_sleep),
            "max_bytes": 4096,
        }
        return ProductImageCopier(
            sessions, http, storage.public, cache, ImageCopySettings(**(settings | values))
        )

    return _copier


async def product(sessions: Sessions, **values: Any) -> Product:
    async with sessions() as session:
        created = await ProductFactory.create(session, **values)
        await session.commit()
    return created


async def reload(sessions: Sessions, stored: Product) -> Product:
    async with sessions() as session:
        found = await session.scalar(select(Product).where(Product.id == stored.id))
    assert found is not None
    return found


def jpeg_key(ean: str, data: bytes = JPEG) -> str:
    return image_key(ean, Image(data, "image/jpeg", "jpg"))


# ---------------------------------------------------------------- copying


async def test_new_photo_is_copied_and_served_publicly(
    sessions: Sessions,
    off: respx.MockRouter,
    copier: Callable[..., ProductImageCopier],
    storage: Storage,
    make_settings: Callable[..., Settings],
) -> None:
    stored = await product(sessions, source_image_url=URL)
    route = off.get(URL).respond(200, content=JPEG, headers={"Content-Type": "image/jpeg"})

    stats = await copier().run()

    assert stats == ImageCopyStats(copied=1)
    assert route.calls.last.request.headers["User-Agent"] == "Qout/test"
    after = await reload(sessions, stored)
    assert after.image_key == jpeg_key(stored.ean)
    assert after.image_copied_from == URL
    assert after.updated_at > stored.updated_at
    assert await storage.public.head(after.image_key) == StoredObject(len(JPEG), "image/jpeg")
    assert await storage.uploads.head(after.image_key) is None
    with respx.mock(assert_all_called=False) as router:
        router.route(host="localhost").pass_through()
        async with httpx.AsyncClient() as client:
            served = await client.get(media_url(make_settings(), after.image_key))
    assert (served.status_code, served.content) == (200, JPEG)
    assert served.headers["cache-control"] == CACHE_CONTROL


async def test_png_keeps_its_type(
    sessions: Sessions,
    off: respx.MockRouter,
    copier: Callable[..., ProductImageCopier],
    storage: Storage,
) -> None:
    stored = await product(sessions, source_image_url=URL)
    off.get(URL).respond(200, content=PNG, headers={"Content-Type": "image/jpeg"})

    await copier().run()

    after = await reload(sessions, stored)
    assert after.image_key is not None
    assert after.image_key.endswith(".png")
    assert await storage.public.head(after.image_key) == StoredObject(len(PNG), "image/png")


async def test_nothing_to_do_the_second_time(
    sessions: Sessions, off: respx.MockRouter, copier: Callable[..., ProductImageCopier]
) -> None:
    await product(sessions, source_image_url=URL)
    await product(sessions, source_image_url=None)
    route = off.get(URL).respond(200, content=JPEG)

    await copier().run()
    again = await copier().run()

    assert again == ImageCopyStats()
    assert route.call_count == 1


async def test_changed_photo_replaces_the_old_copy(
    sessions: Sessions,
    off: respx.MockRouter,
    copier: Callable[..., ProductImageCopier],
    storage: Storage,
) -> None:
    stored = await product(sessions, source_image_url=URL)
    off.get(URL).respond(200, content=JPEG)
    off.get(NEWER).respond(200, content=OTHER_JPEG)
    await copier().run()
    first_key = (await reload(sessions, stored)).image_key
    assert first_key is not None
    async with sessions() as session:
        await session.execute(
            Product.__table__.update().where(Product.id == stored.id).values(source_image_url=NEWER)
        )
        await session.commit()

    stats = await copier().run()

    after = await reload(sessions, stored)
    assert stats == ImageCopyStats(copied=1)
    assert (after.image_key, after.image_copied_from) == (jpeg_key(stored.ean, OTHER_JPEG), NEWER)
    assert await storage.public.head(first_key) is None
    assert await storage.public.head(after.image_key) is not None


async def test_same_photo_at_a_new_url_keeps_its_key(
    sessions: Sessions,
    off: respx.MockRouter,
    copier: Callable[..., ProductImageCopier],
    storage: Storage,
) -> None:
    key = jpeg_key("6191507220214")
    await storage.public.put(key, JPEG, content_type="image/jpeg")
    stored = await product(
        sessions, ean="6191507220214", source_image_url=NEWER, image_key=key, image_copied_from=URL
    )
    off.get(NEWER).respond(200, content=JPEG)

    await copier().run()

    after = await reload(sessions, stored)
    assert (after.image_key, after.image_copied_from) == (key, NEWER)
    assert await storage.public.head(key) is not None


async def test_copying_drops_the_cached_response(
    sessions: Sessions,
    off: respx.MockRouter,
    copier: Callable[..., ProductImageCopier],
    redis: Redis,
) -> None:
    stored = await product(sessions, source_image_url=URL)
    await redis.set(cache_key(stored.ean), b"{}")
    off.get(URL).respond(200, content=JPEG)

    await copier().run()

    assert await redis.exists(cache_key(stored.ean)) == 0


async def test_all_products_are_visited_in_batches(
    sessions: Sessions, off: respx.MockRouter, copier: Callable[..., ProductImageCopier]
) -> None:
    for _ in range(5):
        await product(sessions, source_image_url=URL)
    off.get(URL).respond(200, content=JPEG)

    stats = await copier(batch_size=2).run()

    assert stats == ImageCopyStats(copied=5)


async def test_requests_wait_for_the_rate_limiter(
    sessions: Sessions, off: respx.MockRouter, copier: Callable[..., ProductImageCopier]
) -> None:
    class CountingLimiter:
        calls = 0

        async def acquire(self) -> None:
            self.calls += 1

    limiter = CountingLimiter()
    await product(sessions, source_image_url=URL)
    off.get(URL).mock(side_effect=[httpx.Response(503), httpx.Response(200, content=JPEG)])

    await copier(limiter=limiter).run()

    assert limiter.calls == 2


# ---------------------------------------------------------------- unusable photos


@pytest.mark.parametrize(
    "response",
    [
        pytest.param(httpx.Response(404), id="not-found"),
        pytest.param(httpx.Response(410), id="gone"),
        pytest.param(httpx.Response(403), id="forbidden"),
        pytest.param(
            httpx.Response(302, headers={"Location": "http://169.254.169.254/latest"}),
            id="redirect",
        ),
        pytest.param(httpx.Response(200, text="<html>no</html>"), id="not-an-image"),
        pytest.param(httpx.Response(200, content=b""), id="empty"),
        pytest.param(httpx.Response(200, content=JPEG * 100), id="too-large"),
    ],
)
async def test_unusable_photo_is_not_fetched_again(
    sessions: Sessions,
    off: respx.MockRouter,
    copier: Callable[..., ProductImageCopier],
    response: httpx.Response,
) -> None:
    stored = await product(sessions, source_image_url=URL)
    route = off.get(URL).mock(return_value=response)

    stats = await copier().run()
    again = await copier().run()

    after = await reload(sessions, stored)
    assert (stats, again) == (ImageCopyStats(unusable=1), ImageCopyStats())
    assert (after.image_key, after.image_copied_from) == (None, URL)
    assert route.call_count == 1


async def test_unusable_new_photo_removes_the_old_copy(
    sessions: Sessions,
    off: respx.MockRouter,
    copier: Callable[..., ProductImageCopier],
    storage: Storage,
) -> None:
    old_key = jpeg_key("6191507220214")
    await storage.public.put(old_key, JPEG, content_type="image/jpeg")
    stored = await product(
        sessions,
        ean="6191507220214",
        source_image_url=NEWER,
        image_key=old_key,
        image_copied_from=URL,
    )
    off.get(NEWER).respond(404)

    await copier().run()

    after = await reload(sessions, stored)
    assert (after.image_key, after.image_copied_from) == (None, NEWER)
    assert await storage.public.head(old_key) is None


async def test_photo_dropped_by_the_source_is_deleted(
    sessions: Sessions, copier: Callable[..., ProductImageCopier], storage: Storage
) -> None:
    key = jpeg_key("6191507220214")
    await storage.public.put(key, JPEG, content_type="image/jpeg")
    with_copy = await product(
        sessions, ean="6191507220214", source_image_url=None, image_key=key, image_copied_from=URL
    )
    was_unusable = await product(sessions, source_image_url=None, image_copied_from=URL)

    stats = await copier().run()

    assert stats == ImageCopyStats(removed=1)
    for stored in (with_copy, was_unusable):
        after = await reload(sessions, stored)
        assert (after.image_key, after.image_copied_from) == (None, None)
    assert await storage.public.head(key) is None


# ---------------------------------------------------------------- temporary failures


@pytest.mark.parametrize(
    "failure",
    [
        pytest.param(httpx.Response(503), id="unavailable"),
        pytest.param(httpx.Response(429), id="rate-limited"),
        pytest.param(httpx.ConnectError("refused"), id="connection"),
        pytest.param(httpx.ReadTimeout("slow"), id="timeout"),
    ],
)
async def test_temporary_failure_is_retried_on_the_next_run(
    sessions: Sessions,
    off: respx.MockRouter,
    copier: Callable[..., ProductImageCopier],
    failure: httpx.Response | Exception,
) -> None:
    stored = await product(sessions, source_image_url=URL)
    route = off.get(URL).mock(side_effect=[failure, failure])

    stats = await copier().run()

    after = await reload(sessions, stored)
    assert stats == ImageCopyStats(failed=1)
    assert route.call_count == 2  # one retry
    assert (after.image_key, after.image_copied_from) == (None, None)

    route.mock(side_effect=None, return_value=httpx.Response(200, content=JPEG))
    assert await copier().run() == ImageCopyStats(copied=1)


async def test_failure_then_success_within_the_retries(
    sessions: Sessions, off: respx.MockRouter, copier: Callable[..., ProductImageCopier]
) -> None:
    await product(sessions, source_image_url=URL)
    off.get(URL).mock(side_effect=[httpx.Response(502), httpx.Response(200, content=JPEG)])

    assert await copier().run() == ImageCopyStats(copied=1)


async def test_storage_down_leaves_the_product_for_later(
    sessions: Sessions,
    off: respx.MockRouter,
    http: httpx.AsyncClient,
    cache: ProductCache,
    make_settings: Callable[..., Settings],
) -> None:
    stored = await product(sessions, source_image_url=URL)
    off.get(URL).respond(200, content=JPEG)
    settings = make_settings(s3_endpoint_url="http://127.0.0.1:1")

    async with open_storage(settings) as down:
        copier = ProductImageCopier(
            sessions,
            http,
            down.public,
            cache,
            ImageCopySettings(retry=RetryPolicy(max_retries=0), max_bytes=4096),
        )
        stats = await copier.run()

    assert stats == ImageCopyStats(failed=1)
    after = await reload(sessions, stored)
    assert (after.image_key, after.image_copied_from) == (None, None)


async def test_old_copy_that_cannot_be_deleted_is_left_behind(
    sessions: Sessions,
    copier: Callable[..., ProductImageCopier],
    monkeypatch: pytest.MonkeyPatch,
    storage: Storage,
) -> None:
    async def failing_delete(key: str) -> None:
        raise images.StorageError(key)

    stored = await product(
        sessions, source_image_url=None, image_key="products/x/front-a.jpg", image_copied_from=URL
    )
    monkeypatch.setattr(storage.public, "delete", failing_delete)

    assert await copier().run() == ImageCopyStats(removed=1)
    assert (await reload(sessions, stored)).image_key is None


async def test_source_changed_during_the_download_is_left_for_the_next_run(
    sessions: Sessions,
    copier: Callable[..., ProductImageCopier],
    monkeypatch: pytest.MonkeyPatch,
    storage: Storage,
) -> None:
    stored = await product(sessions, source_image_url=URL)

    async def fetch_while_the_import_changes_it(*_: Any, **__: Any) -> Image:
        await _change_source(sessions, stored)
        return Image(JPEG, "image/jpeg", "jpg")

    monkeypatch.setattr(images, "fetch_image", fetch_while_the_import_changes_it)

    stats = await copier().run()

    after = await reload(sessions, stored)
    assert stats == ImageCopyStats()
    assert (after.source_image_url, after.image_key, after.image_copied_from) == (
        NEWER,
        None,
        None,
    )
    assert await storage.public.head(jpeg_key(stored.ean)) is None


# ---------------------------------------------------------------- worker job


@pytest.fixture
async def ctx(
    make_settings: Callable[..., Settings], sessions: Sessions, storage: Storage
) -> AsyncIterator[jobs.Context]:
    context: jobs.Context = {"settings": make_settings(off_max_retries=0)}
    await jobs.startup(context)
    yield context
    await jobs.shutdown(context)


async def test_job_copies_photos(
    ctx: jobs.Context, sessions: Sessions, off: respx.MockRouter, storage: Storage
) -> None:
    stored = await product(sessions, source_image_url=URL)
    route = off.get(URL).respond(200, content=JPEG)

    result = await jobs.copy_product_images(ctx)

    assert result == {"copied": 1, "removed": 0, "unusable": 0, "failed": 0}
    assert route.calls.last.request.headers["User-Agent"].startswith("Qout/")
    after = await reload(sessions, stored)
    assert after.image_key is not None
    assert await storage.public.head(after.image_key) is not None


async def test_job_is_skipped_while_another_copy_runs(
    ctx: jobs.Context, sessions: Sessions, db_engine: AsyncEngine, off: respx.MockRouter
) -> None:
    stored = await product(sessions, source_image_url=URL)
    route = off.get(URL).respond(200, content=JPEG)
    async with db_engine.connect() as connection:
        await connection.execute(text("SELECT pg_advisory_lock(:k)"), {"k": jobs.IMAGES_LOCK_KEY})
        try:
            assert await jobs.copy_product_images(ctx) is None
        finally:
            await connection.execute(
                text("SELECT pg_advisory_unlock(:k)"), {"k": jobs.IMAGES_LOCK_KEY}
            )

    assert route.call_count == 0
    assert (await reload(sessions, stored)).image_key is None


async def test_job_runs_while_an_import_holds_its_lock(
    ctx: jobs.Context, sessions: Sessions, db_engine: AsyncEngine, off: respx.MockRouter
) -> None:
    await product(sessions, source_image_url=URL)
    off.get(URL).respond(200, content=JPEG)
    async with db_engine.connect() as connection:
        await connection.execute(text("SELECT pg_advisory_lock(:k)"), {"k": jobs.IMPORT_LOCK_KEY})
        try:
            result = await jobs.copy_product_images(ctx)
        finally:
            await connection.execute(
                text("SELECT pg_advisory_unlock(:k)"), {"k": jobs.IMPORT_LOCK_KEY}
            )

    assert result is not None
    assert result["copied"] == 1


async def _change_source(sessions: Sessions, stored: Product) -> None:
    async with sessions() as session:
        await session.execute(
            Product.__table__.update().where(Product.id == stored.id).values(source_image_url=NEWER)
        )
        await session.commit()


async def test_unusable_while_the_source_changed_is_left_for_the_next_run(
    sessions: Sessions,
    copier: Callable[..., ProductImageCopier],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    stored = await product(sessions, source_image_url=URL)

    async def unusable_after_a_change(*_: Any, **__: Any) -> Image:
        await _change_source(sessions, stored)
        raise images.UnusableImageError(URL)

    monkeypatch.setattr(images, "fetch_image", unusable_after_a_change)

    assert await copier().run() == ImageCopyStats()
    after = await reload(sessions, stored)
    assert (after.image_key, after.image_copied_from) == (None, None)


async def test_source_changed_but_same_photo_keeps_the_current_copy(
    sessions: Sessions,
    copier: Callable[..., ProductImageCopier],
    monkeypatch: pytest.MonkeyPatch,
    storage: Storage,
) -> None:
    key = jpeg_key("6191507220214")
    await storage.public.put(key, JPEG, content_type="image/jpeg")
    stored = await product(
        sessions, ean="6191507220214", source_image_url=NEWER, image_key=key, image_copied_from=URL
    )

    async def same_photo_after_a_change(*_: Any, **__: Any) -> Image:
        async with sessions() as session:
            await session.execute(
                Product.__table__.update()
                .where(Product.id == stored.id)
                .values(source_image_url=f"{NEWER}?v=2")
            )
            await session.commit()
        return Image(JPEG, "image/jpeg", "jpg")

    monkeypatch.setattr(images, "fetch_image", same_photo_after_a_change)

    assert await copier().run() == ImageCopyStats()
    assert (await reload(sessions, stored)).image_key == key
    assert await storage.public.head(key) is not None


async def test_contributed_products_are_left_alone(
    sessions: Sessions,
    off: respx.MockRouter,
    copier: Callable[..., ProductImageCopier],
    storage: Storage,
) -> None:
    """Their photo comes from moderation: no source URL, and it must not be deleted."""
    key = "products/6191507220214/contribution-0123.png"
    await storage.public.put(key, PNG, content_type="image/png")
    stored = await product(
        sessions,
        ean="6191507220214",
        source=DataSource.CONTRIBUTION,
        source_image_url=None,
        image_key=key,
    )
    await product(sessions, source=DataSource.CONTRIBUTION, source_image_url=URL)
    route = off.get(URL).respond(200, content=JPEG)

    assert await copier().run() == ImageCopyStats()
    assert route.call_count == 0
    assert (await reload(sessions, stored)).image_key == key
    assert await storage.public.head(key) is not None
