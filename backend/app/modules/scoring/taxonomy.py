"""Build the additives lookup (`data/additives.json`) from the Open Food Facts taxonomy.

Source and decisions: docs/specs/README.md, "Additives and NOVA". Run after updating the
taxonomy file:

    uv run python -m app.modules.scoring.taxonomy

The backend never reads the taxonomy at runtime (the Docker image has no `docs/`).
"""

import json
import re
import sys
from itertools import takewhile
from pathlib import Path
from typing import Any, TypedDict

from app.core.config import REPO_ROOT

TAXONOMY_PATH = REPO_ROOT / "docs" / "specs" / "off-additives-taxonomy-7fbee09.txt"
DATA_PATH = Path(__file__).parent / "data" / "additives.json"

_CODE = re.compile(r"E\d+[a-z]?(\([ivx]+\))?")
_RISKS = {"en:high": "high", "en:moderate": "moderate", "en:no": "none"}
_RISK_KEY = "efsa_evaluation_overexposure_risk:en:"
_URL_KEY = "efsa_evaluation_url:en:"


class AdditiveEntry(TypedDict):
    name: str | None
    risk: str
    risk_from: str | None
    efsa_url: str | None


class _Raw(TypedDict):
    name: str | None
    parent: str | None
    risk: str | None
    efsa_url: str | None


def parse_taxonomy(text: str) -> dict[str, AdditiveEntry]:
    """E-numbered additives with their English name and (possibly inherited) risk flag."""
    raw: dict[str, _Raw] = {}
    for block in re.split(r"\n[ \t]*\n", text):
        entry = _parse_block(block)
        if entry is not None:
            code, fields = entry
            raw[code] = fields
    return {code: _resolve(code, raw) for code in sorted(raw, key=_sort_key)}


def _parse_block(block: str) -> tuple[str, _Raw] | None:
    lines = [line.strip() for line in block.splitlines()]
    lines = [line for line in lines if line and not line.startswith("#")]
    english = next((line for line in lines if line.startswith("en:")), None)
    if english is None:
        return None
    synonyms = [s.strip() for s in english.removeprefix("en:").split(",")]
    code = synonyms[0]
    if not _CODE.fullmatch(code):
        return None  # decision 2: generic entries ("Exxx", "E14XX") and non-E entries
    parent = next(
        (
            p
            for line in lines
            if line.startswith("<")
            and _CODE.fullmatch(p := line[1:].strip().removeprefix("en:").strip())
        ),
        None,
    )
    risk_value = _value(lines, _RISK_KEY)
    if risk_value is not None and risk_value not in _RISKS:
        msg = f"{code}: unexpected overexposure risk {risk_value!r}"
        raise ValueError(msg)
    return code, {
        "name": next((s for s in synonyms[1:] if s), None),
        "parent": parent,
        "risk": _RISKS[risk_value] if risk_value else None,
        "efsa_url": _value(lines, _URL_KEY),
    }


def _value(lines: list[str], key: str) -> str | None:
    return next((line.removeprefix(key).strip() for line in lines if line.startswith(key)), None)


def _resolve(code: str, raw: dict[str, _Raw]) -> AdditiveEntry:
    """Own flag, else the nearest ancestor's (decision 1), else unknown."""
    own = raw[code]
    current: str | None = code
    seen: set[str] = set()
    while current is not None and current in raw and current not in seen:
        seen.add(current)
        fields = raw[current]
        if fields["risk"] is not None:
            return {
                "name": own["name"],
                "risk": fields["risk"],
                "risk_from": current,
                "efsa_url": fields["efsa_url"],
            }
        current = fields["parent"]
    return {"name": own["name"], "risk": "unknown", "risk_from": None, "efsa_url": None}


def _sort_key(code: str) -> tuple[int, str]:
    """E100, E100(i), E101, ..., E1105: numeric order first."""
    return int("".join(takewhile(str.isdigit, code[1:]))), code


def render(entries: dict[str, AdditiveEntry], source: str) -> str:
    document: dict[str, Any] = {"source": source, "additives": entries}
    return json.dumps(document, ensure_ascii=False, indent=1) + "\n"


def build(taxonomy: Path = TAXONOMY_PATH, output: Path = DATA_PATH) -> int:
    """Regenerate the lookup file; returns the number of additives written."""
    entries = parse_taxonomy(taxonomy.read_text(encoding="utf-8"))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(render(entries, taxonomy.name), encoding="utf-8", newline="\n")
    return len(entries)


if __name__ == "__main__":  # pragma: no cover
    count = build()
    sys.stdout.write(f"wrote {count} additives to {DATA_PATH}\n")
