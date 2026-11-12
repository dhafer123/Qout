"""Open Food Facts bulk files: the full JSONL export and the daily delta files.

Both are gzip-compressed JSON Lines, one product per line, in the same shape as the API's
`product` object, so the normaliser handles them unchanged. The CSV export is not used:
it lacks the Nutri-Score 2023 classification the normaliser relies on.

- Full export: `openfoodfacts-products.jsonl.gz` (all products, rebuilt daily, ~14 GB).
- Delta files: `delta/index.txt` lists `openfoodfacts_products_<start>_<end>.json.gz`, the
  products changed in that time window (Unix seconds), kept for about two weeks.

Parsing only (no network); reading a local file is blocking, so callers run it in a thread.
"""

import gzip
import json
import logging
import re
from collections.abc import Iterable, Iterator
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from app.modules.products.ean import InvalidEanError, normalize_ean

logger = logging.getLogger(__name__)

_DELTA_NAME = re.compile(r"^openfoodfacts_products_(\d+)_(\d+)\.json\.gz$")


@dataclass(frozen=True)
class Selected:
    """A product sold in one of the imported countries, with a valid barcode."""

    ean: str
    product: dict[str, Any]


@dataclass(frozen=True)
class Rejected:
    """A line for an imported country that cannot be used."""

    reason: str


type ParsedLine = Selected | Rejected | None
"""None: the product is not sold in any imported country (not our business)."""


def parse_line(line: str, countries: frozenset[str]) -> ParsedLine:
    """One export line. `countries` are OFF country tags such as `en:tunisia`."""
    # Fast path: most of the export is other countries; skip those without parsing JSON.
    # Tags are plain ASCII, so a selected product always contains one of them quoted.
    if not any(f'"{tag}"' in line for tag in countries):
        return None
    try:
        product = json.loads(line)
    except ValueError:
        return Rejected("invalid JSON")
    if not isinstance(product, dict):
        return Rejected("not a JSON object")
    tags = product.get("countries_tags")
    if not isinstance(tags, list) or countries.isdisjoint(t for t in tags if isinstance(t, str)):
        return None
    ean = _ean(product.get("code"))
    return Selected(ean, product) if isinstance(ean, str) else ean


def _ean(code: object) -> str | Rejected:
    if not isinstance(code, str) or not code.strip():
        return Rejected("no barcode")
    try:
        return normalize_ean(code.strip())
    except InvalidEanError as error:
        return Rejected(f"invalid barcode {code!r}: {error}")


def scan(
    lines: Iterable[str], countries: frozenset[str], *, start_line: int = 0
) -> Iterator[tuple[int, ParsedLine]]:
    """(line number from 1, parsed line) for every line after `start_line`."""
    for number, line in enumerate(lines, start=1):
        if number > start_line:
            yield number, parse_line(line, countries)


def read_lines(path: Path) -> Iterator[str]:
    """Lines of a gzip JSONL file. A truncated file raises EOFError at the end."""
    with gzip.open(path, "rt", encoding="utf-8", errors="replace") as file:
        yield from file


# ---------------------------------------------------------------- delta files


@dataclass(frozen=True, order=True)
class DeltaFile:
    """One delta file: products changed between `start` and `end` (Unix seconds)."""

    start: int
    end: int
    name: str


def parse_delta_index(text: str) -> list[DeltaFile]:
    """Delta files listed in `index.txt`, oldest first. Unknown lines are skipped."""
    files: set[DeltaFile] = set()
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        match = _DELTA_NAME.match(line)
        if match is None:
            logger.warning("unexpected line in OFF delta index", extra={"line": line[:200]})
            continue
        files.add(DeltaFile(int(match[1]), int(match[2]), line))
    return sorted(files)
