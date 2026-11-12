"""Resumable downloads of Open Food Facts bulk files.

Files are written to `<dest>.part` and renamed when complete. An interrupted download
continues from the bytes already on disk with an HTTP `Range` request; `If-Range` (the
file's ETag) makes the server send the whole file again if it changed in the meantime.
Timeouts, connection errors (including a body cut short), 429 and 5xx are retried with
backoff; the retry budget starts over whenever a retry made progress.
"""

import logging
import re
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from pathlib import Path

import httpx

from app.core.config import Settings
from app.modules.ingestion.off_client import RetryPolicy

logger = logging.getLogger(__name__)

_RETRY_STATUSES = frozenset({429, 500, 502, 503, 504})
_CONTENT_RANGE = re.compile(r"^bytes (?:(\d+)-\d+|\*)/(\d+|\*)$")
_CONNECT_TIMEOUT_SECONDS = 10.0
_READ_TIMEOUT_SECONDS = 60.0


class DownloadError(Exception):
    """The file could not be downloaded (rejected, or still failing after retries)."""


class _RetryableError(Exception):
    pass


@dataclass(frozen=True)
class RemoteFile:
    url: str
    """After redirects."""
    size: int | None
    etag: str | None


def download_client(settings: Settings) -> httpx.AsyncClient:
    """HTTP client for bulk files: OFF's User-Agent, redirects followed (to S3)."""
    return httpx.AsyncClient(
        headers={"User-Agent": settings.off_user_agent},
        follow_redirects=True,
        timeout=httpx.Timeout(_READ_TIMEOUT_SECONDS, connect=_CONNECT_TIMEOUT_SECONDS),
    )


async def remote_file(http: httpx.AsyncClient, url: str, retry: RetryPolicy) -> RemoteFile:
    """Size and ETag of `url` (HEAD request)."""
    response = await _with_retries(lambda: http.head(url), url, retry)
    length = response.headers.get("Content-Length")
    return RemoteFile(
        url=str(response.url),
        size=int(length) if length is not None and length.isdigit() else None,
        etag=response.headers.get("ETag"),
    )


async def fetch_text(http: httpx.AsyncClient, url: str, retry: RetryPolicy) -> str:
    """A small text file (e.g. the delta index)."""
    response = await _with_retries(lambda: http.get(url), url, retry)
    return response.text


async def download(
    http: httpx.AsyncClient,
    url: str,
    dest: Path,
    retry: RetryPolicy,
    *,
    etag: str | None = None,
) -> Path:
    """Download `url` to `dest`, resuming a previous partial download if there is one."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    part = dest.with_name(dest.name + ".part")
    attempt = 0
    while True:
        offset = _size(part)
        try:
            await _fetch(http, url, part, offset, etag)
        except (httpx.TransportError, _RetryableError) as error:
            attempt = 0 if _size(part) > offset else attempt  # progress: a fresh budget
            if attempt >= retry.max_retries:
                raise DownloadError(f"download of {url} failed: {error!r}") from error
            logger.warning(
                "download interrupted, retrying", extra={"url": url, "bytes": _size(part)}
            )
            await retry.sleep(retry.backoff(attempt))
            attempt += 1
            continue
        part.replace(dest)
        return dest


async def _fetch(
    http: httpx.AsyncClient, url: str, part: Path, offset: int, etag: str | None
) -> None:
    headers = {}
    if offset:
        headers["Range"] = f"bytes={offset}-"
        if etag:
            headers["If-Range"] = etag
    async with http.stream("GET", url, headers=headers) as response:
        status = response.status_code
        if status == httpx.codes.REQUESTED_RANGE_NOT_SATISFIABLE and offset:
            if _total_size(response) == offset:
                return  # already complete
            _discard(part)
            raise _RetryableError("partial file does not match the remote file")
        if status in _RETRY_STATUSES:
            raise _RetryableError(f"HTTP {status}")
        if status == httpx.codes.PARTIAL_CONTENT:
            if _range_start(response) != offset:
                _discard(part)
                raise _RetryableError("server sent an unexpected range")
            mode = "ab"
        elif status == httpx.codes.OK:
            mode = "wb"  # no range support, or the file changed: start over
        else:
            raise DownloadError(f"{url}: HTTP {status}")
        with part.open(mode) as file:
            # Unbuffered: every byte received is on disk if the connection drops.
            async for chunk in response.aiter_bytes():
                file.write(chunk)


def _size(path: Path) -> int:
    return path.stat().st_size if path.exists() else 0


def _discard(path: Path) -> None:
    path.unlink(missing_ok=True)


def _range_start(response: httpx.Response) -> int | None:
    match = _CONTENT_RANGE.match(response.headers.get("Content-Range", ""))
    return int(match[1]) if match is not None and match[1] is not None else None


def _total_size(response: httpx.Response) -> int | None:
    match = _CONTENT_RANGE.match(response.headers.get("Content-Range", ""))
    return int(match[2]) if match is not None and match[2] != "*" else None


async def _with_retries(
    send: Callable[[], Awaitable[httpx.Response]], url: str, retry: RetryPolicy
) -> httpx.Response:
    attempt = 0
    while True:
        try:
            response = await send()
        except httpx.TransportError as error:
            failure = repr(error)
        else:
            if response.status_code not in _RETRY_STATUSES:
                if response.is_error:
                    raise DownloadError(f"{url}: HTTP {response.status_code}")
                return response
            failure = f"HTTP {response.status_code}"
        if attempt >= retry.max_retries:
            raise DownloadError(f"{url} failed after {attempt + 1} attempts: {failure}")
        await retry.sleep(retry.backoff(attempt))
        attempt += 1
