"""Rule-based label parser: every OCR text fixture in tests/fixtures/labels/ (what the label
says, written by hand), each sanity rule at and just past its limit, and the text
normalisation."""

import json
from decimal import Decimal
from pathlib import Path
from typing import Any

import pytest

from app.modules.contributions.label_parser import (
    LabelField,
    LabelIssue,
    LabelIssueCode,
    LabelParse,
    checked_parse,
    label_parse_result,
    normalize,
    parse_label,
)
from app.modules.products.models import NutritionBasis

FIXTURES = Path(__file__).resolve().parents[1] / "fixtures" / "labels"
CASES = sorted(FIXTURES.glob("*.json"))
ARABIC_10_5 = "".join(map(chr, (0x0661, 0x0660, 0x066B, 0x0665)))  # 10.5
EXTENDED_12 = chr(0x06F1) + chr(0x06F2)  # 12


def expected(path: Path) -> dict[str, Any]:
    data: dict[str, Any] = json.loads(path.read_text(encoding="utf-8"))
    return data


def test_there_are_enough_fixtures() -> None:
    assert len(CASES) >= 20
    for path in CASES:
        assert path.with_suffix(".txt").exists()


@pytest.mark.parametrize("path", CASES, ids=[p.stem for p in CASES])
def test_fixture(path: Path) -> None:
    want = expected(path)

    parsed = parse_label(path.with_suffix(".txt").read_text(encoding="utf-8"))

    assert {f.value: v for f, v in parsed.values.items()} == {
        name: Decimal(value) for name, value in want["values"].items()
    }
    assert parsed.basis == (None if want["basis"] is None else NutritionBasis(want["basis"]))
    assert sorted(parsed.derived) == want["derived"]
    assert sorted(parsed.approximate) == want["approximate"]
    assert {(i.code.value, None if i.field is None else i.field.value) for i in parsed.issues} == {
        tuple(issue) for issue in want["issues"]
    }
    assert parsed.ok is want["ok"]


# ---------------------------------------------------------------- sanity rules


def table(**values: str) -> str:
    """A French per-100 g table with the given lines (`name -> "value unit"`)."""
    names = {
        "energy": "Énergie",
        "fat": "Matières grasses",
        "saturated": "dont acides gras saturés",
        "carbohydrates": "Glucides",
        "sugars": "dont sucres",
        "fibre": "Fibres",
        "protein": "Protéines",
        "salt": "Sel",
    }
    lines = ["Valeurs nutritionnelles pour 100 g"]
    lines += [f"{names[name]} {value}" for name, value in values.items()]
    return "\n".join(lines)


# Consistent defaults: 4*50 + 4*10 + 9*10 = 330 kcal.
BASE = {
    "energy": "1386 kJ / 330 kcal",
    "fat": "10 g",
    "saturated": "2 g",
    "carbohydrates": "50 g",
    "sugars": "5 g",
    "protein": "10 g",
    "salt": "1 g",
}


def parse(**overrides: str) -> LabelParse:
    return parse_label(table(**(BASE | overrides)))


def codes(parsed: LabelParse) -> set[LabelIssueCode]:
    return {issue.code for issue in parsed.issues}


def test_consistent_table_is_ok() -> None:
    parsed = parse()

    assert parsed.ok
    assert parsed.issues == ()


@pytest.mark.parametrize(("sugars", "flagged"), [("50 g", False), ("50,1 g", True)])
def test_sugars_at_most_carbohydrates(sugars: str, flagged: bool) -> None:
    parsed = parse(sugars=sugars)

    assert (
        LabelIssue(LabelIssueCode.SUGARS_OVER_CARBOHYDRATES, LabelField.SUGARS) in parsed.issues
    ) is flagged
    assert parsed.ok is not flagged


@pytest.mark.parametrize(("saturated", "flagged"), [("10 g", False), ("10,01 g", True)])
def test_saturated_at_most_fat(saturated: str, flagged: bool) -> None:
    parsed = parse(saturated=saturated)

    assert (
        LabelIssue(LabelIssueCode.SATURATED_OVER_FAT, LabelField.SATURATED_FAT) in parsed.issues
    ) is flagged


@pytest.mark.parametrize(("salt", "flagged"), [("100 g", False), ("100,1 g", True)])
def test_each_amount_at_most_100_g(salt: str, flagged: bool) -> None:
    parsed = parse(salt=salt)

    assert (LabelIssue(LabelIssueCode.AMOUNT_OVER_100, LabelField.SALT) in parsed.issues) is flagged


@pytest.mark.parametrize(("fibre", "flagged"), [("31 g", False), ("31,1 g", True)])
def test_macros_at_most_102_g(fibre: str, flagged: bool) -> None:
    # 10 fat + 50 carbohydrate + 10 protein + 1 salt = 71 g, plus fibre; the declared
    # energy follows the fibre (2 kcal/g) so only the sum can be flagged.
    kcal = 330 + 2 * Decimal(fibre.split(maxsplit=1)[0].replace(",", "."))
    parsed = parse(fibre=fibre, energy=f"{kcal} kcal")

    assert (LabelIssueCode.MACROS_OVER_100 in codes(parsed)) is flagged
    assert LabelIssueCode.ENERGY_MACROS_MISMATCH not in codes(parsed)


SMALL = {  # expected 4 * 20 = 80 kcal = 17 * 20 = 340 kJ
    "fat": "0 g",
    "saturated": "0 g",
    "carbohydrates": "20 g",
    "sugars": "1 g",
    "protein": "0 g",
}


@pytest.mark.parametrize(
    ("kcal", "flagged"),
    [
        ("100", False),  # 20 off; 15 % of 100 is 15, so the 20 kcal floor applies
        ("101", True),  # 21 off; slack max(15.15, 20)
        ("60", False),  # 20 off; slack max(9, 20)
        ("59", True),
    ],
)
def test_energy_slack_is_at_least_20_kcal(kcal: str, flagged: bool) -> None:
    parsed = parse(energy=f"{kcal} kcal", **SMALL)

    assert (LabelIssueCode.ENERGY_MACROS_MISMATCH in codes(parsed)) is flagged


LARGE = {  # expected 4 * 30 + 4 * 5 + 9 * 60 = 680 kcal
    "fat": "60 g",
    "saturated": "10 g",
    "carbohydrates": "30 g",
    "protein": "5 g",
}


@pytest.mark.parametrize(
    ("kcal", "flagged"),
    [
        ("800", False),  # 120 off, slack 15 % of 800 = 120
        ("801", True),  # 121 off, slack 120.15
        ("592", False),  # 88 off, slack 88.8
        ("591", True),  # 89 off, slack 88.65
    ],
)
def test_energy_slack_is_15_percent_of_the_declared_value(kcal: str, flagged: bool) -> None:
    parsed = parse(energy=f"{kcal} kcal", **LARGE)

    assert (
        LabelIssue(LabelIssueCode.ENERGY_MACROS_MISMATCH, LabelField.ENERGY_KCAL) in parsed.issues
    ) is flagged


@pytest.mark.parametrize(
    ("kj", "flagged"),
    [
        ("424", False),  # 84 off; 15 % of 424 is 63.6, so the 84 kJ floor applies
        ("425", True),
    ],
)
def test_energy_in_kj_alone_uses_the_kj_factors(kj: str, flagged: bool) -> None:
    parsed = parse(energy=f"{kj} kJ", **SMALL)

    assert (
        LabelIssue(LabelIssueCode.ENERGY_MACROS_MISMATCH, LabelField.ENERGY_KJ) in parsed.issues
    ) is flagged


def test_derived_kj_is_not_checked_against_kcal() -> None:
    parsed = parse(energy="330 kcal")

    assert parsed.derived == {LabelField.ENERGY_KJ}
    assert parsed.values[LabelField.ENERGY_KJ] == Decimal(1386)
    assert parsed.ok


def test_energy_is_not_checked_without_the_macros() -> None:
    values = {k: v for k, v in BASE.items() if k != "protein"}

    parsed = parse_label(table(**(values | {"energy": "5 kcal"})))

    assert LabelIssueCode.ENERGY_MACROS_MISMATCH not in codes(parsed)
    assert LabelIssue(LabelIssueCode.MISSING, LabelField.PROTEIN) in parsed.issues


@pytest.mark.parametrize(
    ("kj", "flagged"),
    [
        ("1306", False),  # 4.35 * 330 + 20 = 1455.5; 3.9 * 330 - 20 = 1267
        ("1267", False),
        ("1266", True),
        ("1455", False),
        ("1456", True),
    ],
)
def test_kj_and_kcal_must_agree(kj: str, flagged: bool) -> None:
    parsed = parse(energy=f"{kj} kJ / 330 kcal")

    assert (
        LabelIssue(LabelIssueCode.ENERGY_UNITS_MISMATCH, LabelField.ENERGY_KJ) in parsed.issues
    ) is flagged


def test_mandatory_values_must_be_read() -> None:
    parsed = parse_label(table(energy="1386 kJ / 330 kcal", fat="10 g"))

    missing = {i.field for i in parsed.issues if i.code == LabelIssueCode.MISSING}
    assert missing == {
        LabelField.SATURATED_FAT,
        LabelField.CARBOHYDRATES,
        LabelField.SUGARS,
        LabelField.PROTEIN,
        LabelField.SALT,
    }
    assert not parsed.ok


def test_missing_energy_is_reported() -> None:
    values = {k: v for k, v in BASE.items() if k != "energy"}

    parsed = parse_label(table(**values))

    assert LabelIssue(LabelIssueCode.MISSING, LabelField.ENERGY_KJ) in parsed.issues


def test_fibre_is_optional() -> None:
    assert parse().ok
    assert LabelField.FIBRE not in parse().values


# ---------------------------------------------------------------- reading details


def test_energy_without_a_unit_is_not_guessed() -> None:
    parsed = parse(energy="1386")

    assert LabelIssue(LabelIssueCode.ENERGY_UNIT_UNKNOWN, LabelField.ENERGY_KJ) in parsed.issues
    assert LabelField.ENERGY_KJ not in parsed.values


def test_salt_in_mg() -> None:
    assert parse(salt="450 mg").values[LabelField.SALT] == Decimal("0.45")


def test_salt_and_sodium_both_read() -> None:
    parsed = parse_label(table(**BASE) + "\nSodium 0,4 g")

    assert parsed.values[LabelField.SALT] == Decimal(1)
    assert parsed.values[LabelField.SODIUM] == Decimal("0.4")
    assert parsed.derived == frozenset()


def test_approximate_sodium_makes_salt_approximate() -> None:
    values = {k: v for k, v in BASE.items() if k != "salt"}

    parsed = parse_label(table(**values) + "\nSodium < 0,1 g")

    assert parsed.values[LabelField.SALT] == Decimal("0.25")
    assert parsed.approximate == {LabelField.SODIUM, LabelField.SALT}


def test_portion_column_without_values_is_uncertain() -> None:
    text = "Par portion (30 g) Pour 100 g\nÉnergie 1386 kJ / 330 kcal\nMatières grasses 10 g"

    parsed = parse_label(text)

    assert LabelIssue(LabelIssueCode.COLUMN_UNCERTAIN, LabelField.FAT) in parsed.issues
    assert LabelIssue(LabelIssueCode.COLUMN_UNCERTAIN, LabelField.ENERGY_KJ) in parsed.issues
    assert LabelField.FAT not in parsed.values


def test_names_without_enough_values_are_uncertain() -> None:
    text = "Pour 100 g\nÉnergie 1386 kJ / 330 kcal\nGlucides\ndont sucres\nProtéines\n50 g"

    parsed = parse_label(text)

    assert LabelIssue(LabelIssueCode.COLUMN_UNCERTAIN, LabelField.CARBOHYDRATES) in parsed.issues
    assert LabelField.CARBOHYDRATES not in parsed.values


def test_an_issue_is_reported_once() -> None:
    text = "\n".join(["Par portion (30 g) Pour 100 g", "Matières grasses 10 g", "Graisses 10 g"])

    parsed = parse_label(text)

    assert parsed.issues.count(LabelIssue(LabelIssueCode.COLUMN_UNCERTAIN, LabelField.FAT)) == 1


def test_a_name_in_two_languages_is_one_row() -> None:
    text = "\n".join(["Pour 100 g", "Sel", "الملح", "Protéines", "البروتين", "1,2 g", "6 g"])

    parsed = parse_label(text)

    assert parsed.values[LabelField.SALT] == Decimal("1.2")
    assert parsed.values[LabelField.PROTEIN] == Decimal(6)


def test_empty_text() -> None:
    assert parse_label("").issues == (LabelIssue(LabelIssueCode.NO_NUTRITION_TABLE),)
    assert not parse_label("   \n\n").ok


def test_warnings_do_not_block() -> None:
    assert not LabelIssue(LabelIssueCode.BASIS_UNKNOWN).blocking
    assert LabelIssue(LabelIssueCode.MISSING, LabelField.SALT).blocking


# ---------------------------------------------------------------- values from another parser

CHECKED = {
    LabelField.ENERGY_KCAL: Decimal(330),
    LabelField.FAT: Decimal(10),
    LabelField.SATURATED_FAT: Decimal(2),
    LabelField.CARBOHYDRATES: Decimal(50),
    LabelField.SUGARS: Decimal(5),
    LabelField.PROTEIN: Decimal(10),
    LabelField.SODIUM: Decimal("0.4"),
}


def test_checked_values_are_derived_like_the_rules_parser() -> None:
    parsed = checked_parse(CHECKED, NutritionBasis.PER_100G)

    assert parsed.ok
    assert parsed.values[LabelField.ENERGY_KJ] == Decimal(1386)
    assert parsed.values[LabelField.SALT] == Decimal("1.0")
    assert parsed.derived == {LabelField.ENERGY_KJ, LabelField.SALT}
    assert parsed.basis == NutritionBasis.PER_100G


def test_checked_values_get_the_same_checks() -> None:
    parsed = checked_parse(CHECKED | {LabelField.SUGARS: Decimal(51)}, NutritionBasis.PER_100G)

    assert not parsed.ok
    assert codes(parsed) == {LabelIssueCode.SUGARS_OVER_CARBOHYDRATES}


def test_checked_values_report_missing_ones_and_an_unknown_basis() -> None:
    parsed = checked_parse({LabelField.FAT: Decimal(1)}, None)

    assert LabelIssue(LabelIssueCode.MISSING, LabelField.SALT) in parsed.issues
    assert LabelIssue(LabelIssueCode.BASIS_UNKNOWN) in parsed.issues


def test_checked_approximate_marks_only_values_given() -> None:
    parsed = checked_parse(
        CHECKED, NutritionBasis.PER_100G, approximate=[LabelField.SODIUM, LabelField.FIBRE]
    )

    assert parsed.approximate == {LabelField.SODIUM, LabelField.SALT}
    assert parsed.ok


# ---------------------------------------------------------------- normalisation


@pytest.mark.parametrize(
    ("raw", "normalized"),
    [
        ("Énergie", "energie"),
        ("1O,5 g", "10,5 g"),
        ("O,9 g", "0,9 g"),
        ("l,2 g", "1,2 g"),
        ("1OOg", "100g"),
        ("lipides oil Il", "lipides oil il"),  # words are left alone
        ("B12 1O", "b12 10"),
        (ARABIC_10_5 + " g", "10,5 g"),  # Arabic-Indic digits, decimal sign
        (EXTENDED_12, "12"),  # Extended Arabic-Indic digits
        ("1 958 kJ", "1958 kj"),
        ("1.958 kcal", "1958 kcal"),
        ("pour 100 g 30 g", "pour 100 g 30 g"),
        ("الألياف", "الالياف"),
        ("الطاقـــة", "الطاقة"),
    ],
)
def test_normalize(raw: str, normalized: str) -> None:
    assert normalize(raw) == normalized


# ---------------------------------------------------------------- API result


def test_api_result_keeps_impossible_values_for_review() -> None:
    result = label_parse_result(parse(salt="100,5 g", energy="330 kcal"))

    assert result.parser_used == "rules"
    assert result.ok is False
    assert result.basis == NutritionBasis.PER_100G
    assert result.values.salt_g == 100.5
    assert result.values.energy_kj == 1386
    assert result.values.sodium_g is None
    assert result.derived == ["energy_kj"]
    assert result.approximate == []
    assert [(i.code, i.field, i.blocking) for i in result.issues] == [
        ("amount_over_100", "salt_g", True),
        ("macros_over_100", None, True),
    ]
    assert result.model_dump(mode="json")["values"]["salt_g"] == 100.5


def test_api_result_warning_does_not_block() -> None:
    result = label_parse_result(parse_label(table(**BASE).split("\n", 1)[1]))

    assert result.ok is True
    assert [(i.code, i.field, i.blocking) for i in result.issues] == [
        ("basis_unknown", None, False)
    ]
