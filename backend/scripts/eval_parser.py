"""Run the label parser over the evaluation set and write a Markdown report.

    uv run python -m scripts.eval_parser                        # from backend/
    uv run python -m scripts.eval_parser --labels path/to/labels --output report.md

Reads `eval/labels/` (OCR text + ground truth, see `eval/labels/README.md`) and writes
`docs/reports/label-parser-eval-<parser>-<date>.md` unless `--output` is given. Labels
whose ground truth is not reviewed yet are left out and listed.
"""

import argparse
from datetime import UTC, datetime
from pathlib import Path

from app.core.config import REPO_ROOT
from app.modules.contributions.label_parser import parse_label
from app.modules.contributions.parser_eval import (
    Parser,
    evaluate,
    load_cases,
    render_markdown,
)

LABELS_DIR = REPO_ROOT / "eval" / "labels"
REPORTS_DIR = REPO_ROOT / "docs" / "reports"
PARSERS: dict[str, Parser] = {"rules": parse_label}


def main(labels: Path, output: Path | None, parser: str, source: str) -> Path:
    eval_set = load_cases(labels)
    evaluation = evaluate(eval_set, PARSERS[parser], parser_name=parser)
    today = datetime.now(UTC).date()
    path = output or REPORTS_DIR / f"label-parser-eval-{parser}-{today.isoformat()}.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        render_markdown(evaluation, generated_on=today, source=source),
        encoding="utf-8",
        newline="\n",
    )
    f = evaluation.fields
    print(
        f"{path}: {len(evaluation.results)} labels, fields correct {f.correct}/{f.printed}, "
        f"fully correct {evaluation.fully_correct.matching}/{evaluation.fully_correct.total}, "
        f"ok but wrong {len(evaluation.ok_but_wrong)}, not reviewed {len(eval_set.not_reviewed)}"
    )
    return path


if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    cli.add_argument("--labels", type=Path, default=LABELS_DIR, help="evaluation set folder")
    cli.add_argument("--output", type=Path, help="report file (default: docs/reports/...)")
    cli.add_argument("--parser", choices=sorted(PARSERS), default="rules")
    cli.add_argument(
        "--source",
        default="`eval/labels/`",
        help="where the labels came from, for the report text (default `eval/labels/`)",
    )
    args = cli.parse_args()
    main(args.labels, args.output, args.parser, args.source)
