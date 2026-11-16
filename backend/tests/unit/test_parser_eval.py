"""Label parser evaluation (T27): ground truth loading and checks, field outcomes, metrics
and the Markdown report. The committed evaluation set in eval/labels/ must always load."""

import json
import re
from collections import Counter
from datetime import date
from decimal import Decimal
from pathlib import Path
from typing import Any

import pytest

from app.core.config import REPO_ROOT, Settings
from app.modules.contributions.label_parser import (
    LabelField,
    LabelIssue,
    LabelIssueCode,
    LabelParse,
    parse_label,
)
from app.modules.contributions.llm_parser import LlmReply
from app.modules.contributions.models import FallbackReason
from app.modules.contributions.parser_eval import (
    EvalSet,
    GroundTruth,
    GroundTruthError,
    LabelCase,
    LabelSource,
    Outcome,
    Tally,
    compare,
    evaluate,
    evaluate_with_fallback,
    load_cases,
    parse_ground_truth,
    render_markdown,
)
from app.modules.products.models import NutritionBasis
from scripts import eval_parser

F = LabelField
G100 = NutritionBasis.PER_100G
PHOTO = "https://images.openfoodfacts.org/images/products/619/150/724/9383/nutrition_fr.5.full.jpg"
TODAY = date(2026, 11, 16)


def doc(**overrides: Any) -> dict[str, Any]:
    """A valid reviewed ground truth document."""
    base: dict[str, Any] = {
        "reviewed": True,
        "product": "Biscuits",
        "brand": "Marque",
        "ean": "6191234567890",
        "languages": ["fr", "ar"],
        "layout": ["columns"],
        "basis": "per_100g",
        "values": {"energy_kj": "1958", "sugars_g": "29", "salt_g": "0.62"},
        "approximate": [],
        "notes": None,
    }
    return base | overrides


def truth(values: dict[LabelField, str], **kwargs: Any) -> GroundTruth:
    return GroundTruth(
        label_id=kwargs.pop("label_id", "tn-001"),
        basis=kwargs.pop("basis", G100),
        values={f: Decimal(v) for f, v in values.items()},
        **kwargs,
    )


def parsed(values: dict[LabelField, str], **kwargs: Any) -> LabelParse:
    return LabelParse(
        values={f: Decimal(v) for f, v in values.items()},
        basis=kwargs.pop("basis", G100),
        **kwargs,
    )


# ---------------------------------------------------------------- the committed set


def test_committed_evaluation_set_loads_and_is_reviewed() -> None:
    eval_set = load_cases(REPO_ROOT / "eval" / "labels")

    assert eval_set.not_reviewed == ()
    for case in eval_set.cases:
        assert case.ocr_text.strip(), case.truth.label_id


# ---------------------------------------------------------------- ground truth


def test_ground_truth_is_read() -> None:
    t = parse_ground_truth("tn-001", doc(approximate=["salt_g"]))

    assert t == GroundTruth(
        label_id="tn-001",
        basis=G100,
        values={F.ENERGY_KJ: Decimal(1958), F.SUGARS: Decimal(29), F.SALT: Decimal("0.62")},
        approximate=frozenset({F.SALT}),
        languages=("fr", "ar"),
        layout=("columns",),
        product="Biscuits",
        brand="Marque",
        ean="6191234567890",
    )


def test_optional_keys_can_be_left_out() -> None:
    t = parse_ground_truth("x", {"reviewed": True, "basis": "per_100ml", "values": {}})

    assert t == GroundTruth(label_id="x", basis=NutritionBasis.PER_100ML, values={})
    assert t.source == LabelSource.OWN


def test_open_food_facts_photo() -> None:
    t = parse_ground_truth("x", doc(source="open-food-facts", photo_url=PHOTO))

    assert t is not None
    assert (t.source, t.photo_url, t.ean) == (
        LabelSource.OPEN_FOOD_FACTS,
        PHOTO,
        "6191234567890",
    )


def test_own_photo_may_have_a_photo_url() -> None:
    t = parse_ground_truth("x", doc(source="own", photo_url=PHOTO))

    assert t is not None
    assert t.photo_url == PHOTO


def test_empty_strings_are_none() -> None:
    t = parse_ground_truth("x", doc(product="", brand=""))

    assert t is not None
    assert (t.product, t.brand) == (None, None)


def test_per_portion_only_label_has_no_values() -> None:
    t = parse_ground_truth("x", doc(basis=None, values={}))

    assert t is not None
    assert t.basis is None


def test_not_reviewed_is_skipped() -> None:
    assert parse_ground_truth("x", {"reviewed": False, "values": {"bogus": 1}}) is None


@pytest.mark.parametrize(
    ("label_id", "data", "message"),
    [
        ("Tn 1", doc(), "file name"),
        ("x", [], "JSON object"),
        ("x", doc(extra=1), "unknown keys ['extra']"),
        ("x", doc(reviewed="yes"), '"reviewed"'),
        ("x", {k: v for k, v in doc().items() if k != "reviewed"}, '"reviewed"'),
        ("x", doc(basis="per_portion"), '"basis"'),
        ("x", doc(values=[]), '"values" must be an object'),
        ("x", doc(values={"sugar": "1"}), "unknown field 'sugar'"),
        ("x", doc(values={"sugars_g": 1.5}), "must be a string"),
        ("x", doc(values={"sugars_g": "1,5"}), "decimal number"),
        ("x", doc(values={"sugars_g": "-1"}), "decimal number"),
        ("x", doc(values={"sugars_g": "NaN"}), "decimal number"),
        ("x", doc(values={"sugars_g": "Infinity"}), "decimal number"),
        ("x", doc(values={"sugars_g": " 1"}), "decimal number"),
        ("x", doc(basis=None), 'with "basis": null'),
        ("x", doc(approximate="salt_g"), '"approximate" must be a list'),
        ("x", doc(approximate=["fibre_g"]), "needs a value"),
        ("x", doc(ean="123"), '"ean"'),
        ("x", doc(ean=6191234567890), '"ean" must be a string'),
        ("x", doc(notes=1), '"notes"'),
        ("x", doc(languages=["FR"]), '"languages"'),
        ("x", doc(languages="fr"), '"languages"'),
        ("x", doc(languages=["fr", "fr"]), "duplicates"),
        ("x", doc(layout=["two columns"]), '"layout"'),
        ("x", doc(source="web"), '"source" must be own or open-food-facts'),
        ("x", doc(photo_url="http://images.openfoodfacts.org/a.jpg"), '"photo_url"'),
        ("x", doc(photo_url="https://example.org/a.jpg"), '"photo_url"'),
        ("x", doc(photo_url="https://evilopenfoodfacts.org/a.jpg"), '"photo_url"'),
        ("x", doc(photo_url=1), '"photo_url" must be a string'),
        ("x", doc(source="open-food-facts", photo_url=None), "attribution"),
        ("x", doc(source="open-food-facts", photo_url=PHOTO, ean=None), "attribution"),
    ],
)
def test_invalid_ground_truth_is_refused(label_id: str, data: object, message: str) -> None:
    with pytest.raises(GroundTruthError, match=re.escape(message)) as error:
        parse_ground_truth(label_id, data)

    assert str(error.value).startswith(f"{label_id}.json: ")


def write(directory: Path, label_id: str, data: object, text: str | None = "OCR") -> None:
    (directory / f"{label_id}.json").write_text(json.dumps(data), encoding="utf-8")
    if text is not None:
        (directory / f"{label_id}.txt").write_text(text, encoding="utf-8")


def test_load_cases_sorted_with_not_reviewed_listed(tmp_path: Path) -> None:
    write(tmp_path, "tn-002", doc(), "Sel 1 g")
    write(tmp_path, "tn-001", doc(product="First"), "Énergie")
    write(tmp_path, "tn-003", {"reviewed": False})
    (tmp_path / "tn-001.jpg").write_bytes(b"photo")

    eval_set = load_cases(tmp_path)

    assert [c.truth.label_id for c in eval_set.cases] == ["tn-001", "tn-002"]
    assert eval_set.cases[0].ocr_text == "Énergie"
    assert eval_set.cases[0].truth.product == "First"
    assert eval_set.not_reviewed == ("tn-003",)


def test_load_cases_needs_the_ocr_text(tmp_path: Path) -> None:
    write(tmp_path, "tn-001", doc(), text=None)

    with pytest.raises(GroundTruthError, match=r"tn-001\.txt is missing"):
        load_cases(tmp_path)


def test_load_cases_refuses_broken_json(tmp_path: Path) -> None:
    (tmp_path / "tn-001.json").write_text("{", encoding="utf-8")

    with pytest.raises(GroundTruthError, match=r"tn-001\.json: not valid JSON"):
        load_cases(tmp_path)


# ---------------------------------------------------------------- outcomes


def outcomes(t: GroundTruth, p: LabelParse) -> dict[LabelField, Outcome]:
    return {r.field: r.outcome for r in compare(t, p).fields}


def test_each_outcome() -> None:
    t = truth({F.ENERGY_KJ: "1958", F.FAT: "18", F.SUGARS: "29"})
    p = parsed({F.ENERGY_KJ: "1958", F.FAT: "1.8", F.PROTEIN: "6.5"})

    result = compare(t, p)

    assert [(r.field, r.outcome, r.expected, r.got) for r in result.fields] == [
        (F.ENERGY_KJ, Outcome.CORRECT, Decimal(1958), Decimal(1958)),
        (F.FAT, Outcome.WRONG, Decimal(18), Decimal("1.8")),
        (F.SUGARS, Outcome.MISSED, Decimal(29), None),
        (F.PROTEIN, Outcome.SPURIOUS, None, Decimal("6.5")),
    ]
    assert not result.fully_correct


def test_values_compare_as_decimals() -> None:
    t = truth({F.SALT: "1.50", F.FAT: "0"})
    p = parsed({F.SALT: "1.5", F.FAT: "0.0"})

    assert set(outcomes(t, p).values()) == {Outcome.CORRECT}
    assert compare(t, p).fully_correct


def test_derived_values_are_not_spurious() -> None:
    t = truth({F.ENERGY_KCAL: "467", F.SODIUM: "0.32"})
    p = parsed(
        {F.ENERGY_KCAL: "467", F.ENERGY_KJ: "1961", F.SODIUM: "0.32", F.SALT: "0.8"},
        derived=frozenset({F.ENERGY_KJ, F.SALT}),
    )

    assert outcomes(t, p) == {F.ENERGY_KCAL: Outcome.CORRECT, F.SODIUM: Outcome.CORRECT}
    assert compare(t, p).fully_correct


def test_a_derived_value_for_a_printed_field_is_compared() -> None:
    t = truth({F.SALT: "0.82", F.SODIUM: "0.32"})
    p = parsed({F.SALT: "0.8", F.SODIUM: "0.32"}, derived=frozenset({F.SALT}))

    assert outcomes(t, p)[F.SALT] == Outcome.WRONG


def test_wrong_basis_is_not_fully_correct() -> None:
    t = truth({F.SALT: "1"})
    p = parsed({F.SALT: "1"}, basis=None)

    result = compare(t, p)

    assert outcomes(t, p) == {F.SALT: Outcome.CORRECT}
    assert not result.basis_correct
    assert not result.fully_correct


def test_per_portion_only_refused_is_fully_correct() -> None:
    t = truth({}, basis=None)
    p = parsed({}, basis=None, issues=(LabelIssue(LabelIssueCode.PER_PORTION_ONLY),))

    result = compare(t, p)

    assert result.fields == ()
    assert result.fully_correct


def test_approximate_marks_are_compared_on_printed_fields() -> None:
    t = truth({F.SODIUM: "0.1", F.SUGARS: "0"}, approximate=frozenset({F.SODIUM}))
    agree = parsed(
        {F.SODIUM: "0.1", F.SALT: "0.25", F.SUGARS: "0"},
        derived=frozenset({F.SALT}),
        approximate=frozenset({F.SODIUM, F.SALT}),
    )
    disagree = parsed({F.SODIUM: "0.1", F.SUGARS: "0"}, approximate=frozenset({F.SUGARS}))

    assert compare(t, agree).approximate_correct
    assert not compare(t, disagree).approximate_correct


# ---------------------------------------------------------------- metrics


def test_tally_rates() -> None:
    t = Tally(correct=6, wrong=1, missed=1, spurious=2)

    assert (t.printed, t.returned) == (8, 9)
    assert t.accuracy == 75.0
    assert t.precision == pytest.approx(66.667, abs=0.001)
    assert Tally().accuracy is None
    assert Tally().precision is None


OK_TEXT = "ok"
CASES = {
    # label id -> (ground truth, what the fake parser returns)
    "tn-001": (  # fully correct, ok
        truth({F.SUGARS: "29", F.SALT: "0.62"}, languages=("fr",), layout=("columns",)),
        parsed({F.SUGARS: "29", F.SALT: "0.62"}),
    ),
    "tn-002": (  # one wrong field, still ok: the costly case
        truth(
            {F.SUGARS: "29", F.SALT: "0.62"},
            languages=("fr", "ar"),
            product="Gaufrettes | chocolat",
            brand="Marque",
        ),
        parsed({F.SUGARS: "2.9", F.SALT: "0.62"}),
    ),
    "tn-003": (  # missed, spurious and wrong basis, not ok; an Open Food Facts photo
        truth(
            {F.SUGARS: "5", F.FAT: "3"},
            languages=("ar",),
            layout=("columns", "curved"),
            source=LabelSource.OPEN_FOOD_FACTS,
            photo_url=PHOTO,
            ean="6191507249383",
        ),
        parsed(
            {F.SUGARS: "5", F.FIBRE: "3"},
            basis=None,
            issues=(
                LabelIssue(LabelIssueCode.MISSING, F.FAT),
                LabelIssue(LabelIssueCode.MISSING, F.SALT),
                LabelIssue(LabelIssueCode.BASIS_UNKNOWN),
            ),
        ),
    ),
    "tn-004": (  # fully correct but not ok (a mandatory value isn't printed)
        truth({F.SUGARS: "12", F.PROTEIN: "1"}),
        parsed(
            {F.SUGARS: "12", F.PROTEIN: "1"},
            issues=(LabelIssue(LabelIssueCode.MISSING, F.FAT),),
        ),
    ),
}


def run(cases: dict[str, tuple[GroundTruth, LabelParse]], **kwargs: Any) -> Any:
    eval_set = EvalSet(
        tuple(
            LabelCase(GroundTruth(**{**vars(t), "label_id": label_id}), label_id)
            for label_id, (t, _) in cases.items()
        ),
        **kwargs,
    )
    return evaluate(eval_set, lambda text: cases[text][1], parser_name="fake")


def test_evaluate_metrics() -> None:
    e = run(CASES, not_reviewed=("tn-005",))

    assert [r.truth.label_id for r in e.results] == ["tn-001", "tn-002", "tn-003", "tn-004"]
    assert e.fields == Tally(correct=6, wrong=1, missed=1, spurious=1)
    assert e.by_field == {
        F.FAT: Tally(missed=1),
        F.SUGARS: Tally(correct=3, wrong=1),
        F.FIBRE: Tally(spurious=1),
        F.PROTEIN: Tally(correct=1),
        F.SALT: Tally(correct=2),
    }
    assert (e.basis.matching, e.basis.total) == (3, 4)
    assert (e.fully_correct.matching, e.fully_correct.total) == (2, 4)
    assert (e.approximate.matching, e.approximate.total) == (4, 4)
    assert e.ok_matrix == Counter(
        {(True, True): 1, (True, False): 1, (False, True): 1, (False, False): 1}
    )
    assert [r.truth.label_id for r in e.ok_but_wrong] == ["tn-002"]
    assert e.issues == Counter({LabelIssueCode.MISSING: 2, LabelIssueCode.BASIS_UNKNOWN: 1})
    assert e.not_reviewed == ("tn-005",)


def test_groups_by_language_and_layout() -> None:
    e = run(CASES)

    assert list(e.by_language) == ["ar", "fr"]
    assert e.by_language["fr"].labels == 2
    assert e.by_language["fr"].fully_correct.matching == 1
    assert e.by_language["fr"].fields == Tally(correct=3, wrong=1)
    assert e.by_language["ar"].labels == 2
    assert e.by_language["ar"].fully_correct.matching == 0
    assert list(e.by_layout) == ["columns", "curved"]
    assert e.by_layout["columns"].labels == 2
    assert list(e.by_source) == ["open-food-facts", "own"]
    assert e.by_source["own"].labels == 3
    assert e.by_source["own"].fully_correct.matching == 2
    assert e.by_source["open-food-facts"].fields == Tally(correct=1, missed=1, spurious=1)


def test_empty_evaluation() -> None:
    e = evaluate(EvalSet(()), parse_label, parser_name="rules")

    assert e.fields == Tally()
    assert e.by_field == {}
    assert e.fully_correct.percent is None
    report = render_markdown(e, generated_on=TODAY, source="nothing")
    assert "| Labels | 0 |" in report
    assert "| **Field accuracy** (printed fields read correctly) | **0 / 0 (-)** |" in report
    assert report.count("No tags.") == 2
    assert "## By photo source\n\nNo labels." in report
    assert report.endswith("## Labels not fully correct\n\nNone.\n")


def test_evaluate_with_the_rules_parser() -> None:
    text = "Valeurs nutritionnelles pour 100 g\nSel 1,5 g\nSucres 4 g"
    case = LabelCase(truth({F.SALT: "1.5", F.SUGARS: "4"}), text)

    e = evaluate(EvalSet((case,)), parse_label, parser_name="rules")

    assert e.fields == Tally(correct=2)
    assert not e.results[0].parse.ok  # mandatory values missing


# ---------------------------------------------------------------- Markdown


def test_report() -> None:
    report = render_markdown(run(CASES, not_reviewed=("tn-005",)), generated_on=TODAY, source="x")

    assert report.startswith("# Label parser evaluation: `fake`\n\nGenerated 2026-11-16 from x: 4")
    assert "> 1 labels have no ground truth yet and are left out: tn-005." in report
    assert "| **Field accuracy** (printed fields read correctly) | **6 / 8 (75.0 %)** |" in report
    assert "| Field precision (values returned that are correct) | 6 / 8 (75.0 %) |" in report
    assert "| Labels fully correct | 2 / 4 (50.0 %) |" in report
    assert "| **Parser ok but not fully correct** | **1** |" in report
    assert "| Parser ok | 1 | **1** |" in report
    assert "| Parser not ok | 1 | 1 |" in report
    assert "| sugars_g | 4 | 3 | 1 | 0 | 0 | 75.0 % |" in report
    assert "| fibre_g | 0 | 0 | 0 | 0 | 1 | - |" in report
    assert "| ar | 2 | 0 / 2 (0.0 %) | 50.0 % |" in report
    assert "| curved | 1 | 0 / 1 (0.0 %) | 50.0 % |" in report
    assert "| missing | 2 |" in report
    assert "CC BY-SA 3.0; each label below links to its photo" in report
    assert "| own | 3 | 2 / 3 (66.7 %) | 83.3 % |" in report
    assert "| open-food-facts | 1 | 0 / 1 (0.0 %) | 50.0 % |" in report
    assert f"Photo: <{PHOTO}> (Open Food Facts, CC BY-SA 3.0)." in report
    assert report.count("Photo: <") == 1
    assert "### tn-002: Gaufrettes \\| chocolat · Marque" in report
    assert "Tags: fr, ar. Parser ok: yes. Issues: -." in report
    assert "| sugars_g | wrong | 29 | 2.9 |" in report
    assert "### tn-003: unnamed" in report
    assert "Issues: missing (total_fat_g), missing (salt_g), basis_unknown." in report
    assert "Basis: expected per_100g, read none (per portion only)." in report
    assert "| total_fat_g | missed | 3 | - |" in report
    assert "| fibre_g | spurious | - | 3 |" in report
    assert "### tn-001" not in report
    assert "### tn-004" not in report
    assert report.endswith("\n")
    assert not report.endswith("\n\n")


def test_report_without_failures_or_issues() -> None:
    report = render_markdown(run({"tn-001": CASES["tn-001"]}), generated_on=TODAY, source="x")

    assert "## Issues reported by the parser\n\nNone." in report
    assert report.endswith("## Labels not fully correct\n\nNone.\n")
    assert "left out" not in report


def test_a_wrong_basis_alone_lists_no_field_table() -> None:
    case = (truth({F.SALT: "1"}), parsed({F.SALT: "1"}, basis=NutritionBasis.PER_100ML))

    report = render_markdown(run({"tn-001": case}), generated_on=TODAY, source="x")

    assert report.endswith("Basis: expected per_100g, read per_100ml.\n")


# ---------------------------------------------------------------- script


def test_script_writes_the_report(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    labels = tmp_path / "labels"
    labels.mkdir()
    write(labels, "tn-001", doc(values={"salt_g": "1.5"}), "Pour 100 g\nSel 1,5 g")
    write(labels, "tn-002", {"reviewed": False})
    output = tmp_path / "reports" / "eval.md"

    path = eval_parser.main(labels, output, "rules", "the test set")

    assert path == output
    assert output.read_text(encoding="utf-8").startswith(
        "# Label parser evaluation: `rules`\n\nGenerated "
    )
    assert "from the test set: 1 labels" in output.read_text(encoding="utf-8")
    assert (
        capsys.readouterr()
        .out.strip()
        .endswith("1 labels, fields correct 1/1, fully correct 1/1, ok but wrong 0, not reviewed 1")
    )


# ---------------------------------------------------------------- rules + LLM fallback (T28)

TABLE = """Valeurs nutritionnelles pour 100 g
Énergie 1386 kJ / 330 kcal
Matières grasses 10 g
dont acides gras saturés 2 g
Glucides {carbohydrates}
dont sucres 5 g
Protéines 10 g
Sel 1 g"""
READABLE = TABLE.format(carbohydrates="50 g")
MISREAD = TABLE.format(carbohydrates="508")  # `50g` read as `508`: the rules parser fails
MISREAD_WITH_FIBRE = MISREAD + "\nFibres 3 g"
PRINTED = {
    F.ENERGY_KJ: "1386",
    F.ENERGY_KCAL: "330",
    F.FAT: "10",
    F.SATURATED_FAT: "2",
    F.CARBOHYDRATES: "50",
    F.SUGARS: "5",
    F.PROTEIN: "10",
    F.SALT: "1",
}


def llm_answer(**changes: Any) -> dict[str, Any]:
    values: dict[str, Any] = {
        "energy_kj": {"amount": 1386},
        "energy_kcal": {"amount": 330},
        "total_fat_g": {"amount": 10, "unit": "g"},
        "saturated_fat_g": {"amount": 2, "unit": "g"},
        "carbohydrates_g": {"amount": 50, "unit": "g"},
        "sugars_g": {"amount": 5, "unit": "g"},
        "fibre_g": None,
        "protein_g": {"amount": 10, "unit": "g"},
        "salt_g": {"amount": 1, "unit": "g"},
        "sodium_g": None,
    }
    return {
        "table_found": True,
        "basis": "per_100g",
        "values": values | changes,
        "approximate": [],
    }


class FakeLlm:
    model = "claude-test"

    def __init__(self, answers: dict[str, dict[str, Any]]) -> None:
        self.answers = answers
        self.texts: list[str] = []

    async def read(self, ocr_text: str) -> LlmReply:
        self.texts.append(ocr_text)
        return LlmReply(json.dumps(self.answers[ocr_text]), "end_turn", self.model)


ANSWERS = {
    MISREAD: llm_answer(),
    # Protein 12 is not in the text: rejected, the rules reading is kept.
    MISREAD_WITH_FIBRE: llm_answer(protein_g={"amount": 12, "unit": "g"}),
}
FALLBACK_SET = EvalSet(
    (
        LabelCase(truth(PRINTED, label_id="tn-001"), READABLE),
        LabelCase(truth(PRINTED, label_id="tn-002"), MISREAD),
        LabelCase(truth(PRINTED | {F.FIBRE: "3"}, label_id="tn-003"), MISREAD_WITH_FIBRE),
    )
)


async def test_evaluate_with_fallback() -> None:
    llm = FakeLlm(ANSWERS)

    e, use = await evaluate_with_fallback(FALLBACK_SET, llm, time_limit=1)

    assert sorted(llm.texts) == sorted(ANSWERS)  # never asked for the readable label
    assert use.outcomes == {"tn-002": None, "tn-003": FallbackReason.UNGROUNDED_VALUE}
    assert (use.asked, use.accepted) == (2, frozenset({"tn-002"}))
    assert use.rejected == Counter({FallbackReason.UNGROUNDED_VALUE: 1})
    assert e.parser == "rules+llm"
    assert e.fields == Tally(correct=24, wrong=1)
    assert [r.fully_correct for r in e.results] == [True, True, False]
    assert e.results[2].parse.values[F.CARBOHYDRATES] == Decimal(508)  # the rules reading


async def test_fallback_report() -> None:
    baseline = evaluate(FALLBACK_SET, parse_label, parser_name="rules")
    e, use = await evaluate_with_fallback(FALLBACK_SET, FakeLlm(ANSWERS), time_limit=1)

    report = render_markdown(e, generated_on=TODAY, source="x", baseline=baseline, fallback=use)

    assert report.startswith("# Label parser evaluation: `rules+llm`")
    assert "## Compared with `rules` alone\n\n| | `rules` | `rules+llm` |" in report
    assert "| Field accuracy | 23 / 25 (92.0 %) | 24 / 25 (96.0 %) |" in report
    assert "| Labels fully correct | 1 / 3 (33.3 %) | 2 / 3 (66.7 %) |" in report
    assert "| **Ok but not fully correct** | 0 | 0 |" in report
    assert "Asked for the 2 labels whose rules reading is not ok." in report
    assert "| Reading accepted | 1 |" in report
    assert "| **Accepted but not fully correct** | **0** |" in report
    assert "| Manual entry: ungrounded_value | 1 |" in report
    assert "### tn-003" in report
    assert "LLM fallback: ungrounded_value (rules reading kept)." in report
    assert "Read by the LLM fallback." not in report  # tn-002 is fully correct


async def test_fallback_report_marks_llm_readings_that_are_wrong() -> None:
    wrong_truth = EvalSet((LabelCase(truth(PRINTED | {F.SUGARS: "4"}), MISREAD),))
    baseline = evaluate(wrong_truth, parse_label, parser_name="rules")
    e, use = await evaluate_with_fallback(wrong_truth, FakeLlm(ANSWERS), time_limit=1)

    report = render_markdown(e, generated_on=TODAY, source="x", baseline=baseline, fallback=use)

    assert "| **Accepted but not fully correct** | **1** |" in report
    assert "| **Ok but not fully correct** | 0 | 1 |" in report
    assert "Read by the LLM fallback." in report


def _settings(**values: Any) -> Settings:
    return Settings(
        _env_file=None,  # type: ignore[call-arg]
        database_url="postgresql+asyncpg://u:p@db:5432/q",  # type: ignore[arg-type]
        redis_url="redis://cache:6379/0",  # type: ignore[arg-type]
        **values,
    )


def _labels(directory: Path) -> Path:
    directory.mkdir()
    for case in FALLBACK_SET.cases:
        values = {f.value: str(v) for f, v in case.truth.values.items()}
        write(directory, case.truth.label_id, doc(values=values), case.ocr_text)
    return directory


def test_script_with_the_fallback(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(eval_parser, "REPORTS_DIR", tmp_path / "reports")
    monkeypatch.setattr(eval_parser, "get_settings", _settings)
    labels = _labels(tmp_path / "labels")

    path = eval_parser.main(labels, None, "rules+llm", "x", llm=FakeLlm(ANSWERS))

    assert path.parent == tmp_path / "reports"
    assert path.name.startswith("label-parser-eval-rules-llm-")
    assert "## Compared with `rules` alone" in path.read_text(encoding="utf-8")
    assert (
        capsys.readouterr()
        .out.strip()
        .endswith("fully correct 2/3, ok but wrong 0, not reviewed 0, LLM accepted 1/2")
    )


def test_script_fallback_needs_a_key(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(eval_parser, "get_settings", _settings)
    labels = _labels(tmp_path / "labels")

    with pytest.raises(SystemExit, match="LLM_API_KEY"):
        eval_parser.main(labels, tmp_path / "r.md", "rules+llm", "x")

    assert not (tmp_path / "r.md").exists()


async def test_cached_llm_answers_again_without_asking(tmp_path: Path) -> None:
    llm = FakeLlm(ANSWERS)
    cached = eval_parser.CachedLabelLlm(llm, tmp_path / "cache", effort="medium")
    other_effort = eval_parser.CachedLabelLlm(llm, tmp_path / "cache", effort="high")

    first = await cached.read(MISREAD)
    again = await cached.read(MISREAD)
    await other_effort.read(MISREAD)

    assert first == again
    assert cached.model == "claude-test"
    assert llm.texts == [MISREAD, MISREAD]  # another effort is another request
    assert len(list((tmp_path / "cache").glob("*.json"))) == 2
