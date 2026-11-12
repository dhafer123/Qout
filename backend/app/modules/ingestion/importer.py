"""Import one downloaded Open Food Facts file (full export or delta) into our database.

- Resumable: the file is read in chunks; after each chunk (and every `batch_size`
  products) the products and the run's checkpoint are committed together. A new run of
  the same file and countries continues after the checkpoint; lines after it may have
  been half-done, which is harmless because the upsert is idempotent.
- One bad product never stops an import: it is rolled back on its own and counted.
- Progress is logged after every commit; counters are kept on the `import_runs` row.
- Cached lookups of changed products are invalidated after each commit.

Reading and decompressing the file is blocking, so it runs in a worker thread.
"""

import asyncio
import itertools
import logging
from collections.abc import Iterator
from dataclasses import asdict, dataclass, fields
from datetime import UTC, datetime
from pathlib import Path

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.modules.ingestion.models import ImportKind, ImportRun, ImportStatus
from app.modules.ingestion.off_export import ParsedLine, Rejected, Selected, read_lines, scan
from app.modules.ingestion.off_normaliser import normalize
from app.modules.ingestion.repository import ImportRunRepository
from app.modules.products.cache import ProductCache
from app.modules.products.upsert import ProductUpserter, UpsertOutcome

logger = logging.getLogger(__name__)

CHUNK_LINES = 10_000
"""Lines read per thread hop; also the most lines between two checkpoints."""
_ERROR_CHARS = 2000
_COUNTER = {
    UpsertOutcome.INSERTED: "inserted",
    UpsertOutcome.UPDATED: "updated",
    UpsertOutcome.UNCHANGED: "unchanged",
    UpsertOutcome.NOT_FROM_OFF: "skipped",
    UpsertOutcome.STALE: "skipped",
}


@dataclass
class ImportStats:
    """Counters of a run (see `ImportRun`)."""

    lines: int = 0
    selected: int = 0
    inserted: int = 0
    updated: int = 0
    unchanged: int = 0
    skipped: int = 0
    rejected: int = 0
    failed: int = 0

    @classmethod
    def of(cls, run: ImportRun) -> "ImportStats":
        return cls(**{f.name: getattr(run, f.name) for f in fields(cls)})

    def write_to(self, run: ImportRun) -> None:
        for name, value in asdict(self).items():
            setattr(run, name, value)

    def count(self, outcome: UpsertOutcome) -> None:
        name = _COUNTER[outcome]
        setattr(self, name, getattr(self, name) + 1)


@dataclass(frozen=True)
class ImportResult:
    """What a run did; returned by the worker jobs."""

    kind: ImportKind
    source: str
    status: ImportStatus | None
    """None: the file had already been imported, nothing was done."""
    resumed_from_line: int = 0
    stats: ImportStats | None = None


class FileImporter:
    def __init__(
        self,
        sessions: async_sessionmaker[AsyncSession],
        cache: ProductCache,
        *,
        countries: frozenset[str],
        batch_size: int,
    ) -> None:
        self._sessions = sessions
        self._cache = cache
        self._countries = countries
        self._batch_size = batch_size

    async def is_completed(self, kind: ImportKind, source: str) -> bool:
        async with self._sessions() as session:
            run = await ImportRunRepository(session).latest(kind, source, self._countries)
            return run is not None and run.status == ImportStatus.COMPLETED

    async def completed_sources(self, kind: ImportKind) -> set[str]:
        async with self._sessions() as session:
            return await ImportRunRepository(session).completed_sources(kind, self._countries)

    async def run(
        self, kind: ImportKind, source: str, path: Path, *, force: bool = False
    ) -> ImportResult:
        """Import `path`, resuming an unfinished run of the same file. A completed file is
        not imported again unless `force` (which starts a new run from the top)."""
        run = await self._start(kind, source, force=force)
        if run is None:
            return ImportResult(kind, source, status=None)
        started_at = run.checkpoint_line
        stats = ImportStats.of(run)
        logger.info(
            "import started",
            extra={"kind": kind, "source": source, "resume_from_line": started_at},
        )
        try:
            await self._import(run, path, stats)
        except BaseException as error:
            await self._finish(run, ImportStatus.FAILED, error=repr(error)[:_ERROR_CHARS])
            logger.exception("import failed", extra={"kind": kind, "source": source})
            raise
        await self._finish(run, ImportStatus.COMPLETED)
        logger.info("import completed", extra={"kind": kind, "source": source, **asdict(stats)})
        return ImportResult(kind, source, ImportStatus.COMPLETED, started_at, stats)

    # ------------------------------------------------------------ run bookkeeping

    async def _start(self, kind: ImportKind, source: str, *, force: bool) -> ImportRun | None:
        async with self._sessions() as session:
            runs = ImportRunRepository(session)
            run = await runs.latest(kind, source, self._countries)
            if run is not None and run.status == ImportStatus.COMPLETED and not force:
                return None
            if run is None or run.status == ImportStatus.COMPLETED:
                run = await runs.add(
                    ImportRun(
                        kind=kind,
                        source=source,
                        countries=sorted(self._countries),
                        status=ImportStatus.RUNNING,
                        checkpoint_line=0,
                        **asdict(ImportStats()),
                    )
                )
            else:  # running (interrupted) or failed: resume
                run.status, run.error = ImportStatus.RUNNING, None
            await session.commit()
            return run

    async def _finish(
        self, run: ImportRun, status: ImportStatus, *, error: str | None = None
    ) -> None:
        async with self._sessions() as session:
            stored = await ImportRunRepository(session).get(run.id)
            if stored is None:  # pragma: no cover - deleted while running
                return
            stored.status, stored.error = status, error
            stored.finished_at = datetime.now(UTC)
            await session.commit()

    # ------------------------------------------------------------ the file

    async def _import(self, run: ImportRun, path: Path, stats: ImportStats) -> None:
        lines = scan(read_lines(path), self._countries, start_line=run.checkpoint_line)
        while chunk := await asyncio.to_thread(_take, lines, CHUNK_LINES):
            batch: list[tuple[int, Selected]] = []
            for number, parsed in chunk:
                stats.lines += 1
                if isinstance(parsed, Rejected):
                    stats.rejected += 1
                    logger.warning(
                        "unusable line in OFF file",
                        extra={"source": run.source, "line": number, "reason": parsed.reason},
                    )
                elif parsed is not None:
                    batch.append((number, parsed))
                    if len(batch) >= self._batch_size:
                        await self._commit(run, batch, stats, checkpoint=number)
                        batch = []
            await self._commit(run, batch, stats, checkpoint=chunk[-1][0])

    async def _commit(
        self,
        run: ImportRun,
        batch: list[tuple[int, Selected]],
        stats: ImportStats,
        *,
        checkpoint: int,
    ) -> None:
        """Store `batch` and move the checkpoint, in one transaction."""
        changed: list[str] = []
        async with self._sessions() as session:
            upserter = ProductUpserter(session)
            for number, item in batch:
                stats.selected += 1
                try:
                    async with session.begin_nested():
                        result = await upserter.upsert(normalize(item.ean, item.product))
                except Exception:
                    stats.failed += 1
                    logger.exception(
                        "product import failed",
                        extra={"source": run.source, "line": number, "ean": item.ean},
                    )
                    continue
                stats.count(result.outcome)
                if result.changed:
                    changed.append(item.ean)
            stored = await ImportRunRepository(session).get(run.id)
            if stored is None:  # pragma: no cover - deleted while running
                raise RuntimeError(f"import run {run.id} disappeared")
            stats.write_to(stored)
            stored.checkpoint_line = run.checkpoint_line = checkpoint
            await session.commit()
        for ean in changed:  # after commit, so a lookup can't re-cache the old data
            await self._cache.invalidate(ean)
        logger.info(
            "import progress",
            extra={"source": run.source, "checkpoint_line": checkpoint, **asdict(stats)},
        )


def _take(lines: Iterator[tuple[int, ParsedLine]], count: int) -> list[tuple[int, ParsedLine]]:
    return list(itertools.islice(lines, count))
