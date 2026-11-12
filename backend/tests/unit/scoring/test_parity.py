"""Parity inputs, the Python runner and the results comparison."""

import json
from collections import Counter
from pathlib import Path
from typing import Any

import pytest

from app.modules.scoring import Category, NutritionInput
from app.modules.scoring import parity as p
from app.modules.scoring.spec_json import nutrition_input_from_spec
from tests.unit.scoring.golden import GOLDEN_FILES, load


@pytest.fixture(scope="module")
def cases() -> list[dict[str, Any]]:
    return p.generate()


def test_committed_inputs_match_the_generator(cases: list[dict[str, Any]]) -> None:
    """Fails when the generator or a golden case changed without regenerating."""
    assert p.INPUTS_PATH.read_text(encoding="utf-8") == p.render_inputs(cases), (
        "run: uv run python -m app.modules.scoring.parity generate"
    )


def test_generation_is_deterministic(cases: list[dict[str, Any]]) -> None:
    assert p.generate() == cases
    assert p.generate(seed=1) != cases


def test_ids_are_unique(cases: list[dict[str, Any]]) -> None:
    duplicates = [i for i, n in Counter(c["id"] for c in cases).items() if n > 1]
    assert duplicates == []


def test_every_golden_case_is_included(cases: list[dict[str, Any]]) -> None:
    ids = {c["id"] for c in cases}
    assert {f"golden--{path.stem}" for path in GOLDEN_FILES} <= ids


def test_every_category_and_kind_is_covered(cases: list[dict[str, Any]]) -> None:
    kinds = Counter(
        (c["category"], c["id"].split("-")[-2]) for c in cases if not c["id"].startswith("golden")
    )
    for category in Category:
        if category is Category.WATER:
            continue
        assert kinds[(category.value, "random")] == p.RANDOM_CASES_PER_CATEGORY
        assert kinds[(category.value, "boundary")] > 0
    assert kinds[("fats_oils_nuts_seeds", "ratio")] > 0


def test_inputs_are_valid_and_include_missing_data(cases: list[dict[str, Any]]) -> None:
    results = p.run(cases)
    insufficient = [i for i, r in results.items() if "insufficient_data" in r]
    assert 50 < len(insufficient) < len(cases) // 10
    zero_fat = [c for c in cases if c["input"].get("total_fat_g") == 0]
    assert zero_fat


def test_boundary_values_sit_on_thresholds(cases: list[dict[str, Any]]) -> None:
    salts = {c["input"]["salt_g"] for c in cases if "-boundary-" in c["id"]}
    assert {3.2, 3.199, 3.201} <= salts
    ratios = [
        (c["input"]["saturated_fat_g"], c["input"]["total_fat_g"])
        for c in cases
        if "-ratio-" in c["id"]
    ]
    assert (6.0, 37.5) in ratios  # 16 % exactly


def test_values_respect_input_limits(cases: list[dict[str, Any]]) -> None:
    for case in cases:
        nutrition_input_from_spec(case["input"])  # raises on impossible values


def test_run_reproduces_the_golden_cases(cases: list[dict[str, Any]]) -> None:
    results = p.run(cases)
    for path in GOLDEN_FILES:
        assert results[f"golden--{path.stem}"] == load(path)["expected"], path.stem


# ---------------------------------------------------------------- compare


def results(engine: str, **entries: Any) -> dict[str, Any]:
    return {"engine": engine, "results": entries}


def test_compare_identical() -> None:
    a = results("python", x={"grade": "A"})
    assert p.compare(a, results("dart", x={"grade": "A"})) == []


def test_compare_reports_differences_and_missing_ids() -> None:
    problems = p.compare(
        results("python", x={"grade": "A"}, y={"grade": "B"}),
        results("dart", x={"grade": "C"}, z={"grade": "B"}),
    )
    assert problems == [
        "only in python: y",
        "only in dart: z",
        "x (python vs dart): {'grade': 'A'} != {'grade': 'C'}",
    ]


def test_compare_limits_the_report() -> None:
    a = results("python", **{f"c{n}": {"score": n} for n in range(30)})
    b = results("dart", **{f"c{n}": {"score": -n - 1} for n in range(30)})
    problems = p.compare(a, b, limit=5)
    assert len(problems) == 6
    assert problems[-1] == "... and 25 more"


# ---------------------------------------------------------------- command line


def test_cli_generate_run_compare(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    inputs = tmp_path / "inputs.json"
    assert p.main(["generate", "--output", str(inputs)]) == 0
    first, second = tmp_path / "a.json", tmp_path / "b.json"
    assert p.main(["run", str(first), "--inputs", str(inputs)]) == 0
    assert p.main(["run", str(second), "--inputs", str(inputs)]) == 0
    assert p.main(["compare", str(first), str(second)]) == 0
    assert "identical: " in capsys.readouterr().out

    document = json.loads(second.read_text(encoding="utf-8"))
    document["engine"] = "dart"
    document["results"]["water-000"] = {"grade": "B"}
    second.write_text(json.dumps(document), encoding="utf-8")
    assert p.main(["compare", str(first), str(second)]) == 1
    assert "water-000 (python vs dart)" in capsys.readouterr().out


def test_results_file_format() -> None:
    rendered = p.render_results("python", {"b": {"grade": "A"}, "a": {"grade": "B"}})
    assert json.loads(rendered) == {
        "engine": "python",
        "results": {"a": {"grade": "B"}, "b": {"grade": "A"}},
    }


def test_spec_input_rejects_unknown_fields() -> None:
    with pytest.raises(ValueError, match="unknown input fields: sodium_g"):
        nutrition_input_from_spec({"sodium_g": 1})
    assert nutrition_input_from_spec({"salt_g": 1}) == NutritionInput(salt_g=1)
