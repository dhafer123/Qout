"""Bridge between engine results and the golden case format (scoring-spec/README.md)."""

import json
from pathlib import Path
from typing import Any

from app.core.config import REPO_ROOT
from app.modules.scoring import InsufficientData, NutritionInput, ScoreResult

SPEC_DIR = REPO_ROOT / "scoring-spec"
GOLDEN_FILES = sorted((SPEC_DIR / "golden").glob("*.json"))
SCHEMA_PATH = SPEC_DIR / "schema.json"


def load(path: Path) -> dict[str, Any]:
    data: dict[str, Any] = json.loads(path.read_text(encoding="utf-8"))
    return data


def to_input(raw: dict[str, Any]) -> NutritionInput:
    return NutritionInput(**raw)


def to_expected(result: ScoreResult) -> dict[str, Any]:
    """The golden `expected` block for an engine result."""
    if isinstance(result, InsufficientData):
        return {"insufficient_data": list(result.missing)}
    if result.breakdown is None:
        return {"grade": result.grade.value}
    b = result.breakdown
    return {
        "negative": dict(b.negative),
        "positive": dict(b.positive),
        "negative_total": b.negative_total,
        "positive_total": b.positive_total,
        "protein_counted": b.protein_counted,
        "score": b.score,
        "grade": result.grade.value,
    }
