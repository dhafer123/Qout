"""FileImporter against real Postgres and Redis, with the fixture export."""

from collections.abc import Callable
from decimal import Decimal
from pathlib import Path
from typing import Any

import pytest
from redis.asyncio import Redis
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.modules.ingestion import importer as importer_module
from app.modules.ingestion.importer import FileImporter, ImportStats
from app.modules.ingestion.models import ImportKind, ImportRun, ImportStatus
from app.modules.ingestion.off_normaliser import NormalizedProduct, normalize
from app.modules.products.cache import ProductCache, cache_key
from app.modules.products.models import DataSource, NutritionFacts, Product, Score
from app.modules.products.upsert import ProductUpserter
from app.modules.scoring import ENGINE_VERSION
from tests.factories import ProductFactory
from tests.integration.ingestion.conftest import (
    NESCAFE,
    NUTELLA,
    RICOTTA,
    TUNISIA,
    TUNISIAN,
    edit_product,
    export_lines,
)

Sessions = async_sessionmaker[AsyncSession]
WriteGz = Callable[..., Path]


def importer(sessions: Sessions, cache: ProductCache, batch_size: int = 500) -> FileImporter:
    return FileImporter(sessions, cache, countries=TUNISIA, batch_size=batch_size)


async def count(sessions: Sessions, model: type[Any]) -> int:
    async with sessions() as session:
        return await session.scalar(select(func.count()).select_from(model)) or 0


async def eans(sessions: Sessions) -> set[str]:
    async with sessions() as session:
        return set((await session.scalars(select(Product.ean))).all())


async def runs(sessions: Sessions) -> list[ImportRun]:
    async with sessions() as session:
        result = await session.scalars(select(ImportRun).order_by(ImportRun.created_at))
        return list(result.all())


async def product_rows(sessions: Sessions, ean: str) -> tuple[list[NutritionFacts], list[Score]]:
    async with sessions() as session:
        product = await session.scalar(select(Product).where(Product.ean == ean))
        assert product is not None
        facts = await session.scalars(
            select(NutritionFacts)
            .where(NutritionFacts.product_id == product.id)
            .order_by(NutritionFacts.version)
        )
        scores = await session.scalars(
            select(Score).where(Score.product_id == product.id).order_by(Score.created_at)
        )
        return list(facts.all()), list(scores.all())


# ---------------------------------------------------------------- one import


async def test_import_stores_and_scores_the_selected_products(
    sessions: Sessions, cache: ProductCache, write_gz: WriteGz
) -> None:
    result = await importer(sessions, cache).run(
        ImportKind.FULL, "export@1", write_gz(export_lines())
    )

    assert (result.status, result.resumed_from_line) == (ImportStatus.COMPLETED, 0)
    assert result.stats == ImportStats(
        lines=12, selected=5, inserted=5, updated=0, unchanged=0, skipped=0, rejected=4, failed=0
    )
    assert await eans(sessions) == TUNISIAN
    facts, scores = await product_rows(sessions, NUTELLA)
    assert len(facts) == 1
    assert [(s.engine_version, s.grade, s.off_grade) for s in scores] == [
        (ENGINE_VERSION, "E", "E")
    ]
    no_nutrition, [insufficient] = await product_rows(sessions, NESCAFE)  # a beverage
    assert no_nutrition == []
    assert (insufficient.grade, insufficient.nutrition_facts_id) == (None, None)

    [run] = await runs(sessions)
    assert (run.kind, run.source, run.countries, run.status) == (
        ImportKind.FULL,
        "export@1",
        ["en:tunisia"],
        ImportStatus.COMPLETED,
    )
    assert (run.checkpoint_line, run.lines, run.inserted, run.rejected) == (12, 12, 5, 4)
    assert run.finished_at is not None
    assert run.error is None


async def test_small_batches_and_chunks_give_the_same_result(
    sessions: Sessions,
    cache: ProductCache,
    write_gz: WriteGz,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(importer_module, "CHUNK_LINES", 4)

    result = await importer(sessions, cache, batch_size=2).run(
        ImportKind.FULL, "export@1", write_gz(export_lines())
    )

    assert result.stats is not None
    assert (result.stats.inserted, result.stats.lines) == (5, 12)
    assert await eans(sessions) == TUNISIAN


# ---------------------------------------------------------------- twice


async def test_importing_twice_creates_no_duplicates_and_rescores_changes(
    sessions: Sessions, cache: ProductCache, write_gz: WriteGz
) -> None:
    lines = export_lines()
    await importer(sessions, cache).run(ImportKind.FULL, "export@1", write_gz(lines, "a.gz"))
    facts_before = await count(sessions, NutritionFacts)
    scores_before = await count(sessions, Score)
    # Next day: Nutella's sugar changed (and OFF touched it), ricotta got a new name.
    edited = edit_product(
        lines, NUTELLA, last_modified_t=1760000000, nutriments={"sugars_100g": 10}
    )
    edited = edit_product(
        edited, RICOTTA, last_modified_t=1760000000, product_name_fr="Ricotta fraîche"
    )

    result = await importer(sessions, cache).run(
        ImportKind.FULL, "export@2", write_gz(edited, "b.gz")
    )

    assert result.stats is not None
    assert (result.stats.inserted, result.stats.updated, result.stats.unchanged) == (0, 2, 3)
    assert await eans(sessions) == TUNISIAN
    assert await count(sessions, Product) == 5
    assert await count(sessions, NutritionFacts) == facts_before + 1  # Nutella v2 only
    assert await count(sessions, Score) == scores_before + 1
    facts, scores = await product_rows(sessions, NUTELLA)
    assert [f.version for f in facts] == [1, 2]
    assert facts[1].sugars_g == Decimal(10)
    assert scores[-1].nutrition_facts_id == facts[1].id
    assert scores[-1].total is not None
    assert scores[0].total is not None
    assert scores[-1].total < scores[0].total


async def test_completed_file_is_not_imported_again(
    sessions: Sessions, cache: ProductCache, write_gz: WriteGz
) -> None:
    path = write_gz(export_lines())
    await importer(sessions, cache).run(ImportKind.DELTA, "delta-1", path)

    again = await importer(sessions, cache).run(ImportKind.DELTA, "delta-1", path)
    assert (again.status, again.stats) == (None, None)
    assert len(await runs(sessions)) == 1

    forced = await importer(sessions, cache).run(ImportKind.DELTA, "delta-1", path, force=True)
    assert forced.stats is not None
    assert (forced.stats.inserted, forced.stats.unchanged) == (0, 5)
    assert len(await runs(sessions)) == 2


async def test_runs_are_per_country_list(
    sessions: Sessions, cache: ProductCache, write_gz: WriteGz
) -> None:
    path = write_gz(export_lines())
    await importer(sessions, cache).run(ImportKind.DELTA, "delta-1", path)
    both = frozenset({"en:tunisia", "en:morocco"})
    wider = FileImporter(sessions, cache, countries=both, batch_size=500)

    result = await wider.run(ImportKind.DELTA, "delta-1", path)

    assert result.stats is not None
    assert (result.stats.inserted, result.stats.unchanged) == (1, 5)  # + Moroccan beef
    assert [r.countries for r in await runs(sessions)] == [
        ["en:tunisia"],
        ["en:morocco", "en:tunisia"],
    ]


# ---------------------------------------------------------------- resume


async def test_interrupted_import_resumes_from_the_checkpoint(
    sessions: Sessions,
    cache: ProductCache,
    write_gz: WriteGz,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(importer_module, "CHUNK_LINES", 4)
    path = write_gz(export_lines())
    original = FileImporter._commit
    commits = 0

    async def crash_on_third_commit(self: FileImporter, *args: Any, **kwargs: Any) -> None:
        nonlocal commits
        commits += 1
        if commits == 3:
            raise ConnectionError("database went away")
        await original(self, *args, **kwargs)

    monkeypatch.setattr(FileImporter, "_commit", crash_on_third_commit)
    with pytest.raises(ConnectionError):
        await importer(sessions, cache, batch_size=2).run(ImportKind.FULL, "export@1", path)

    [failed] = await runs(sessions)
    assert failed.status == ImportStatus.FAILED
    assert failed.error == "ConnectionError('database went away')"
    # Batches: [1, 2] (checkpoint 2), [3] + end of chunk 1-4 (checkpoint 4), then the crash.
    assert failed.checkpoint_line == 4
    assert (failed.lines, failed.inserted) == (4, 3)

    monkeypatch.setattr(FileImporter, "_commit", original)
    result = await importer(sessions, cache, batch_size=2).run(ImportKind.FULL, "export@1", path)

    assert (result.status, result.resumed_from_line) == (ImportStatus.COMPLETED, 4)
    assert result.stats == ImportStats(
        lines=12, selected=5, inserted=5, updated=0, unchanged=0, skipped=0, rejected=4, failed=0
    )
    assert await eans(sessions) == TUNISIAN
    [run] = await runs(sessions)  # the same run, resumed
    assert (run.id, run.status, run.error) == (failed.id, ImportStatus.COMPLETED, None)


async def test_run_left_running_by_a_killed_worker_is_resumed(
    sessions: Sessions, cache: ProductCache, write_gz: WriteGz
) -> None:
    async with sessions() as session:
        session.add(
            ImportRun(
                kind=ImportKind.DELTA,
                source="delta-1",
                countries=["en:tunisia"],
                status=ImportStatus.RUNNING,
                checkpoint_line=5,
                lines=5,
                selected=4,
                inserted=4,
                rejected=1,
            )
        )
        await session.commit()

    result = await importer(sessions, cache).run(
        ImportKind.DELTA, "delta-1", write_gz(export_lines())
    )

    assert result.resumed_from_line == 5
    assert result.stats is not None
    assert (result.stats.lines, result.stats.selected, result.stats.inserted) == (12, 5, 5)
    assert await eans(sessions) == {NESCAFE}  # lines 1-5 were "done" before


# ---------------------------------------------------------------- left alone, failures


async def test_contributions_and_older_records_are_skipped(
    sessions: Sessions, cache: ProductCache, write_gz: WriteGz
) -> None:
    async with sessions() as session:
        await ProductFactory.create(
            session, ean=RICOTTA, name="Ours", source=DataSource.CONTRIBUTION
        )
        newer = normalize(NUTELLA, {"product_name": "Newer", "last_modified_t": 1900000000})
        await ProductUpserter(session).upsert(newer)
        await session.commit()

    result = await importer(sessions, cache).run(
        ImportKind.FULL, "export@1", write_gz(export_lines())
    )

    assert result.stats is not None
    assert (result.stats.inserted, result.stats.skipped) == (3, 2)
    async with sessions() as session:
        names = dict((await session.execute(select(Product.ean, Product.name))).all())
    assert (names[RICOTTA], names[NUTELLA]) == ("Ours", "Newer")


async def test_one_failing_product_does_not_stop_the_import(
    sessions: Sessions,
    cache: ProductCache,
    write_gz: WriteGz,
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
) -> None:
    def normalize_or_fail(ean: str, product: Any) -> NormalizedProduct:
        if ean == NUTELLA:
            raise ValueError("unexpected OFF data")
        return normalize(ean, product)

    monkeypatch.setattr(importer_module, "normalize", normalize_or_fail)

    result = await importer(sessions, cache).run(
        ImportKind.FULL, "export@1", write_gz(export_lines())
    )

    assert result.status == ImportStatus.COMPLETED
    assert result.stats is not None
    assert (result.stats.inserted, result.stats.failed) == (4, 1)
    assert await eans(sessions) == TUNISIAN - {NUTELLA}
    assert "product import failed" in caplog.text


async def test_truncated_file_fails_the_run(
    sessions: Sessions, cache: ProductCache, write_gz: WriteGz, tmp_path: Path
) -> None:
    whole = write_gz(export_lines()).read_bytes()
    truncated = tmp_path / "truncated.gz"
    truncated.write_bytes(whole[: len(whole) - 20])

    with pytest.raises(EOFError):
        await importer(sessions, cache).run(ImportKind.FULL, "export@1", truncated)

    [run] = await runs(sessions)
    assert run.status == ImportStatus.FAILED
    assert run.error is not None
    assert run.error.startswith("EOFError")


# ---------------------------------------------------------------- cache


async def test_changed_products_leave_the_cache(
    sessions: Sessions, cache: ProductCache, redis: Redis, write_gz: WriteGz
) -> None:
    lines = export_lines()
    await importer(sessions, cache).run(ImportKind.FULL, "export@1", write_gz(lines, "a.gz"))
    for ean in (NUTELLA, RICOTTA):
        await redis.set(cache_key(ean), b"stale")
    edited = edit_product(lines, NUTELLA, nutriments={"sugars_100g": 10})

    await importer(sessions, cache).run(ImportKind.FULL, "export@2", write_gz(edited, "b.gz"))

    assert await redis.get(cache_key(NUTELLA)) is None
    assert await redis.get(cache_key(RICOTTA)) == b"stale"  # unchanged: still valid
