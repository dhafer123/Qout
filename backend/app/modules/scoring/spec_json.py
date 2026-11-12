"""Conversions between the engine and the golden case format (scoring-spec/README.md).

Inputs and `expected` blocks keyed by spec names. Used by the golden tests and the parity
runner; the Dart engine has the same functions (app/lib/scoring/spec_json.dart).
"""

from collections.abc import Mapping
from dataclasses import fields
from typing import Any

from app.modules.scoring.models import InsufficientData, NutritionInput, ScoreResult

_INPUT_FIELDS = frozenset(f.name for f in fields(NutritionInput))


def nutrition_input_from_spec(raw: Mapping[str, Any]) -> NutritionInput:
    """A golden case `input` object; unknown keys are an error, not ignored."""
    unknown = sorted(set(raw) - _INPUT_FIELDS)
    if unknown:
        msg = f"unknown input fields: {', '.join(unknown)}"
        raise ValueError(msg)
    return NutritionInput(**raw)


def expected_to_spec(result: ScoreResult) -> dict[str, Any]:
    """The golden `expected` block for an engine result."""
    if isinstance(result, InsufficientData):
        return {"insufficient_data": list(result.missing)}
    if result.breakdown is None:
        return {"grade": result.grade.value}
    b = result.breakdown
    expected: dict[str, Any] = {
        "negative": dict(b.negative),
        "positive": dict(b.positive),
        "negative_total": b.negative_total,
        "positive_total": b.positive_total,
        "protein_counted": b.protein_counted,
        "score": b.score,
        "grade": result.grade.value,
    }
    if b.assumed_zero:
        expected["assumed_zero"] = list(b.assumed_zero)
    return expected
