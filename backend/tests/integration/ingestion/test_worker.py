"""The arq worker end to end (real Redis queue and Postgres; OFF files mocked with respx),
the worker configuration and the command line."""

import importlib
import json
import runpy
import sys
import uuid
from collections.abc import AsyncIterator, Callable, Iterator
from datetime import UTC
from pathlib import Path
from typing import Any

import pytest
import respx
from arq import Retry, Worker, create_pool
from arq.connections import ArqRedis
from arq.constants import in_progress_key_prefix, job_key_prefix, result_key_prefix
from arq.jobs import Job
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.core.config import Settings
from app.modules.products.models import Product, Score
from app.modules.scoring import ENGINE_VERSION, Category
from app.worker import cli, jobs
from app.worker.settings import QUEUE_NAME, redis_settings, worker_settings
from tests.factories import NutritionFactsFactory, ProductFactory
from tests.integration.ingestion.conftest import TUNISIAN, export_lines

Sessions = async_sessionmaker[AsyncSession]
EXPORT_URL = "https://static.off.test/data/openfoodfacts-products.jsonl.gz"
DELTA_URL = "https://static.off.test/data/delta/"
DELTA = "openfoodfacts_products_1000_2000.json.gz"
JOBS = ["import_off_export", "import_off_deltas", "rescore_products"]


@pytest.fixture
def settings(make_settings: Callable[..., Settings], tmp_path: Path) -> Settings:
    return make_settings(
        off_export_url=EXPORT_URL,
        off_delta_url=DELTA_URL,
        import_download_dir=tmp_path / "downloads",
        off_max_retries=0,
        import_delta_cron_hour=3,
    )


@pytest.fixture
def off_files(write_gz: Callable[..., Path]) -> Iterator[respx.MockRouter]:
    body = write_gz(export_lines(), "served.gz").read_bytes()
    with respx.mock(assert_all_called=False) as router:
        router.get(f"{DELTA_URL}index.txt").respond(200, text=f"{DELTA}\n")
        router.get(f"{DELTA_URL}{DELTA}").respond(200, content=body)
        router.head(EXPORT_URL).respond(200, headers={"ETag": '"v1"'})
        router.get(EXPORT_URL).respond(200, content=body)
        yield router


@pytest.fixture
def queue_name() -> str:
    return f"qout:test-queue:{uuid.uuid4().hex}"


@pytest.fixture
async def pool(settings: Settings, queue_name: str) -> AsyncIterator[ArqRedis]:
    redis = await create_pool(redis_settings(settings), default_queue_name=queue_name)
    yield redis
    await redis.delete(queue_name)
    await redis.aclose()


@pytest.fixture(autouse=True)
async def forget_rescoring_job(pool: ArqRedis) -> AsyncIterator[None]:
    """arq job keys are global to the Redis database (shared with dev): without this, a
    finished test rescoring would stop a real worker from queuing it for a day."""
    job_id = jobs.rescore_job_id()
    keys = [
        prefix + job_id for prefix in (job_key_prefix, result_key_prefix, in_progress_key_prefix)
    ]
    await pool.delete(*keys)
    yield
    await pool.delete(*keys)


@pytest.fixture
async def ctx(settings: Settings) -> AsyncIterator[jobs.Context]:
    context: jobs.Context = {"settings": settings}
    await jobs.startup(context)
    yield context
    await jobs.shutdown(context)


@pytest.fixture
async def import_lock(db_engine: AsyncEngine) -> AsyncIterator[None]:
    """Another import holds the bulk-import lock."""
    async with db_engine.connect() as connection:
        await connection.execute(text("SELECT pg_advisory_lock(:k)"), {"k": jobs.IMPORT_LOCK_KEY})
        yield
        await connection.execute(text("SELECT pg_advisory_unlock(:k)"), {"k": jobs.IMPORT_LOCK_KEY})


async def product_count(sessions: Sessions) -> int:
    async with sessions() as session:
        return await session.scalar(select(func.count()).select_from(Product)) or 0


# ---------------------------------------------------------------- configuration


def test_worker_settings(settings: Settings) -> None:
    config = worker_settings(settings, queue_name="q")

    assert [f.name for f in config["functions"]] == JOBS
    [cron_job] = config["cron_jobs"]
    assert (cron_job.name, cron_job.hour, cron_job.minute) == ("cron:import_off_deltas", {3}, {0})
    assert (config["queue_name"], config["timezone"]) == ("q", UTC)
    assert config["ctx"] == {"settings": settings}
    assert worker_settings(settings)["queue_name"] == QUEUE_NAME


def test_cron_can_be_disabled(make_settings: Callable[..., Settings]) -> None:
    settings = make_settings(import_delta_cron_enabled=False)
    assert worker_settings(settings)["cron_jobs"] == []


def test_arq_entry_point() -> None:
    main = importlib.import_module("app.worker.main")
    assert [f.name for f in main.WorkerSettings["functions"]] == JOBS


# ---------------------------------------------------------------- through the queue


async def test_queued_delta_job_is_run_by_the_worker(
    settings: Settings,
    pool: ArqRedis,
    queue_name: str,
    sessions: Sessions,
    off_files: respx.MockRouter,
) -> None:
    job = await pool.enqueue_job("import_off_deltas")
    assert job is not None
    worker = Worker(
        **worker_settings(settings, queue_name=queue_name),
        burst=True,
        handle_signals=False,
        poll_delay=0.01,
    )
    try:
        await worker.main()
    finally:
        await worker.close()

    [summary] = await job.result(timeout=5)
    assert (summary["source"], summary["status"]) == (DELTA, "completed")
    assert summary["stats"]["inserted"] == len(TUNISIAN)
    assert await product_count(sessions) == len(TUNISIAN)
    assert (worker.jobs_complete, worker.jobs_failed) == (2, 0)  # + rescoring at startup


async def test_worker_start_queues_rescoring_once_per_engine_version(
    settings: Settings, pool: ArqRedis, queue_name: str, sessions: Sessions
) -> None:
    async with sessions() as session:
        product = await ProductFactory.create(session, category=Category.GENERAL)
        await NutritionFactsFactory.create(session, product_id=product.id)
        await session.commit()

    for _ in range(2):  # a restart does not rescore again
        worker = Worker(
            **worker_settings(settings, queue_name=queue_name),
            burst=True,
            handle_signals=False,
            poll_delay=0.01,
        )
        try:
            await worker.main()
        finally:
            await worker.close()

    job = Job(jobs.rescore_job_id(), pool, _queue_name=queue_name)
    assert await job.result(timeout=5) == {"checked": 1, "rescored": 1, "failed": 0}
    assert worker.jobs_complete == 0  # second start: already done for this version
    async with sessions() as session:
        stored = await session.scalar(select(Score).where(Score.product_id == product.id))
    assert stored is not None
    assert stored.engine_version == ENGINE_VERSION


# ---------------------------------------------------------------- jobs


async def test_export_job(
    ctx: jobs.Context, sessions: Sessions, off_files: respx.MockRouter
) -> None:
    summary = await jobs.import_off_export(ctx)

    assert summary["source"] == "openfoodfacts-products.jsonl.gz@v1"
    assert summary["status"] == "completed"
    assert summary["resumed_from_line"] == 0
    assert await product_count(sessions) == len(TUNISIAN)
    again = await jobs.import_off_export(ctx)
    assert (again["status"], again["stats"]) == (None, None)


async def test_jobs_wait_while_another_import_runs(
    ctx: jobs.Context, sessions: Sessions, import_lock: None, off_files: respx.MockRouter
) -> None:
    with pytest.raises(Retry):
        await jobs.import_off_deltas(ctx)
    with pytest.raises(Retry):
        await jobs.import_off_export(ctx)
    assert off_files.calls.call_count == 0
    assert await product_count(sessions) == 0


async def test_lock_is_released_after_a_failure(
    ctx: jobs.Context, sessions: Sessions, off_files: respx.MockRouter
) -> None:
    off_files.get(f"{DELTA_URL}index.txt").respond(403)
    with pytest.raises(Exception, match="HTTP 403"):
        await jobs.import_off_deltas(ctx)

    off_files.get(f"{DELTA_URL}index.txt").respond(200, text=f"{DELTA}\n")
    [summary] = await jobs.import_off_deltas(ctx)
    assert summary["status"] == "completed"


async def test_startup_reads_settings_from_the_environment(
    settings: Settings, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(jobs, "get_settings", lambda: settings)
    context: jobs.Context = {}
    await jobs.startup(context)
    try:
        assert context["settings"] is settings
    finally:
        await jobs.shutdown(context)


# ---------------------------------------------------------------- command line


async def test_cli_runs_deltas_now(
    settings: Settings,
    sessions: Sessions,
    off_files: respx.MockRouter,
    capsys: pytest.CaptureFixture[str],
) -> None:
    assert await cli.amain(["run", "deltas"], settings=settings) == 0

    [summary] = json.loads(capsys.readouterr().out.splitlines()[-1])
    assert summary["source"] == DELTA
    assert await product_count(sessions) == len(TUNISIAN)


async def test_cli_runs_the_export_now(
    settings: Settings,
    sessions: Sessions,
    off_files: respx.MockRouter,
    capsys: pytest.CaptureFixture[str],
) -> None:
    assert await cli.amain(["run", "export", "--force"], settings=settings) == 0
    assert json.loads(capsys.readouterr().out.splitlines()[-1])["status"] == "completed"


async def test_cli_runs_rescoring_now(
    settings: Settings, sessions: Sessions, capsys: pytest.CaptureFixture[str]
) -> None:
    assert await cli.amain(["run", "rescore"], settings=settings) == 0
    assert json.loads(capsys.readouterr().out.splitlines()[-1]) == {
        "checked": 0,
        "rescored": 0,
        "failed": 0,
    }


async def test_cli_reports_a_running_import(
    settings: Settings,
    sessions: Sessions,
    import_lock: None,
    capsys: pytest.CaptureFixture[str],
) -> None:
    assert await cli.amain(["run", "deltas"], settings=settings) == 1
    assert "another bulk import is running" in capsys.readouterr().err


async def test_cli_enqueues_jobs(
    settings: Settings, pool: ArqRedis, queue_name: str, capsys: pytest.CaptureFixture[str]
) -> None:
    assert await cli.amain(["enqueue", "deltas"], settings=settings, queue_name=queue_name) == 0
    assert (
        await cli.amain(["enqueue", "export", "--force"], settings=settings, queue_name=queue_name)
        == 0
    )

    queued = sorted(await pool.queued_jobs(), key=lambda job: job.function)
    assert [(job.function, job.kwargs) for job in queued] == [
        ("import_off_deltas", {}),
        ("import_off_export", {"force": True}),
    ]
    assert capsys.readouterr().out.count("queued import_off_") == 2


async def test_cli_force_is_only_for_the_export(
    settings: Settings, capsys: pytest.CaptureFixture[str]
) -> None:
    assert await cli.amain(["run", "deltas", "--force"], settings=settings) == 2
    assert "--force only applies to the export" in capsys.readouterr().err


def test_cli_main_and_module_entry_point(monkeypatch: pytest.MonkeyPatch) -> None:
    async def fake_amain(argv: Any) -> int:
        return 7 if argv in (["run", "deltas"], None) else 0  # None: argparse reads sys.argv

    monkeypatch.setattr(cli, "amain", fake_amain)
    assert cli.main(["run", "deltas"]) == 7

    monkeypatch.setattr(sys, "argv", ["app.worker", "run", "deltas"])
    with pytest.raises(SystemExit) as exit_info:
        runpy.run_module("app.worker", run_name="__main__")
    assert exit_info.value.code == 7
