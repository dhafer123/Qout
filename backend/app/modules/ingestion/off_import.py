"""Bulk import from Open Food Facts: the full export (seeding) and the daily delta files.

- Full export: rebuilt by OFF every day under the same name, so a run is identified by
  the file's ETag. Downloaded (resumably) to `import_download_dir`, imported, deleted.
- Deltas: every file listed in the index that has not been imported yet, oldest first.
  Older records never overwrite newer data (see `ProductUpserter`), so the order of
  full and delta imports does not matter.

Only products sold in `import_countries` are imported.
"""

import logging
import re
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urljoin, urlsplit

import httpx
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.config import Settings
from app.modules.ingestion.download import download, fetch_text, remote_file
from app.modules.ingestion.importer import FileImporter, ImportResult
from app.modules.ingestion.models import ImportKind
from app.modules.ingestion.off_client import RetryPolicy
from app.modules.ingestion.off_export import parse_delta_index
from app.modules.products.cache import ProductCache

logger = logging.getLogger(__name__)

_UNSAFE = re.compile(r"[^A-Za-z0-9._-]+")


@dataclass(frozen=True)
class ImportSettings:
    countries: frozenset[str]
    batch_size: int
    download_dir: Path
    export_url: str
    delta_url: str
    """Folder URL, ending with a slash."""

    @classmethod
    def from_settings(cls, settings: Settings) -> "ImportSettings":
        return cls(
            countries=settings.import_countries,
            batch_size=settings.import_batch_size,
            download_dir=settings.import_download_dir,
            export_url=str(settings.off_export_url),
            delta_url=str(settings.off_delta_url),
        )


class OffImport:
    def __init__(
        self,
        sessions: async_sessionmaker[AsyncSession],
        cache: ProductCache,
        http: httpx.AsyncClient,
        settings: ImportSettings,
        *,
        retry: RetryPolicy | None = None,
    ) -> None:
        self._http = http
        self._settings = settings
        self._retry = retry or RetryPolicy()
        self._importer = FileImporter(
            sessions, cache, countries=settings.countries, batch_size=settings.batch_size
        )

    async def import_export(self, *, force: bool = False) -> ImportResult:
        """Import the current full export (skipped if this version is already imported,
        unless `force`)."""
        remote = await remote_file(self._http, self._settings.export_url, self._retry)
        name = Path(urlsplit(self._settings.export_url).path).name
        version = (remote.etag or "").removeprefix("W/").strip('"') or f"size-{remote.size}"
        source = f"{name}@{version}"
        if not force and await self._importer.is_completed(ImportKind.FULL, source):
            logger.info("full export already imported", extra={"source": source})
            return ImportResult(ImportKind.FULL, source, status=None)

        directory = self._settings.download_dir
        dest = directory / _safe(source)
        _remove_other_versions(directory, prefix=_safe(f"{name}@"), keep=dest.name)
        if not _complete(dest, remote.size):
            logger.info("downloading full export", extra={"source": source, "bytes": remote.size})
            await download(self._http, remote.url, dest, self._retry, etag=remote.etag)
        result = await self._importer.run(ImportKind.FULL, source, dest, force=force)
        _delete(dest)
        return result

    async def import_deltas(self) -> list[ImportResult]:
        """Import every listed delta file not imported yet, oldest first."""
        index_url = urljoin(self._settings.delta_url, "index.txt")
        files = parse_delta_index(await fetch_text(self._http, index_url, self._retry))
        done = await self._importer.completed_sources(ImportKind.DELTA)
        results = []
        for delta in files:
            if delta.name in done:
                continue
            dest = self._settings.download_dir / delta.name
            if not dest.exists():  # delta files never change once published
                url = urljoin(self._settings.delta_url, delta.name)
                await download(self._http, url, dest, self._retry)
            results.append(await self._importer.run(ImportKind.DELTA, delta.name, dest))
            _delete(dest)
        logger.info("delta import finished", extra={"listed": len(files), "imported": len(results)})
        return results


def _safe(name: str) -> str:
    return _UNSAFE.sub("_", name)


def _complete(path: Path, size: int | None) -> bool:
    """A finished download of the expected size (from an earlier, failed run)."""
    return path.exists() and (size is None or path.stat().st_size == size)


def _delete(path: Path) -> None:
    path.unlink(missing_ok=True)


def _remove_other_versions(directory: Path, *, prefix: str, keep: str) -> None:
    """Old downloads of the full export (another ETag): ~14 GB each, never resumed."""
    if not directory.exists():
        return
    for path in directory.iterdir():
        if path.name.startswith(prefix) and not path.name.startswith(keep):
            logger.info("removing outdated download", extra={"file": path.name})
            path.unlink()
