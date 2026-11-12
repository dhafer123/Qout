"""The engine reproduces every golden case (scoring-spec/golden/*.json) exactly."""

from pathlib import Path

import pytest

from app.modules.scoring import ENGINE_VERSION, Category, score
from tests.unit.scoring.golden import GOLDEN_FILES, load, to_expected, to_input


def test_golden_cases_are_found() -> None:
    assert len(GOLDEN_FILES) >= 20


@pytest.mark.parametrize("path", GOLDEN_FILES, ids=lambda p: p.stem)
def test_engine_matches_golden_case(path: Path) -> None:
    case = load(path)
    result = score(Category(case["category"]), to_input(case["input"]))
    assert to_expected(result) == case["expected"]
    assert result.category == case["category"]
    assert result.engine_version == ENGINE_VERSION
