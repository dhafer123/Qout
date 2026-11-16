"""Run the label parser over the evaluation set and write a Markdown report.

    uv run python -m scripts.eval_parser                        # from backend/
    uv run python -m scripts.eval_parser --parser rules+llm     # with the LLM fallback (T28)
    uv run python -m scripts.eval_parser --labels path/to/labels --output report.md

Reads `eval/labels/` (OCR text + ground truth, see `eval/labels/README.md`) and writes
`docs/reports/label-parser-eval-<parser>-<date>.md` unless `--output` is given. Labels
whose ground truth is not reviewed yet are left out and listed.

`rules+llm` calls the LLM (Google Gemini API, `LLM_API_KEY` and `LLM_MODEL` from `.env`;
real requests) for every label the rules parser can't read, and compares the result
with `rules` alone. Replies are kept in `backend/var/llm-cache/` (git-ignored): running it
again with the same model, settings, prompt and labels sends nothing.
"""

import argparse
import asyncio
import hashlib
import json
import sys
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

from app.core.config import BACKEND_DIR, REPO_ROOT, Settings, get_settings, has_llm_key
from app.modules.contributions.label_parser import parse_label
from app.modules.contributions.llm_client import GeminiLabelLlm
from app.modules.contributions.llm_parser import (
    OUTPUT_SCHEMA,
    SYSTEM_PROMPT,
    LabelLlm,
    LlmFinish,
    LlmReply,
)
from app.modules.contributions.parser_eval import (
    EvalSet,
    Evaluation,
    FallbackUse,
    Parser,
    evaluate,
    evaluate_with_fallback,
    load_cases,
    render_markdown,
)

LABELS_DIR = REPO_ROOT / "eval" / "labels"
REPORTS_DIR = REPO_ROOT / "docs" / "reports"
CACHE_DIR = BACKEND_DIR / "var" / "llm-cache"
PARSERS: dict[str, Parser] = {"rules": parse_label}
WITH_FALLBACK = "rules+llm"


@dataclass(frozen=True)
class FallbackOptions:
    llm: LabelLlm | None = None
    """The model to ask; None: the Gemini API from the settings, behind the reply cache."""
    concurrency: int = 4
    """Requests at a time (the free tier allows only a few per minute)."""


class CachedLabelLlm:
    """Saves each reply under a hash of everything that shapes it (model, prompt,
    schema, OCR text), and answers from there next time."""

    def __init__(self, llm: LabelLlm, directory: Path) -> None:
        self._llm = llm
        self._directory = directory
        request = {"model": llm.model, "system": SYSTEM_PROMPT, "schema": OUTPUT_SCHEMA}
        self._request = json.dumps(request, sort_keys=True)

    @property
    def model(self) -> str:
        return self._llm.model

    async def read(self, ocr_text: str) -> LlmReply:
        key = hashlib.sha256(f"{self._request}\n{ocr_text}".encode()).hexdigest()
        path = self._directory / f"{key}.json"
        if path.exists():
            saved = json.loads(path.read_text(encoding="utf-8"))
            return LlmReply(saved["text"], LlmFinish(saved["finish"]), saved["model"])
        reply = await self._llm.read(ocr_text)
        self._directory.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(reply.__dict__), encoding="utf-8")
        return reply


def main(
    labels: Path,
    output: Path | None,
    parser: str,
    source: str,
    *,
    options: FallbackOptions | None = None,
) -> Path:
    eval_set = load_cases(labels)
    baseline: Evaluation | None = None
    fallback: FallbackUse | None = None
    if parser == WITH_FALLBACK:
        settings = get_settings()
        baseline = evaluate(eval_set, parse_label, parser_name="rules")
        evaluation, fallback = asyncio.run(
            _with_fallback(eval_set, settings, options or FallbackOptions())
        )
    else:
        evaluation = evaluate(eval_set, PARSERS[parser], parser_name=parser)

    today = datetime.now(UTC).date()
    name = parser.replace("+", "-")
    path = output or REPORTS_DIR / f"label-parser-eval-{name}-{today.isoformat()}.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    report = render_markdown(
        evaluation, generated_on=today, source=source, baseline=baseline, fallback=fallback
    )
    path.write_text(report, encoding="utf-8", newline="\n")
    f = evaluation.fields
    summary = (
        f"{path}: {len(evaluation.results)} labels, fields correct {f.correct}/{f.printed}, "
        f"fully correct {evaluation.fully_correct.matching}/{evaluation.fully_correct.total}, "
        f"ok but wrong {len(evaluation.ok_but_wrong)}, not reviewed {len(eval_set.not_reviewed)}"
    )
    if fallback is not None:
        summary += f", LLM accepted {len(fallback.accepted)}/{fallback.asked}"
    print(summary)
    return path


async def _with_fallback(
    eval_set: EvalSet, settings: Settings, options: FallbackOptions
) -> tuple[Evaluation, FallbackUse]:
    """With `llm` (tests), as given; otherwise the Gemini API behind the reply cache."""
    time_limit = settings.llm_timeout_seconds
    if options.llm is not None:
        return await evaluate_with_fallback(
            eval_set, options.llm, time_limit=time_limit, concurrency=options.concurrency
        )
    if not has_llm_key(settings):
        sys.exit("rules+llm needs a real Gemini API key in LLM_API_KEY (.env)")
    client = GeminiLabelLlm.from_settings(settings)
    cached = CachedLabelLlm(client, CACHE_DIR)
    try:
        return await evaluate_with_fallback(
            eval_set, cached, time_limit=time_limit, concurrency=options.concurrency
        )
    finally:
        await client.aclose()


if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    cli.add_argument("--labels", type=Path, default=LABELS_DIR, help="evaluation set folder")
    cli.add_argument("--output", type=Path, help="report file (default: docs/reports/...)")
    cli.add_argument("--parser", choices=[*sorted(PARSERS), WITH_FALLBACK], default="rules")
    cli.add_argument(
        "--concurrency", type=int, default=4, help="rules+llm: LLM requests at a time (default 4)"
    )
    cli.add_argument(
        "--source",
        default="`eval/labels/`",
        help="where the labels came from, for the report text (default `eval/labels/`)",
    )
    args = cli.parse_args()
    options = FallbackOptions(concurrency=args.concurrency)
    main(args.labels, args.output, args.parser, args.source, options=options)
