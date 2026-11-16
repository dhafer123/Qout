"""Run the label parser over the evaluation set and write a Markdown report.

    uv run python -m scripts.eval_parser                        # from backend/
    uv run python -m scripts.eval_parser --parser rules+llm     # with the LLM fallback (T28)
    uv run python -m scripts.eval_parser --labels path/to/labels --output report.md

Reads `eval/labels/` (OCR text + ground truth, see `eval/labels/README.md`) and writes
`docs/reports/label-parser-eval-<parser>-<date>.md` unless `--output` is given. Labels
whose ground truth is not reviewed yet are left out and listed.

`rules+llm` calls the LLM (Anthropic API, `LLM_API_KEY` and `LLM_MODEL` from `.env`; real
requests, billed) for every label the rules parser can't read, and compares the result
with `rules` alone. Replies are kept in `backend/var/llm-cache/` (git-ignored): running it
again with the same model, settings, prompt and labels sends nothing.
"""

import argparse
import asyncio
import hashlib
import json
import sys
from datetime import UTC, datetime
from pathlib import Path

from app.core.config import BACKEND_DIR, REPO_ROOT, Settings, get_settings, has_llm_key
from app.modules.contributions.label_parser import parse_label
from app.modules.contributions.llm_client import AnthropicLabelLlm
from app.modules.contributions.llm_parser import (
    OUTPUT_SCHEMA,
    SYSTEM_PROMPT,
    LabelLlm,
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


class CachedLabelLlm:
    """Saves each complete reply under a hash of everything that shapes it (model,
    effort, prompt, schema, OCR text), and answers from there next time."""

    def __init__(self, llm: LabelLlm, directory: Path, *, effort: str) -> None:
        self._llm = llm
        self._directory = directory
        request = {"model": llm.model, "effort": effort, "system": SYSTEM_PROMPT}
        self._request = json.dumps(request | {"schema": OUTPUT_SCHEMA}, sort_keys=True)

    @property
    def model(self) -> str:
        return self._llm.model

    async def read(self, ocr_text: str) -> LlmReply:
        key = hashlib.sha256(f"{self._request}\n{ocr_text}".encode()).hexdigest()
        path = self._directory / f"{key}.json"
        if path.exists():
            return LlmReply(**json.loads(path.read_text(encoding="utf-8")))
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
    llm: LabelLlm | None = None,
) -> Path:
    eval_set = load_cases(labels)
    baseline: Evaluation | None = None
    fallback: FallbackUse | None = None
    if parser == WITH_FALLBACK:
        settings = get_settings()
        baseline = evaluate(eval_set, parse_label, parser_name="rules")
        evaluation, fallback = asyncio.run(_with_fallback(eval_set, settings, llm))
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
    eval_set: EvalSet, settings: Settings, llm: LabelLlm | None
) -> tuple[Evaluation, FallbackUse]:
    """With `llm` (tests), as given; otherwise the Anthropic API behind the reply cache."""
    time_limit = settings.llm_timeout_seconds
    if llm is not None:
        return await evaluate_with_fallback(eval_set, llm, time_limit=time_limit)
    if not has_llm_key(settings):
        sys.exit("rules+llm needs a real LLM_API_KEY in .env (requests are billed)")
    client = AnthropicLabelLlm.from_settings(settings)
    cached = CachedLabelLlm(client, CACHE_DIR, effort=settings.llm_effort)
    try:
        return await evaluate_with_fallback(eval_set, cached, time_limit=time_limit)
    finally:
        await client.aclose()


if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    cli.add_argument("--labels", type=Path, default=LABELS_DIR, help="evaluation set folder")
    cli.add_argument("--output", type=Path, help="report file (default: docs/reports/...)")
    cli.add_argument("--parser", choices=[*sorted(PARSERS), WITH_FALLBACK], default="rules")
    cli.add_argument(
        "--source",
        default="`eval/labels/`",
        help="where the labels came from, for the report text (default `eval/labels/`)",
    )
    args = cli.parse_args()
    main(args.labels, args.output, args.parser, args.source)
