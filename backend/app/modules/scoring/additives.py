"""Additives of a product, with the EFSA overexposure risk flag.

Data: `data/additives.json`, generated from the Open Food Facts taxonomy in docs/specs/ by
`app.modules.scoring.taxonomy`. Meaning of the flag and decisions: docs/specs/README.md,
"Additives and NOVA".
"""

import json
import re
from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from enum import StrEnum
from functools import cache
from types import MappingProxyType

from app.modules.scoring.taxonomy import DATA_PATH

_OFF_TAG = re.compile(r"en:(e\d+[a-z]*)")


class OverexposureRisk(StrEnum):
    """EFSA's risk that part of the population exceeds the acceptable daily intake."""

    HIGH = "high"
    MODERATE = "moderate"
    NONE = "none"
    UNKNOWN = "unknown"  # not evaluated in the source: not the same as NONE


@dataclass(frozen=True, slots=True)
class Additive:
    """One additive. `in_taxonomy` is False for codes the source does not list."""

    code: str
    name: str | None
    risk: OverexposureRisk
    risk_from: str | None
    """Code whose flag applies: the additive itself, or its parent group (inherited)."""
    efsa_url: str | None
    in_taxonomy: bool


def _key(code: str) -> str:
    """'E160a(i)' and 'en:e160ai' both become 'e160ai'."""
    return re.sub(r"[^a-z0-9]", "", code.lower().removeprefix("en:"))


@cache
def _lookup() -> Mapping[str, Additive]:
    document = json.loads(DATA_PATH.read_text(encoding="utf-8"))
    entries = {
        _key(code): Additive(
            code=code,
            name=entry["name"],
            risk=OverexposureRisk(entry["risk"]),
            risk_from=entry["risk_from"],
            efsa_url=entry["efsa_url"],
            in_taxonomy=True,
        )
        for code, entry in document["additives"].items()
    }
    return MappingProxyType(entries)


def additive(code: str) -> Additive | None:
    """Look up one additive by taxonomy code ('E339(i)') or OFF tag ('en:e339i')."""
    return _lookup().get(_key(code))


def additives_from_off(tags: Iterable[object]) -> tuple[Additive, ...]:
    """The additives named by Open Food Facts `additives_tags`, in order, without duplicates.

    Malformed tags are dropped. A well-formed tag missing from the taxonomy is kept with
    risk UNKNOWN, so the product still shows it.
    """
    found: dict[str, Additive] = {}
    for tag in tags:
        if not isinstance(tag, str):
            continue
        match = _OFF_TAG.fullmatch(tag.strip().lower())
        if match is None:
            continue
        key = _key(match.group(1))
        if key in found:
            continue
        found[key] = additive(key) or Additive(
            code="E" + match.group(1)[1:],
            name=None,
            risk=OverexposureRisk.UNKNOWN,
            risk_from=None,
            efsa_url=None,
            in_taxonomy=False,
        )
    return tuple(found.values())
