"""Daily needs cases (`scoring-spec/needs/`) are well-formed.

Checks the files themselves: they validate against `scoring-spec/needs/schema.json` and are
named after their id. The app computes the needs on the phone (the profile never leaves it),
so the results are checked by the Dart test `app/test/health/needs_spec_test.dart`.
"""

import json
from pathlib import Path
from typing import Any

import pytest
from jsonschema import Draft202012Validator

from app.core.config import REPO_ROOT

NEEDS_DIR = REPO_ROOT / "scoring-spec" / "needs"
CASE_FILES = sorted((NEEDS_DIR / "cases").glob("*.json"))
TABLE_PATH = NEEDS_DIR / "efsa-table-12.json"


def load(path: Path) -> dict[str, Any]:
    data: dict[str, Any] = json.loads(path.read_text(encoding="utf-8"))
    return data


@pytest.fixture(scope="module")
def schema() -> dict[str, Any]:
    schema = load(NEEDS_DIR / "schema.json")
    Draft202012Validator.check_schema(schema)
    return schema


def test_cases_are_found() -> None:
    assert len(CASE_FILES) >= 20


@pytest.mark.parametrize("path", CASE_FILES, ids=lambda path: path.stem)
def test_case_is_valid_and_named_after_its_id(path: Path, schema: dict[str, Any]) -> None:
    case = load(path)
    Draft202012Validator(schema).validate(case)
    assert case["id"] == path.stem


def test_every_kind_of_case_is_present() -> None:
    kinds = {path.stem.split("--")[0] for path in CASE_FILES}
    assert kinds == {"personal", "reference", "bmi"}


def test_efsa_table_is_valid_and_complete(schema: dict[str, Any]) -> None:
    table = load(TABLE_PATH)
    Draft202012Validator(schema["$defs"]["efsa_table"] | {"$defs": schema["$defs"]}).validate(table)
    keys = {(row["input"]["sex"], row["age_band"], row["input"]["pal"]) for row in table["cases"]}
    assert len(keys) == 48  # 2 sexes x 6 age bands x 4 activity levels, no duplicate


def test_schema_rejects_a_wrong_reference_amount(schema: dict[str, Any]) -> None:
    case = load(NEEDS_DIR / "cases" / "reference--no-profile.json")
    case["expected"]["salt_g"] = 5  # the reference intake is 6 g
    assert not Draft202012Validator(schema).is_valid(case)
