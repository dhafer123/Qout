"""Golden scoring cases (`scoring-spec/golden/*.json`) are well-formed.

Checks the files themselves, not a scoring engine: they validate against
`scoring-spec/schema.json`, are named after their id, cover every category, and their
point totals add up.
"""

import copy
import json
from collections import Counter
from pathlib import Path
from typing import Any

import pytest
from jsonschema import Draft202012Validator

from app.core.config import REPO_ROOT

SPEC_DIR = REPO_ROOT / "scoring-spec"
SCHEMA_PATH = SPEC_DIR / "schema.json"
GOLDEN_DIR = SPEC_DIR / "golden"
GOLDEN_FILES = sorted(GOLDEN_DIR.glob("*.json"))
CATEGORIES = {"general", "red_meat", "cheese", "fats_oils_nuts_seeds", "beverage", "water"}
MIN_CASES = 20

Case = dict[str, Any]


def load(path: Path) -> Case:
    data: Case = json.loads(path.read_text(encoding="utf-8"))
    return data


SCORED_FILES = [p for p in GOLDEN_FILES if "score" in load(p)["expected"]]
INSUFFICIENT_FILES = [p for p in GOLDEN_FILES if "insufficient_data" in load(p)["expected"]]


@pytest.fixture(scope="module")
def validator() -> Draft202012Validator:
    schema = load(SCHEMA_PATH)
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema)


@pytest.fixture(scope="module")
def cases() -> list[Case]:
    return [load(path) for path in GOLDEN_FILES]


def is_scored(case: Case) -> bool:
    return "score" in case["expected"]


def test_there_are_enough_cases() -> None:
    assert len(GOLDEN_FILES) >= MIN_CASES


def test_every_category_has_a_graded_case(cases: list[Case]) -> None:
    graded = {case["category"] for case in cases if "grade" in case["expected"]}
    assert graded == CATEGORIES


def test_every_graded_category_has_an_insufficient_data_case(cases: list[Case]) -> None:
    covered = {case["category"] for case in cases if "insufficient_data" in case["expected"]}
    assert {"general", "fats_oils_nuts_seeds", "beverage"} <= covered


def test_ids_are_unique(cases: list[Case]) -> None:
    duplicates = [i for i, n in Counter(c["id"] for c in cases).items() if n > 1]
    assert duplicates == []


@pytest.mark.parametrize("path", GOLDEN_FILES, ids=lambda p: p.stem)
def test_case_matches_schema(path: Path, validator: Draft202012Validator) -> None:
    errors = [
        f"{'/'.join(map(str, e.absolute_path)) or '<root>'}: {e.message}"
        for e in validator.iter_errors(load(path))
    ]
    assert errors == []


@pytest.mark.parametrize("path", GOLDEN_FILES, ids=lambda p: p.stem)
def test_file_is_named_after_its_id_and_category(path: Path) -> None:
    case = load(path)
    assert case["id"] == path.stem
    assert case["id"].split("--", 1)[0] == case["category"]


@pytest.mark.parametrize("path", SCORED_FILES, ids=lambda p: p.stem)
def test_points_add_up(path: Path) -> None:
    expected = load(path)["expected"]
    negative, positive = expected["negative"], expected["positive"]

    assert expected["negative_total"] == sum(negative.values())
    assert expected["positive_total"] == sum(positive.values())
    if expected["protein_counted"]:
        assert expected["score"] == expected["negative_total"] - expected["positive_total"]
    else:
        assert expected["score"] == (
            expected["negative_total"] - positive["fibre"] - positive["fvl"]
        )


@pytest.mark.parametrize("path", INSUFFICIENT_FILES, ids=lambda p: p.stem)
def test_insufficient_data_lists_absent_or_unusable_inputs(path: Path) -> None:
    case = load(path)
    missing = case["expected"]["insufficient_data"]

    assert missing == sorted(missing)
    for field in missing:
        unusable_fat = field == "total_fat_g" and case["input"].get(field) == 0
        assert field not in case["input"] or unusable_fat, field


# ----------------------------------------------------------------- the schema rejects


def broken(base: Case, path: list[str], value: object) -> Case:
    case = copy.deepcopy(base)
    target = case
    for key in path[:-1]:
        target = target[key]
    target[path[-1]] = value
    return case


@pytest.fixture(scope="module")
def red_meat(cases: list[Case]) -> Case:
    return next(c for c in cases if c["category"] == "red_meat" and is_scored(c))


@pytest.fixture(scope="module")
def beverage(cases: list[Case]) -> Case:
    return next(c for c in cases if c["category"] == "beverage" and is_scored(c))


@pytest.mark.parametrize(
    ("label", "path", "value"),
    [
        ("unknown category", ["category"], "snacks"),
        ("unknown input", ["input", "sodium_mg"], 100),
        ("negative amount", ["input", "sugars_g"], -1),
        ("fvl over 100 %", ["input", "fvl_percent"], 101),
        ("red meat protein above cap", ["expected", "positive", "protein"], 3),
        ("grade outside A-E", ["expected", "grade"], "F"),
        ("fats-only input on red meat", ["input", "total_fat_g"], 10),
    ],
)
def test_schema_rejects_invalid_red_meat_case(
    validator: Draft202012Validator, red_meat: Case, label: str, path: list[str], value: object
) -> None:
    assert not validator.is_valid(broken(red_meat, path, value)), label


@pytest.mark.parametrize(
    ("label", "path", "value"),
    [
        ("beverage graded A", ["expected", "grade"], "A"),
        ("sweeteners not 0 or 4", ["expected", "negative", "non_nutritive_sweeteners"], 2),
        ("beverage FVL points not in 0/2/4/6", ["expected", "positive", "fvl"], 5),
        ("beverage without protein counted", ["expected", "protein_counted"], False),
    ],
)
def test_schema_rejects_invalid_beverage_case(
    validator: Draft202012Validator, beverage: Case, label: str, path: list[str], value: object
) -> None:
    assert not validator.is_valid(broken(beverage, path, value)), label


def test_schema_rejects_water_with_inputs(validator: Draft202012Validator) -> None:
    water = {
        "id": "water--x",
        "description": "d",
        "source": "s",
        "category": "water",
        "input": {"energy_kj": 0},
        "expected": {"grade": "A"},
    }
    assert not validator.is_valid(water)
    assert validator.is_valid({**water, "input": {}})


def test_schema_rejects_scored_case_with_missing_required_input(
    validator: Draft202012Validator, red_meat: Case
) -> None:
    case = copy.deepcopy(red_meat)
    del case["input"]["protein_g"]
    assert not validator.is_valid(case)


def test_schema_ties_undeclared_fibre_to_assumed_zero(
    validator: Draft202012Validator, red_meat: Case
) -> None:
    """Decision 8: fibre absent from a scored input <=> `assumed_zero: ["fibre_g"]`."""
    without_fibre = copy.deepcopy(red_meat)
    del without_fibre["input"]["fibre_g"]
    assert not validator.is_valid(without_fibre)  # assumption not reported

    without_fibre["expected"]["assumed_zero"] = ["fibre_g"]
    assert validator.is_valid(without_fibre)

    declared_but_assumed = broken(red_meat, ["expected", "assumed_zero"], ["fibre_g"])
    assert not validator.is_valid(declared_but_assumed)

    for wrong in ([], ["protein_g"], ["fibre_g", "fibre_g"]):
        assert not validator.is_valid(broken(without_fibre, ["expected", "assumed_zero"], wrong))
