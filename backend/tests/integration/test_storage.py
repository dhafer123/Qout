"""Object storage against real RustFS: objects in both buckets, and presigned uploads that
storage itself holds to the signed content type and size."""

from datetime import UTC, datetime, timedelta

import httpx
import pytest

from app.core.config import Settings
from app.core.storage import Storage, StorageError, StoredObject, media_url, open_storage

KEY = "contributions/test/photo.jpg"


@pytest.fixture
async def http() -> httpx.AsyncClient:
    async with httpx.AsyncClient(timeout=10) as client:
        yield client


async def test_put_head_and_delete(storage: Storage) -> None:
    await storage.uploads.put(KEY, b"jpeg bytes", content_type="image/jpeg")

    assert await storage.uploads.head(KEY) == StoredObject(size=10, content_type="image/jpeg")
    await storage.uploads.delete(KEY)
    assert await storage.uploads.head(KEY) is None


async def test_deleting_a_missing_object_is_fine(storage: Storage) -> None:
    await storage.uploads.delete("never/stored.jpg")


async def test_listing_by_prefix_in_key_order(storage: Storage) -> None:
    keys = ["contributions/u/c/b.jpg", "contributions/u/c/a.jpg", "contributions/v/d/c.png"]
    for key in [*keys, "products/1/front.jpg"]:
        await storage.uploads.put(key, b"x", content_type="image/jpeg")
    before = datetime.now(UTC) - timedelta(minutes=5)

    listed = [item async for page in storage.uploads.pages("contributions/") for item in page]

    assert [item.key for item in listed] == sorted(keys)
    assert all(item.last_modified > before for item in listed)  # timezone-aware
    assert [page async for page in storage.uploads.pages("nothing/")] == [[]]


async def test_buckets_are_separate(storage: Storage) -> None:
    await storage.public.put(KEY, b"x", content_type="image/jpeg")

    assert await storage.uploads.head(KEY) is None
    assert await storage.public.head(KEY) is not None


async def test_public_objects_are_readable_at_their_media_url(
    storage: Storage, make_settings: object, http: httpx.AsyncClient
) -> None:
    settings: Settings = make_settings()  # type: ignore[operator]
    await storage.public.put(
        "products/x.jpg", b"img", content_type="image/jpeg", cache_control="max-age=60"
    )
    await storage.uploads.put("products/x.jpg", b"img", content_type="image/jpeg")

    public = await http.get(media_url(settings, "products/x.jpg"))
    private = await http.get(f"{settings.s3_endpoint_url}{settings.s3_bucket}/products/x.jpg")

    assert (public.status_code, public.content) == (200, b"img")
    assert public.headers["cache-control"] == "max-age=60"
    assert private.status_code == 403


async def test_presigned_put_accepts_the_declared_upload(
    storage: Storage, http: httpx.AsyncClient
) -> None:
    url = await storage.uploads.presign_put(
        KEY, content_type="image/jpeg", content_length=5, expires_in=60
    )

    response = await http.put(url, content=b"12345", headers={"Content-Type": "image/jpeg"})

    assert response.status_code == 200
    assert await storage.uploads.head(KEY) == StoredObject(size=5, content_type="image/jpeg")


@pytest.mark.parametrize(
    ("content", "headers"),
    [
        pytest.param(b"12345", {"Content-Type": "image/png"}, id="other-content-type"),
        pytest.param(b"12345", {"Content-Type": "text/html"}, id="html"),
        pytest.param(b"12345", {}, id="no-content-type"),
        pytest.param(b"123456", {"Content-Type": "image/jpeg"}, id="larger"),
        pytest.param(b"1234", {"Content-Type": "image/jpeg"}, id="smaller"),
    ],
)
async def test_presigned_put_rejects_another_type_or_size(
    storage: Storage, http: httpx.AsyncClient, content: bytes, headers: dict[str, str]
) -> None:
    url = await storage.uploads.presign_put(
        KEY, content_type="image/jpeg", content_length=5, expires_in=60
    )

    response = await http.put(url, content=content, headers=headers)

    assert response.status_code == 403
    assert await storage.uploads.head(KEY) is None


async def test_presigned_url_is_only_for_put(storage: Storage, http: httpx.AsyncClient) -> None:
    url = await storage.uploads.presign_put(
        KEY, content_type="image/jpeg", content_length=5, expires_in=60
    )
    await storage.uploads.put(KEY, b"12345", content_type="image/jpeg")

    assert (await http.get(url)).status_code == 403


async def test_presigned_urls_use_the_public_endpoint(
    make_settings: object,
) -> None:
    settings: Settings = make_settings(  # type: ignore[operator]
        s3_public_endpoint_url="http://192.168.1.20:9000"
    )
    async with open_storage(settings) as opened:
        url = await opened.uploads.presign_put(
            KEY, content_type="image/jpeg", content_length=5, expires_in=60
        )

    assert url.startswith(f"http://192.168.1.20:9000/{settings.s3_bucket}/{KEY}?")


async def test_storage_down_raises_storage_error(make_settings: object) -> None:
    settings: Settings = make_settings(s3_endpoint_url="http://127.0.0.1:1")  # type: ignore[operator]
    async with open_storage(settings) as opened:
        with pytest.raises(StorageError):
            await opened.uploads.put(KEY, b"x", content_type="image/jpeg")
        with pytest.raises(StorageError):
            await opened.uploads.head(KEY)
        with pytest.raises(StorageError):
            await opened.uploads.delete(KEY)
        with pytest.raises(StorageError):
            await anext(opened.uploads.pages(""))


async def test_refused_credentials_raise_storage_error(make_settings: object) -> None:
    settings: Settings = make_settings(s3_secret_key="not-the-secret-key")  # type: ignore[operator]
    async with open_storage(settings) as opened:
        with pytest.raises(StorageError):
            await opened.uploads.head(KEY)


async def test_copy_between_buckets(storage: Storage) -> None:
    await storage.uploads.put(KEY, b"photo", content_type="image/jpeg")

    await storage.public.copy_from(
        storage.uploads, KEY, "products/x.jpg", content_type="image/png", cache_control="no-cache"
    )

    assert await storage.public.head("products/x.jpg") == StoredObject(5, "image/png")
    assert await storage.uploads.head(KEY) is not None  # the source stays


async def test_copying_a_missing_object_raises_storage_error(storage: Storage) -> None:
    with pytest.raises(StorageError):
        await storage.public.copy_from(
            storage.uploads, "missing.jpg", "x.jpg", content_type="image/jpeg", cache_control="x"
        )
