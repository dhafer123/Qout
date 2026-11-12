"""Compare our Nutri-Score grades with Open Food Facts' and write a Markdown report.

    uv run python -m scripts.validate_engine                    # from backend/
    uv run python -m scripts.validate_engine --output report.md --top 50

Reads the database in DATABASE_URL (normally the dev database after an OFF import) and
writes `docs/reports/engine-validation-<engine version>-<date>.md` unless `--output` is
given. Run `python -m app.worker run rescore` first if the engine version changed.
"""

import argparse
import asyncio
from datetime import UTC, datetime
from pathlib import Path

from app.core.config import REPO_ROOT, get_settings
from app.core.db import create_engine, create_session_factory
from app.modules.products.validation import load_comparisons, render_markdown
from app.modules.scoring import ENGINE_VERSION

REPORTS_DIR = REPO_ROOT / "docs" / "reports"


async def main(output: Path | None, top: int, source: str) -> Path:
    engine = create_engine(get_settings())
    try:
        async with create_session_factory(engine)() as session:
            validation = await load_comparisons(session)
    finally:
        await engine.dispose()
    today = datetime.now(UTC).date()
    path = output or REPORTS_DIR / f"engine-validation-{ENGINE_VERSION}-{today.isoformat()}.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    report = render_markdown(validation, generated_on=today, source=source, top=top)
    path.write_text(report, encoding="utf-8", newline="\n")
    print(
        f"{path}: {validation.graded} graded by both, same grade "
        f"{validation.exact.matching}/{validation.exact.total}"
    )
    return path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--output", type=Path, help="report file (default: docs/reports/...)")
    parser.add_argument("--top", type=int, default=25, help="mismatches to list (default 25)")
    parser.add_argument(
        "--source",
        default="the development database",
        help='where the data came from, for the report text (default "the development database")',
    )
    args = parser.parse_args()
    asyncio.run(main(args.output, args.top, args.source))
