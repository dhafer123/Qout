"""Resumable bulk downloads; HTTP mocked with respx."""

from collections.abc import AsyncIterator, Iterator
from pathlib import Path

import httpx
import pytest
import respx

from app.core.config import Settings
from app.modules.ingestion.download import (
    DownloadError,
    download,
    download_client,
    fetch_text,
    remote_file,
)
from app.modules.ingestion.off_client import RetryPolicy

URL = "https://static.off.test/data/export.jsonl.gz"
DATA = bytes(range(256)) * 40  # 10 240 bytes
ETAG = '"abc-1"'


class Sleeps:
    def __init__(self) -> None:
        self.calls: list[float] = []

    async def __call__(self, seconds: float) -> None:
        self.calls.append(seconds)


@pytest.fixture
def sleeps() -> Sleeps:
    return Sleeps()


@pytest.fixture
def retry(sleeps: Sleeps) -> RetryPolicy:
    return RetryPolicy(max_retries=2, backoff_base_seconds=1, sleep=sleeps, jitter=lambda: 0.5)


@pytest.fixture
def router() -> Iterator[respx.MockRouter]:
    with respx.mock(assert_all_called=False) as mock:
        yield mock


@pytest.fixture
async def http() -> AsyncIterator[httpx.AsyncClient]:
    async with httpx.AsyncClient(follow_redirects=True) as client:
        yield client


class BrokenStream(httpx.AsyncByteStream):
    """Sends `data`, then the connection drops."""

    def __init__(self, data: bytes) -> None:
        self._data = data

    async def __aiter__(self) -> AsyncIterator[bytes]:
        yield self._data
        raise httpx.RemoteProtocolError("peer closed connection")


def ranged(request: httpx.Request) -> httpx.Response:
    """A server with range support for DATA."""
    header = request.headers.get("Range")
    if header is None:
        return httpx.Response(200, content=DATA, headers={"ETag": ETAG})
    start = int(header.removeprefix("bytes=").removesuffix("-"))
    if start >= len(DATA):
        return httpx.Response(416, headers={"Content-Range": f"bytes */{len(DATA)}"})
    body = DATA[start:]
    content_range = f"bytes {start}-{len(DATA) - 1}/{len(DATA)}"
    return httpx.Response(206, content=body, headers={"Content-Range": content_range})


def partial(tmp_path: Path, size: int, data: bytes = DATA) -> Path:
    dest = tmp_path / "export.jsonl.gz"
    (tmp_path / "export.jsonl.gz.part").write_bytes(data[:size])
    return dest


# ---------------------------------------------------------------- download


async def test_fresh_download(
    tmp_path: Path, router: respx.MockRouter, http: httpx.AsyncClient, retry: RetryPolicy
) -> None:
    route = router.get(URL).mock(side_effect=ranged)
    dest = tmp_path / "sub" / "export.jsonl.gz"

    assert await download(http, URL, dest, retry) == dest

    assert dest.read_bytes() == DATA
    assert not (tmp_path / "sub" / "export.jsonl.gz.part").exists()
    assert "Range" not in route.calls.last.request.headers


async def test_resumes_a_partial_download(
    tmp_path: Path, router: respx.MockRouter, http: httpx.AsyncClient, retry: RetryPolicy
) -> None:
    route = router.get(URL).mock(side_effect=ranged)
    dest = partial(tmp_path, 4000)

    await download(http, URL, dest, retry, etag=ETAG)

    assert dest.read_bytes() == DATA
    request = route.calls.last.request
    assert (request.headers["Range"], request.headers["If-Range"]) == ("bytes=4000-", ETAG)


async def test_resume_without_etag_sends_no_if_range(
    tmp_path: Path, router: respx.MockRouter, http: httpx.AsyncClient, retry: RetryPolicy
) -> None:
    route = router.get(URL).mock(side_effect=ranged)
    await download(http, URL, partial(tmp_path, 10), retry)
    assert "If-Range" not in route.calls.last.request.headers


async def test_server_without_range_support_starts_over(
    tmp_path: Path, router: respx.MockRouter, http: httpx.AsyncClient, retry: RetryPolicy
) -> None:
    router.get(URL).respond(200, content=DATA)  # also what If-Range does for a changed file
    dest = partial(tmp_path, 4000, data=b"x" * 4000)

    await download(http, URL, dest, retry, etag=ETAG)

    assert dest.read_bytes() == DATA


async def test_complete_partial_file_is_kept(
    tmp_path: Path, router: respx.MockRouter, http: httpx.AsyncClient, retry: RetryPolicy
) -> None:
    router.get(URL).mock(side_effect=ranged)
    dest = partial(tmp_path, len(DATA))
    await download(http, URL, dest, retry)
    assert dest.read_bytes() == DATA


async def test_partial_file_larger_than_remote_starts_over(
    tmp_path: Path, router: respx.MockRouter, http: httpx.AsyncClient, retry: RetryPolicy
) -> None:
    router.get(URL).mock(side_effect=ranged)
    dest = partial(tmp_path, len(DATA) + 10, data=DATA + b"0123456789")

    await download(http, URL, dest, retry)

    assert dest.read_bytes() == DATA


async def test_unexpected_range_starts_over(
    tmp_path: Path, router: respx.MockRouter, http: httpx.AsyncClient, retry: RetryPolicy
) -> None:
    wrong = httpx.Response(206, content=DATA, headers={"Content-Range": "bytes 0-10239/10240"})
    router.get(URL).mock(side_effect=[wrong, httpx.Response(200, content=DATA)])
    dest = partial(tmp_path, 4000)

    await download(http, URL, dest, retry)

    assert dest.read_bytes() == DATA


async def test_dropped_connection_resumes_where_it_stopped(
    tmp_path: Path,
    router: respx.MockRouter,
    http: httpx.AsyncClient,
    retry: RetryPolicy,
    sleeps: Sleeps,
) -> None:
    # Three drops in a row: more than max_retries, but each one made progress.
    responses = [
        httpx.Response(200, stream=BrokenStream(DATA[:1000])),
        httpx.Response(
            206,
            stream=BrokenStream(DATA[1000:2000]),
            headers={"Content-Range": "bytes 1000-10239/10240"},
        ),
        httpx.Response(
            206,
            stream=BrokenStream(DATA[2000:3000]),
            headers={"Content-Range": "bytes 2000-10239/10240"},
        ),
    ]
    rest = httpx.Response(
        206, content=DATA[3000:], headers={"Content-Range": "bytes 3000-10239/10240"}
    )
    route = router.get(URL).mock(side_effect=[*responses, rest])
    dest = tmp_path / "export.jsonl.gz"

    await download(http, URL, dest, retry)

    assert dest.read_bytes() == DATA
    assert route.call_count == 4
    assert sleeps.calls == [1.0, 1.0, 1.0]  # progress resets the backoff


async def test_server_errors_are_retried(
    tmp_path: Path,
    router: respx.MockRouter,
    http: httpx.AsyncClient,
    retry: RetryPolicy,
    sleeps: Sleeps,
) -> None:
    router.get(URL).mock(
        side_effect=[
            httpx.Response(503),
            httpx.ConnectError("refused"),
            httpx.Response(200, content=DATA),
        ]
    )
    dest = tmp_path / "export.jsonl.gz"
    await download(http, URL, dest, retry)
    assert dest.read_bytes() == DATA
    assert sleeps.calls == [1.0, 2.0]


async def test_gives_up_after_the_retries(
    tmp_path: Path, router: respx.MockRouter, http: httpx.AsyncClient, retry: RetryPolicy
) -> None:
    route = router.get(URL).respond(502)
    with pytest.raises(DownloadError, match="HTTP 502"):
        await download(http, URL, tmp_path / "export.jsonl.gz", retry)
    assert route.call_count == 3


async def test_rejection_is_not_retried(
    tmp_path: Path, router: respx.MockRouter, http: httpx.AsyncClient, retry: RetryPolicy
) -> None:
    route = router.get(URL).respond(403)
    with pytest.raises(DownloadError, match="HTTP 403"):
        await download(http, URL, tmp_path / "export.jsonl.gz", retry)
    assert route.call_count == 1


# ---------------------------------------------------------------- small requests


async def test_remote_file_follows_redirects(
    router: respx.MockRouter, http: httpx.AsyncClient, retry: RetryPolicy
) -> None:
    s3 = "https://bucket.s3.test/export.jsonl.gz"
    router.head(URL).respond(302, headers={"Location": s3})
    router.head(s3).respond(200, headers={"ETag": ETAG, "Content-Length": "13591123373"})

    remote = await remote_file(http, URL, retry)

    assert (remote.url, remote.size, remote.etag) == (s3, 13591123373, ETAG)


async def test_remote_file_without_headers(
    router: respx.MockRouter, http: httpx.AsyncClient, retry: RetryPolicy
) -> None:
    router.head(URL).respond(200)
    remote = await remote_file(http, URL, retry)
    assert (remote.size, remote.etag) == (None, None)


async def test_fetch_text_retries_then_fails(
    router: respx.MockRouter, http: httpx.AsyncClient, retry: RetryPolicy, sleeps: Sleeps
) -> None:
    index = "https://static.off.test/data/delta/index.txt"
    router.get(index).mock(
        side_effect=[httpx.ReadTimeout("slow"), httpx.Response(200, text="a\nb\n")]
    )
    assert await fetch_text(http, index, retry) == "a\nb\n"

    router.get(index).respond(500)
    with pytest.raises(DownloadError, match="after 3 attempts: HTTP 500"):
        await fetch_text(http, index, retry)

    router.get(index).respond(404)
    with pytest.raises(DownloadError, match="HTTP 404"):
        await fetch_text(http, index, retry)


async def test_download_client_identifies_qout(router: respx.MockRouter) -> None:
    route = router.get(URL).respond(200)
    settings = Settings(
        _env_file=None, database_url="postgresql+asyncpg://u:p@h/d", redis_url="redis://h"
    )  # type: ignore[call-arg]
    async with download_client(settings) as client:
        await client.get(URL)
    assert route.calls.last.request.headers["User-Agent"] == settings.off_user_agent
    assert client.follow_redirects
