"""Golden case files (scoring-spec/golden/) for the tests."""

import json
from pathlib import Path
from typing import Any

from app.core.config import REPO_ROOT
from app.modules.scoring.spec_json import expected_to_spec, nutrition_input_from_spec

SPEC_DIR = REPO_ROOT / "scoring-spec"
GOLDEN_FILES = sorted((SPEC_DIR / "golden").glob("*.json"))
SCHEMA_PATH = SPEC_DIR / "schema.json"

to_input = nutrition_input_from_spec
to_expected = expected_to_spec


def load(path: Path) -> dict[str, Any]:
    data: dict[str, Any] = json.loads(path.read_text(encoding="utf-8"))
    return data
