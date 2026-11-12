"""Command line for bulk imports: queue a job for the worker, or run it right here.

uv run python -m app.worker enqueue deltas          # the worker runs it
uv run python -m app.worker enqueue export --force
uv run python -m app.worker run deltas              # runs now, in this process
"""

import argparse
import asyncio
import json
import sys
from collections.abc import Sequence
from typing import Any

from arq import create_pool

from app.core.config import Settings, get_settings
from app.worker import jobs
from app.worker.settings import QUEUE_NAME, redis_settings

_JOBS = {"export": "import_off_export", "deltas": "import_off_deltas"}


def parser() -> argparse.ArgumentParser:
    cli = argparse.ArgumentParser(prog="python -m app.worker", description=__doc__.split("\n")[0])
    cli.add_argument("action", choices=["enqueue", "run"], help="queue for the worker, or run now")
    cli.add_argument("job", choices=sorted(_JOBS), help="full export, or new delta files")
    cli.add_argument(
        "--force", action="store_true", help="export: import again even if already imported"
    )
    return cli


def main(argv: Sequence[str] | None = None) -> int:
    return asyncio.run(amain(argv))


async def amain(
    argv: Sequence[str] | None = None,
    *,
    settings: Settings | None = None,
    queue_name: str = QUEUE_NAME,
) -> int:
    args = parser().parse_args(argv)
    if args.force and args.job != "export":
        print("--force only applies to the export", file=sys.stderr)
        return 2
    settings = settings or get_settings()
    if args.action == "enqueue":
        return await _enqueue(settings, args.job, force=args.force, queue_name=queue_name)
    return await _run(settings, args.job, force=args.force)


async def _enqueue(settings: Settings, job: str, *, force: bool, queue_name: str) -> int:
    pool = await create_pool(redis_settings(settings), default_queue_name=queue_name)
    try:
        kwargs: dict[str, Any] = {"force": True} if force else {}
        queued = await pool.enqueue_job(_JOBS[job], **kwargs)
    finally:
        await pool.aclose()
    # `queued` is None only for a duplicate `_job_id`, which is never set here.
    print(f"queued {_JOBS[job]} (job {getattr(queued, 'job_id', None)})")
    return 0


async def _run(settings: Settings, job: str, *, force: bool) -> int:
    ctx: jobs.Context = {"settings": settings}
    await jobs.startup(ctx)
    try:
        if job == "export":
            output: object = jobs.summary(await jobs.run_export(ctx, force=force))
        else:
            output = [jobs.summary(result) for result in await jobs.run_deltas(ctx)]
    except jobs.ImportBusyError:
        print("another bulk import is running; try again later", file=sys.stderr)
        return 1
    finally:
        await jobs.shutdown(ctx)
    print(json.dumps(output))  # one line, after the log lines
    return 0
