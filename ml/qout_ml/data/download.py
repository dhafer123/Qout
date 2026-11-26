"""Download pinned files: checksum verified, retried on transport errors, never half-written."""

import hashlib
import logging
import time
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

import httpx

logger = logging.getLogger(__name__)

CHUNK_BYTES = 1 << 20
RETRYABLE_STATUS = frozenset({408, 429, 500, 502, 503, 504})


@dataclass(frozen=True)
class RemoteFile:
    """A file to fetch, pinned by SHA-256 or MD5 (hex) and optionally by size."""

    url: str
    name: str
    sha256: str | None = None
    md5: str | None = None
    size: int | None = None

    def __post_init__(self) -> None:
        if self.sha256 is None and self.md5 is None:
            msg = f"{self.name}: a checksum (sha256 or md5) is required"
            raise ValueError(msg)
        if Path(self.name).is_absolute() or ".." in Path(self.name).parts:
            msg = f"{self.name}: must be a relative path inside the destination"
            raise ValueError(msg)


class DownloadError(Exception):
    """The file could not be fetched (after retries) or did not match its checksum."""


def _digests(path: Path) -> tuple[str, str, int]:
    sha256 = hashlib.sha256()
    md5 = hashlib.md5(usedforsecurity=False)
    size = 0
    with path.open("rb") as handle:
        while chunk := handle.read(CHUNK_BYTES):
            sha256.update(chunk)
            md5.update(chunk)
            size += len(chunk)
    return sha256.hexdigest(), md5.hexdigest(), size


def matches(path: Path, remote: RemoteFile) -> bool:
    """True if the file on disk is exactly the pinned one."""
    if not path.is_file():
        return False
    sha256, md5, size = _digests(path)
    return (
        (remote.size is None or size == remote.size)
        and (remote.sha256 is None or sha256 == remote.sha256)
        and (remote.md5 is None or md5 == remote.md5)
    )


def _fetch_once(client: httpx.Client, remote: RemoteFile, part: Path) -> None:
    with client.stream("GET", remote.url) as response:
        response.raise_for_status()
        with part.open("wb") as handle:
            for chunk in response.iter_bytes(CHUNK_BYTES):
                handle.write(chunk)


def _retryable(error: httpx.HTTPError) -> bool:
    if isinstance(error, httpx.HTTPStatusError):
        return error.response.status_code in RETRYABLE_STATUS
    return isinstance(error, httpx.TransportError)


def download(
    client: httpx.Client,
    remote: RemoteFile,
    dest_dir: Path,
    *,
    attempts: int = 3,
    sleep: Callable[[float], None] = time.sleep,
) -> Path:
    """Fetch `remote` into `dest_dir / remote.name` and return its path.

    A file already there with the right checksum is kept. The download goes to a
    `.part` file that only replaces the target once its checksum matches. Transport
    errors and 408/429/5xx are retried with a growing pause; a wrong checksum is not
    (the server sent a different file, not a broken one).
    """
    target = dest_dir / remote.name
    if matches(target, remote):
        logger.info("%s: already downloaded", remote.name)
        return target

    target.parent.mkdir(parents=True, exist_ok=True)
    part = target.with_name(target.name + ".part")
    for attempt in range(1, attempts + 1):
        try:
            _fetch_once(client, remote, part)
        except httpx.HTTPError as error:
            part.unlink(missing_ok=True)
            if not _retryable(error) or attempt == attempts:
                msg = f"{remote.name}: download failed ({error})"
                raise DownloadError(msg) from error
            logger.warning("%s: attempt %d failed (%s), retrying", remote.name, attempt, error)
            sleep(2.0 ** (attempt - 1))
            continue
        if not matches(part, remote):
            part.unlink()
            msg = f"{remote.name}: checksum or size does not match the pinned value"
            raise DownloadError(msg)
        part.replace(target)
        logger.info("%s: downloaded", remote.name)
        return target
    raise AssertionError("unreachable")  # pragma: no cover


def download_all(
    client: httpx.Client,
    remotes: list[RemoteFile],
    dest_dir: Path,
    *,
    sleep: Callable[[float], None] = time.sleep,
) -> list[Path]:
    """Fetch every file in order; stops at the first failure."""
    return [download(client, remote, dest_dir, sleep=sleep) for remote in remotes]
