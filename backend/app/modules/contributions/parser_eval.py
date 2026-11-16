"""Label parser evaluation (T27): parser output against hand-written ground truth.

The evaluation set lives in `eval/labels/` (repo root): for each label, `<id>.txt` is the
OCR text exactly as ML Kit returned it on the phone and `<id>.json` the ground truth, read
from the photo by a person (format in `eval/labels/README.md`). `load_cases` reads and
checks the files, `evaluate` runs a parser over them and computes the metrics, and
`render_markdown` writes the report (all pure apart from reading files). The script
`scripts/eval_parser.py` puts them together.

Each field of a label gets one outcome:

- correct: printed on the label and read with the same value (as exact decimals);
- wrong: printed, read with another value;
- missed: printed, not read;
- spurious: not printed, but the parser returned a value it did not derive. Salt derived
  from sodium and kJ derived from kcal are expected when the label omits them.

A label is fully correct when every printed field is correct, nothing is spurious and the
basis is right. The parser's own `ok` is compared with that: a label the parser calls ok
but got wrong is the costly case, because the fallback parser (T28) is only tried when
`ok` is False.
"""

import json
import re
from collections import Counter
from collections.abc import Callable, Iterable, Mapping
from dataclasses import dataclass, field
from datetime import date
from decimal import Decimal, InvalidOperation
from enum import StrEnum
from pathlib import Path

from app.modules.contributions.label_parser import LabelField, LabelIssueCode, LabelParse
from app.modules.products.models import NutritionBasis

Parser = Callable[[str], LabelParse]

_ID = re.compile(r"[a-z0-9][a-z0-9-]*")
_TAG = re.compile(r"[a-z0-9][a-z0-9-]*")
_LANGUAGE = re.compile(r"[a-z]{2}")
_EAN = re.compile(r"\d{8,14}")
_KEYS = frozenset(
    {
        "reviewed",
        "product",
        "brand",
        "ean",
        "languages",
        "layout",
        "basis",
        "values",
        "approximate",
        "notes",
    }
)
_FIELD_NAMES = frozenset(f.value for f in LabelField)
_EMPTY = "-"


class GroundTruthError(ValueError):
    """A ground truth file that doesn't follow the format; the message names the file."""


@dataclass(frozen=True)
class GroundTruth:
    label_id: str
    basis: NutritionBasis | None
    """None: the label has no per-100 column (per portion only)."""
    values: dict[LabelField, Decimal]
    """Printed in the per-100 column, in grams (sodium converted from mg) or kJ/kcal."""
    approximate: frozenset[LabelField] = frozenset()
    """Printed as "< x" (value x) or "traces" (value 0)."""
    languages: tuple[str, ...] = ()
    layout: tuple[str, ...] = ()
    product: str | None = None
    brand: str | None = None
    ean: str | None = None


@dataclass(frozen=True)
class LabelCase:
    truth: GroundTruth
    ocr_text: str


@dataclass(frozen=True)
class EvalSet:
    cases: tuple[LabelCase, ...]
    not_reviewed: tuple[str, ...] = ()
    """Labels whose ground truth isn't written yet (`"reviewed": false`): left out."""


# ---------------------------------------------------------------- loading


def load_cases(directory: Path) -> EvalSet:
    """Every `<id>.json` in `directory` with its `<id>.txt`, sorted by id."""
    cases: list[LabelCase] = []
    not_reviewed: list[str] = []
    for path in sorted(directory.glob("*.json")):
        label_id = path.stem
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            raise GroundTruthError(f"{path.name}: not valid JSON ({error})") from error
        text_path = path.with_suffix(".txt")
        if not text_path.is_file():
            raise GroundTruthError(f"{path.name}: {text_path.name} is missing")
        truth = parse_ground_truth(label_id, data)
        if truth is None:
            not_reviewed.append(label_id)
            continue
        cases.append(LabelCase(truth, text_path.read_text(encoding="utf-8")))
    return EvalSet(tuple(cases), tuple(not_reviewed))


def parse_ground_truth(label_id: str, data: object) -> GroundTruth | None:
    """Check one ground truth document; None when it is not reviewed yet."""

    def fail(message: str) -> GroundTruthError:
        return GroundTruthError(f"{label_id}.json: {message}")

    if not _ID.fullmatch(label_id):
        raise fail("the file name must be lower-case letters, digits and hyphens")
    if not isinstance(data, dict):
        raise fail("expected a JSON object")
    if unknown := sorted(set(data) - _KEYS):
        raise fail(f"unknown keys {unknown}")
    reviewed = data.get("reviewed")
    if not isinstance(reviewed, bool):
        raise fail('"reviewed" must be true or false')
    if not reviewed:
        return None

    basis = data.get("basis")
    if basis is not None and basis not in {b.value for b in NutritionBasis}:
        raise fail(f'"basis" must be per_100g, per_100ml or null, not {basis!r}')
    values = _values(data.get("values"), fail)
    if basis is None and values:
        raise fail('values are per 100 g or 100 mL: with "basis": null there are none')
    approximate = _fields(data.get("approximate", []), '"approximate"', fail)
    if not approximate <= values.keys():
        raise fail('every "approximate" field needs a value')
    ean = _optional_text(data, "ean", fail)
    if ean is not None and not _EAN.fullmatch(ean):
        raise fail('"ean" must be 8 to 14 digits')
    _optional_text(data, "notes", fail)
    return GroundTruth(
        label_id=label_id,
        basis=None if basis is None else NutritionBasis(basis),
        values=values,
        approximate=approximate,
        languages=_tags(data.get("languages", []), '"languages"', _LANGUAGE, fail),
        layout=_tags(data.get("layout", []), '"layout"', _TAG, fail),
        product=_optional_text(data, "product", fail),
        brand=_optional_text(data, "brand", fail),
        ean=ean,
    )


def _values(raw: object, fail: Callable[[str], GroundTruthError]) -> dict[LabelField, Decimal]:
    if not isinstance(raw, dict):
        raise fail('"values" must be an object')
    values: dict[LabelField, Decimal] = {}
    for name, text in raw.items():
        target = _field(name, '"values"', fail)
        if not isinstance(text, str):
            raise fail(f"{name} must be a string (exact decimal), not {text!r}")
        try:
            value = Decimal(text)
        except InvalidOperation:
            value = Decimal("NaN")
        if not value.is_finite() or value < 0 or text.strip() != text:
            raise fail(f'{name} must be a decimal number ≥ 0 such as "1.5", not {text!r}')
        values[target] = value
    return values


def _fields(
    raw: object, key: str, fail: Callable[[str], GroundTruthError]
) -> frozenset[LabelField]:
    if not isinstance(raw, list):
        raise fail(f"{key} must be a list")
    return frozenset(_field(name, key, fail) for name in raw)


def _field(name: object, key: str, fail: Callable[[str], GroundTruthError]) -> LabelField:
    if name not in _FIELD_NAMES:
        raise fail(f"unknown field {name!r} in {key}")
    return LabelField(str(name))


def _tags(
    raw: object, key: str, pattern: re.Pattern[str], fail: Callable[[str], GroundTruthError]
) -> tuple[str, ...]:
    if not isinstance(raw, list) or not all(
        isinstance(tag, str) and pattern.fullmatch(tag) for tag in raw
    ):
        raise fail(f"{key} must be a list of lower-case tags")
    if len(set(raw)) != len(raw):
        raise fail(f"{key} has duplicates")
    return tuple(raw)


def _optional_text(
    data: Mapping[str, object], key: str, fail: Callable[[str], GroundTruthError]
) -> str | None:
    value = data.get(key)
    if value is not None and not isinstance(value, str):
        raise fail(f'"{key}" must be a string or null')
    return value or None


# ---------------------------------------------------------------- comparison


class Outcome(StrEnum):
    CORRECT = "correct"
    WRONG = "wrong"
    MISSED = "missed"
    SPURIOUS = "spurious"


@dataclass(frozen=True)
class FieldResult:
    field: LabelField
    outcome: Outcome
    expected: Decimal | None
    got: Decimal | None


@dataclass(frozen=True)
class LabelResult:
    truth: GroundTruth
    parse: LabelParse
    fields: tuple[FieldResult, ...]
    """Printed fields and spurious ones, in `LabelField` order."""

    @property
    def basis_correct(self) -> bool:
        return self.parse.basis == self.truth.basis

    @property
    def fully_correct(self) -> bool:
        return self.basis_correct and all(r.outcome == Outcome.CORRECT for r in self.fields)

    @property
    def approximate_correct(self) -> bool:
        """The parser's approximate marks agree with the label's, on the printed fields."""
        return self.parse.approximate & self.truth.values.keys() == self.truth.approximate


def compare(truth: GroundTruth, parse: LabelParse) -> LabelResult:
    results: list[FieldResult] = []
    for target in LabelField:
        expected, got = truth.values.get(target), parse.values.get(target)
        if expected is not None:
            if got is None:
                outcome = Outcome.MISSED
            else:
                outcome = Outcome.CORRECT if got == expected else Outcome.WRONG
        elif got is not None and target not in parse.derived:
            outcome = Outcome.SPURIOUS
        else:
            continue
        results.append(FieldResult(target, outcome, expected, got))
    return LabelResult(truth, parse, tuple(results))


# ---------------------------------------------------------------- metrics


@dataclass(frozen=True)
class Tally:
    """Field outcomes. Accuracy is over printed fields, precision over values returned."""

    correct: int = 0
    wrong: int = 0
    missed: int = 0
    spurious: int = 0

    @property
    def printed(self) -> int:
        return self.correct + self.wrong + self.missed

    @property
    def returned(self) -> int:
        return self.correct + self.wrong + self.spurious

    @property
    def accuracy(self) -> float | None:
        return _ratio(self.correct, self.printed)

    @property
    def precision(self) -> float | None:
        return _ratio(self.correct, self.returned)


@dataclass(frozen=True)
class Rate:
    matching: int
    total: int

    @property
    def percent(self) -> float | None:
        return _ratio(self.matching, self.total)


@dataclass(frozen=True)
class Group:
    """Labels sharing a language or layout tag."""

    labels: int
    fully_correct: Rate
    fields: Tally


@dataclass(frozen=True)
class Evaluation:
    parser: str
    results: tuple[LabelResult, ...]
    fields: Tally
    by_field: dict[LabelField, Tally]
    """Only fields printed or returned somewhere, in `LabelField` order."""
    basis: Rate
    fully_correct: Rate
    approximate: Rate
    ok_matrix: Counter[tuple[bool, bool]]
    """(parser ok, fully correct) -> labels."""
    by_language: dict[str, Group]
    by_layout: dict[str, Group]
    issues: Counter[LabelIssueCode] = field(default_factory=Counter)
    """Labels reporting each issue code."""
    not_reviewed: tuple[str, ...] = ()

    @property
    def ok_but_wrong(self) -> tuple[LabelResult, ...]:
        return tuple(r for r in self.results if r.parse.ok and not r.fully_correct)


def evaluate(eval_set: EvalSet, parser: Parser, *, parser_name: str) -> Evaluation:
    results = tuple(compare(case.truth, parser(case.ocr_text)) for case in eval_set.cases)
    return Evaluation(
        parser=parser_name,
        results=results,
        fields=_tally(r for result in results for r in result.fields),
        by_field={
            target: tally
            for target in LabelField
            if (tally := _tally(r for res in results for r in res.fields if r.field == target))
            != Tally()
        },
        basis=Rate(sum(r.basis_correct for r in results), len(results)),
        fully_correct=_fully_correct(results),
        approximate=Rate(sum(r.approximate_correct for r in results), len(results)),
        ok_matrix=Counter((r.parse.ok, r.fully_correct) for r in results),
        by_language=_groups(results, lambda t: t.languages),
        by_layout=_groups(results, lambda t: t.layout),
        issues=Counter(code for r in results for code in {i.code for i in r.parse.issues}),
        not_reviewed=eval_set.not_reviewed,
    )


def _tally(results: Iterable[FieldResult]) -> Tally:
    counts = Counter(r.outcome for r in results)
    return Tally(
        correct=counts[Outcome.CORRECT],
        wrong=counts[Outcome.WRONG],
        missed=counts[Outcome.MISSED],
        spurious=counts[Outcome.SPURIOUS],
    )


def _fully_correct(results: Iterable[LabelResult]) -> Rate:
    rows = tuple(results)
    return Rate(sum(r.fully_correct for r in rows), len(rows))


def _groups(
    results: tuple[LabelResult, ...], tags: Callable[[GroundTruth], tuple[str, ...]]
) -> dict[str, Group]:
    names = sorted({tag for r in results for tag in tags(r.truth)})
    groups: dict[str, Group] = {}
    for name in names:
        members = [r for r in results if name in tags(r.truth)]
        groups[name] = Group(
            labels=len(members),
            fully_correct=_fully_correct(members),
            fields=_tally(f for r in members for f in r.fields),
        )
    return groups


def _ratio(part: int, whole: int) -> float | None:
    return None if whole == 0 else 100 * part / whole


# ---------------------------------------------------------------- Markdown


def render_markdown(evaluation: Evaluation, *, generated_on: date, source: str) -> str:
    e = evaluation
    lines = [
        f"# Label parser evaluation: `{e.parser}`",
        "",
        f"Generated {generated_on.isoformat()} from {source}: {len(e.results)} labels, OCR "
        "text from ML Kit on the phone, ground truth read from the photos by hand. Values are "
        "compared as exact decimals with what the label prints per 100 g or 100 mL.",
        "",
    ]
    if e.not_reviewed:
        lines += [
            f"> {len(e.not_reviewed)} labels have no ground truth yet and are left out: "
            f"{', '.join(e.not_reviewed)}.",
            "",
        ]
    lines += [
        "## Summary",
        "",
        "| | Result |",
        "|---|---:|",
        f"| Labels | {len(e.results)} |",
        f"| **Field accuracy** (printed fields read correctly) | "
        f"**{_count(e.fields.correct, e.fields.printed, e.fields.accuracy)}** |",
        f"| Field precision (values returned that are correct) | "
        f"{_count(e.fields.correct, e.fields.returned, e.fields.precision)} |",
        f"| Labels fully correct | {_rate(e.fully_correct)} |",
        f"| Basis correct | {_rate(e.basis)} |",
        f"| Approximate marks correct | {_rate(e.approximate)} |",
        f"| **Parser ok but not fully correct** | **{len(e.ok_but_wrong)}** |",
        "",
    ]
    lines += _ok_matrix(e) + _by_field(e) + _groups_table("language", e.by_language)
    lines += _groups_table("layout", e.by_layout) + _issues(e) + _failures(e)
    return "\n".join(lines).rstrip() + "\n"


def _ok_matrix(e: Evaluation) -> list[str]:
    m = e.ok_matrix
    return [
        "## Parser `ok` against the ground truth",
        "",
        "`ok` False sends the label to the fallback parser (T28) and flags it to the "
        "contributor. Ok but not fully correct: wrong values that nothing catches.",
        "",
        "| | Fully correct | Not fully correct |",
        "|---|---:|---:|",
        f"| Parser ok | {m[(True, True)]} | **{m[(True, False)]}** |",
        f"| Parser not ok | {m[(False, True)]} | {m[(False, False)]} |",
        "",
    ]


def _by_field(e: Evaluation) -> list[str]:
    lines = [
        "## By field",
        "",
        "| Field | Printed | Correct | Wrong | Missed | Spurious | Accuracy |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    lines += [
        f"| {target.value} | {t.printed} | {t.correct} | {t.wrong} | {t.missed} | "
        f"{t.spurious} | {_percent(t.accuracy)} |"
        for target, t in e.by_field.items()
    ]
    return [*lines, ""]


def _groups_table(kind: str, groups: dict[str, Group]) -> list[str]:
    lines = [f"## By {kind}", ""]
    if not groups:
        return [*lines, "No tags.", ""]
    lines += [
        f"A label can have several {kind} tags.",
        "",
        f"| {kind.capitalize()} | Labels | Fully correct | Field accuracy |",
        "|---|---:|---:|---:|",
    ]
    lines += [
        f"| {name} | {g.labels} | {_rate(g.fully_correct)} | {_percent(g.fields.accuracy)} |"
        for name, g in groups.items()
    ]
    return [*lines, ""]


def _issues(e: Evaluation) -> list[str]:
    lines = ["## Issues reported by the parser", ""]
    if not e.issues:
        return [*lines, "None.", ""]
    lines += ["| Issue | Labels |", "|---|---:|"]
    lines += [f"| {code.value} | {n} |" for code, n in sorted(e.issues.items())]
    return [*lines, ""]


def _failures(e: Evaluation) -> list[str]:
    failing = [r for r in e.results if not r.fully_correct]
    lines = ["## Labels not fully correct", ""]
    if not failing:
        return [*lines, "None.", ""]
    for r in failing:
        t = r.truth
        title = " · ".join(_text(x) for x in (t.product, t.brand) if x) or "unnamed"
        tags = ", ".join((*t.languages, *t.layout)) or _EMPTY
        lines += [
            f"### {t.label_id}: {title}",
            "",
            f"Tags: {tags}. Parser ok: {'yes' if r.parse.ok else 'no'}. "
            f"Issues: {', '.join(_issue_text(r)) or _EMPTY}.",
            "",
        ]
        if not r.basis_correct:
            lines += [f"Basis: expected {_basis(t.basis)}, read {_basis(r.parse.basis)}.", ""]
        wrong = [f for f in r.fields if f.outcome != Outcome.CORRECT]
        if wrong:
            lines += ["| Field | Outcome | Expected | Read |", "|---|---|---:|---:|"]
            lines += [
                f"| {f.field.value} | {f.outcome.value} | {_number(f.expected)} | "
                f"{_number(f.got)} |"
                for f in wrong
            ]
            lines.append("")
    return lines


def _issue_text(result: LabelResult) -> list[str]:
    return [
        i.code.value if i.field is None else f"{i.code.value} ({i.field.value})"
        for i in result.parse.issues
    ]


def _count(part: int, whole: int, percent: float | None) -> str:
    return f"{part} / {whole} ({_percent(percent)})"


def _rate(rate: Rate) -> str:
    return _count(rate.matching, rate.total, rate.percent)


def _percent(percent: float | None) -> str:
    return _EMPTY if percent is None else f"{percent:.1f} %"


def _basis(basis: NutritionBasis | None) -> str:
    return "none (per portion only)" if basis is None else basis.value


def _number(value: Decimal | None) -> str:
    return _EMPTY if value is None else str(value)


def _text(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")
