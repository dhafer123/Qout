"""Full-export and delta imports end to end: OFF's static files mocked with respx."""

from collections.abc import AsyncIterator, Callable, Iterator
from pathlib import Path

import httpx
import pytest
import respx
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.modules.ingestion.importer import ImportStats
from app.modules.ingestion.models import ImportKind, ImportRun, ImportStatus
from app.modules.ingestion.off_client import RetryPolicy
from app.modules.ingestion.off_import import ImportSettings, OffImport
from app.modules.products.cache import ProductCache
from app.modules.products.models import NutritionFacts, Product
from tests.integration.ingestion.conftest import (
    NUTELLA,
    TUNISIA,
    TUNISIAN,
    edit_product,
    export_lines,
)

Sessions = async_sessionmaker[AsyncSession]
EXPORT_URL = "https://static.off.test/data/openfoodfacts-products.jsonl.gz"
S3_URL = "https://bucket.s3.test/openfoodfacts-products.jsonl.gz"
DELTA_URL = "https://static.off.test/data/delta/"
DELTA_1 = "openfoodfacts_products_1000_2000.json.gz"
DELTA_2 = "openfoodfacts_products_2000_3000.json.gz"


async def no_sleep(_: float) -> None:
    return None


@pytest.fixture
def router() -> Iterator[respx.MockRouter]:
    with respx.mock(assert_all_called=False) as mock:
        yield mock


@pytest.fixture
async def http() -> AsyncIterator[httpx.AsyncClient]:
    async with httpx.AsyncClient(follow_redirects=True) as client:
        yield client


@pytest.fixture
def download_dir(tmp_path: Path) -> Path:
    return tmp_path / "downloads"


@pytest.fixture
def off_import(
    sessions: Sessions, cache: ProductCache, http: httpx.AsyncClient, download_dir: Path
) -> OffImport:
    settings = ImportSettings(
        countries=TUNISIA,
        batch_size=500,
        download_dir=download_dir,
        export_url=EXPORT_URL,
        delta_url=DELTA_URL,
    )
    return OffImport(
        sessions, cache, http, settings, retry=RetryPolicy(max_retries=1, sleep=no_sleep)
    )


@pytest.fixture
def gz_bytes(write_gz: Callable[..., Path]) -> Callable[[list[str]], bytes]:
    return lambda lines: write_gz(lines, "served.gz").read_bytes()


def serve_export(router: respx.MockRouter, body: bytes, etag: str) -> respx.Route:
    router.head(EXPORT_URL).respond(302, headers={"Location": S3_URL})
    router.head(S3_URL).respond(200, headers={"ETag": etag, "Content-Length": str(len(body))})
    return router.get(S3_URL).respond(200, content=body)


def files_in(directory: Path) -> list[str]:
    return sorted(p.name for p in directory.iterdir()) if directory.exists() else []


def write_files(directory: Path, files: dict[str, bytes]) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    for name, body in files.items():
        (directory / name).write_bytes(body)


async def count(sessions: Sessions, model: type[object]) -> int:
    async with sessions() as session:
        return await session.scalar(select(func.count()).select_from(model)) or 0


async def run_sources(sessions: Sessions) -> list[tuple[str, str, ImportStatus]]:
    async with sessions() as session:
        result = await session.execute(
            select(ImportRun.kind, ImportRun.source, ImportRun.status).order_by(
                ImportRun.created_at
            )
        )
        return [tuple(row) for row in result.all()]  # type: ignore[misc]


# ---------------------------------------------------------------- full export


async def test_full_export_is_downloaded_imported_and_deleted(
    off_import: OffImport,
    router: respx.MockRouter,
    sessions: Sessions,
    download_dir: Path,
    gz_bytes: Callable[[list[str]], bytes],
) -> None:
    serve_export(router, gz_bytes(export_lines()), '"abc-811"')

    result = await off_import.import_export()

    assert (result.kind, result.source, result.status) == (
        ImportKind.FULL,
        "openfoodfacts-products.jsonl.gz@abc-811",
        ImportStatus.COMPLETED,
    )
    assert result.stats is not None
    assert result.stats.inserted == len(TUNISIAN)
    assert files_in(download_dir) == []


async def test_same_export_version_is_not_downloaded_again(
    off_import: OffImport, router: respx.MockRouter, gz_bytes: Callable[[list[str]], bytes]
) -> None:
    get = serve_export(router, gz_bytes(export_lines()), '"abc-811"')
    await off_import.import_export()

    again = await off_import.import_export()

    assert (again.status, get.call_count) == (None, 1)


async def test_new_export_version_is_imported_and_rescored(
    off_import: OffImport,
    router: respx.MockRouter,
    sessions: Sessions,
    gz_bytes: Callable[[list[str]], bytes],
) -> None:
    lines = export_lines()
    serve_export(router, gz_bytes(lines), '"v1"')
    await off_import.import_export()
    facts_before = await count(sessions, NutritionFacts)
    edited = edit_product(lines, NUTELLA, nutriments={"sugars_100g": 10})
    serve_export(router, gz_bytes(edited), 'W/"v2"')

    result = await off_import.import_export()

    assert result.source == "openfoodfacts-products.jsonl.gz@v2"
    assert result.stats is not None
    assert (result.stats.updated, result.stats.unchanged) == (1, 4)
    assert await count(sessions, Product) == len(TUNISIAN)
    assert await count(sessions, NutritionFacts) == facts_before + 1  # Nutella v2


async def test_force_imports_the_same_version_again(
    off_import: OffImport, router: respx.MockRouter, gz_bytes: Callable[[list[str]], bytes]
) -> None:
    get = serve_export(router, gz_bytes(export_lines()), '"v1"')
    await off_import.import_export()

    forced = await off_import.import_export(force=True)

    assert get.call_count == 2
    assert forced.stats is not None
    assert forced.stats.unchanged == len(TUNISIAN)


async def test_downloaded_file_from_a_failed_run_is_reused(
    off_import: OffImport,
    router: respx.MockRouter,
    download_dir: Path,
    gz_bytes: Callable[[list[str]], bytes],
) -> None:
    body = gz_bytes(export_lines())
    get = serve_export(router, body, '"v1"')
    write_files(
        download_dir,
        {
            "openfoodfacts-products.jsonl.gz_v1": body,  # complete, from a failed run
            "openfoodfacts-products.jsonl.gz_v0.part": b"old export",
            DELTA_1: b"unrelated",
        },
    )

    result = await off_import.import_export()

    assert result.status == ImportStatus.COMPLETED
    assert get.call_count == 0
    assert files_in(download_dir) == [DELTA_1]  # the outdated export version is removed


async def test_export_without_etag_is_identified_by_size(
    off_import: OffImport, router: respx.MockRouter, gz_bytes: Callable[[list[str]], bytes]
) -> None:
    body = gz_bytes(export_lines())
    router.head(EXPORT_URL).respond(200, headers={"Content-Length": str(len(body))})
    router.get(EXPORT_URL).respond(200, content=body)

    result = await off_import.import_export()

    assert result.source == f"openfoodfacts-products.jsonl.gz@size-{len(body)}"


# ---------------------------------------------------------------- deltas


def serve_deltas(router: respx.MockRouter, files: dict[str, bytes]) -> dict[str, respx.Route]:
    index = "\n".join(files) + "\n"
    router.get(f"{DELTA_URL}index.txt").respond(200, text=index)
    return {
        name: router.get(f"{DELTA_URL}{name}").respond(200, content=body)
        for name, body in files.items()
    }


async def test_new_delta_files_are_imported_oldest_first(
    off_import: OffImport,
    router: respx.MockRouter,
    sessions: Sessions,
    download_dir: Path,
    gz_bytes: Callable[[list[str]], bytes],
) -> None:
    lines = export_lines()
    newer = edit_product(lines, NUTELLA, last_modified_t=1760000000, nutriments={"sugars_100g": 10})
    serve_deltas(router, {DELTA_2: gz_bytes(newer), DELTA_1: gz_bytes(lines)})

    results = await off_import.import_deltas()

    assert [r.source for r in results] == [DELTA_1, DELTA_2]
    second = results[1].stats
    assert second == ImportStats(
        lines=12, selected=5, inserted=0, updated=1, unchanged=4, skipped=0, rejected=4, failed=0
    )
    assert files_in(download_dir) == []
    assert await run_sources(sessions) == [
        (ImportKind.DELTA, DELTA_1, ImportStatus.COMPLETED),
        (ImportKind.DELTA, DELTA_2, ImportStatus.COMPLETED),
    ]


async def test_imported_delta_files_are_not_downloaded_again(
    off_import: OffImport, router: respx.MockRouter, gz_bytes: Callable[[list[str]], bytes]
) -> None:
    body = gz_bytes(export_lines())
    first = serve_deltas(router, {DELTA_1: body})[DELTA_1]
    await off_import.import_deltas()
    downloads = first.call_count
    serve_deltas(router, {DELTA_1: body, DELTA_2: body})

    results = await off_import.import_deltas()

    assert [r.source for r in results] == [DELTA_2]
    assert (downloads, first.call_count) == (1, 1)


async def test_failed_delta_stops_the_job_and_is_retried_next_time(
    off_import: OffImport,
    router: respx.MockRouter,
    sessions: Sessions,
    download_dir: Path,
    gz_bytes: Callable[[list[str]], bytes],
) -> None:
    body = gz_bytes(export_lines())
    serve_deltas(router, {DELTA_1: body[:-20], DELTA_2: body})  # DELTA_1 truncated

    with pytest.raises(EOFError):
        await off_import.import_deltas()
    assert await run_sources(sessions) == [(ImportKind.DELTA, DELTA_1, ImportStatus.FAILED)]
    assert files_in(download_dir) == [DELTA_1]  # kept for the next attempt

    write_files(download_dir, {DELTA_1: body})  # e.g. replaced by a complete download
    results = await off_import.import_deltas()

    assert [r.source for r in results] == [DELTA_1, DELTA_2]
    assert [r.status for r in results] == [ImportStatus.COMPLETED] * 2


async def test_empty_delta_index(off_import: OffImport, router: respx.MockRouter) -> None:
    serve_deltas(router, {})
    assert await off_import.import_deltas() == []
