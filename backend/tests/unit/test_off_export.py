"""Parsing Open Food Facts bulk files: a small fixture export and the delta index."""

import gzip
import json
import shutil
from pathlib import Path

import pytest

from app.modules.ingestion.off_export import (
    DeltaFile,
    Rejected,
    Selected,
    parse_delta_index,
    parse_line,
    read_lines,
    scan,
)

EXPORT = Path(__file__).resolve().parents[1] / "fixtures" / "off_export" / "export.jsonl"
TUNISIA = frozenset({"en:tunisia"})


def gzipped(tmp_path: Path, source: Path = EXPORT) -> Path:
    target = tmp_path / "export.jsonl.gz"
    with source.open("rb") as raw, gzip.open(target, "wb") as packed:
        shutil.copyfileobj(raw, packed)
    return target


def test_fixture_export_selects_tunisian_products(tmp_path: Path) -> None:
    parsed = list(scan(read_lines(gzipped(tmp_path)), TUNISIA))

    assert [number for number, _ in parsed] == list(range(1, 13))
    selected = [item.ean for _, item in parsed if isinstance(item, Selected)]
    assert selected == [
        "6191585700226",  # ricotta
        "6191509900855",  # olive oil
        "6194039501011",  # water
        "3017620422003",  # Nutella, also sold in France
        "6111018501480",  # Nescafé
    ]
    rejected = {number: item.reason for number, item in parsed if isinstance(item, Rejected)}
    assert rejected.keys() == {4, 9, 10, 11}
    assert rejected[4] == "invalid JSON"
    assert rejected[9].startswith("invalid barcode '12345'")
    assert rejected[10] == "no barcode"
    assert rejected[11] == "not a JSON object"
    # Energy drink (France, Germany), beef patty (Morocco), made in Tunisia but sold in France
    assert [number for number, item in parsed if item is None] == [6, 8, 12]


def test_selected_line_keeps_the_whole_product(tmp_path: Path) -> None:
    first = next(item for _, item in scan(read_lines(gzipped(tmp_path)), TUNISIA))
    assert isinstance(first, Selected)
    assert first.product["code"] == first.ean
    assert first.product["product_name"] == "Ricotta"
    assert "nutriscore" in first.product


def test_several_countries(tmp_path: Path) -> None:
    countries = frozenset({"en:tunisia", "en:morocco"})
    parsed = [item for _, item in scan(read_lines(gzipped(tmp_path)), countries)]
    assert sum(isinstance(item, Selected) for item in parsed) == 6


def test_scan_skips_lines_up_to_the_checkpoint(tmp_path: Path) -> None:
    parsed = list(scan(read_lines(gzipped(tmp_path)), TUNISIA, start_line=5))
    assert parsed[0][0] == 6
    assert [n for n, item in parsed if isinstance(item, Selected)] == [7]


def test_truncated_file_raises_at_the_end(tmp_path: Path) -> None:
    whole = gzipped(tmp_path).read_bytes()
    truncated = tmp_path / "truncated.jsonl.gz"
    truncated.write_bytes(whole[: len(whole) // 2])
    with pytest.raises(EOFError):
        list(read_lines(truncated))


@pytest.mark.parametrize(
    ("product", "expected"),
    [
        ({"code": "3017620422003", "countries_tags": ["en:tunisia"]}, "3017620422003"),
        ({"code": " 3017620422003 ", "countries_tags": ["en:tunisia"]}, "3017620422003"),
        ({"code": "036000291452", "countries_tags": ["en:tunisia"]}, "0036000291452"),  # UPC-A
        ({"code": 3017620422003, "countries_tags": ["en:tunisia"]}, None),
        ({"code": "", "countries_tags": ["en:tunisia"]}, None),
        ({"code": "3017620422004", "countries_tags": ["en:tunisia"]}, None),  # check digit
    ],
)
def test_barcodes(product: dict[str, object], expected: str | None) -> None:
    parsed = parse_line(json.dumps(product), TUNISIA)
    if expected is None:
        assert isinstance(parsed, Rejected)
    else:
        assert parsed == Selected(expected, product)  # type: ignore[arg-type]


@pytest.mark.parametrize(
    "tags",
    [None, "en:tunisia", {"en:tunisia": 1}, [], ["en:france"], [1, None], ["en:tunisiax"]],
)
def test_country_tags_must_list_the_country(tags: object) -> None:
    line = json.dumps({"code": "3017620422003", "countries_tags": tags, "x": "en:tunisia"})
    line = line.replace('"x": "en:tunisia"', '"x": ["en:tunisia"]')  # passes the fast check
    assert parse_line(line, TUNISIA) is None


def test_other_countries_are_not_parsed() -> None:
    assert parse_line("not json at all", TUNISIA) is None


# ---------------------------------------------------------------- delta index


def test_delta_index_is_sorted_oldest_first() -> None:
    text = (
        "openfoodfacts_products_1794378650_1794465153.json.gz\n"
        "openfoodfacts_products_1794292097_1794378650.json.gz\r\n"
        "\n"
        "  openfoodfacts_products_1794205327_1794292097.json.gz  \n"
        "openfoodfacts_products_1794292097_1794378650.json.gz\n"  # listed twice
    )
    assert parse_delta_index(text) == [
        DeltaFile(1794205327, 1794292097, "openfoodfacts_products_1794205327_1794292097.json.gz"),
        DeltaFile(1794292097, 1794378650, "openfoodfacts_products_1794292097_1794378650.json.gz"),
        DeltaFile(1794378650, 1794465153, "openfoodfacts_products_1794378650_1794465153.json.gz"),
    ]


@pytest.mark.parametrize(
    "line",
    [
        "<html>",
        "openfoodfacts_products_1_2.json",
        "../openfoodfacts_products_1_2.json.gz",
        "openfoodfacts_products_a_2.json.gz",
    ],
)
def test_delta_index_skips_unexpected_lines(line: str, caplog: pytest.LogCaptureFixture) -> None:
    assert parse_delta_index(f"{line}\nopenfoodfacts_products_1_2.json.gz") == [
        DeltaFile(1, 2, "openfoodfacts_products_1_2.json.gz")
    ]
    assert "unexpected line in OFF delta index" in caplog.text


def test_empty_delta_index() -> None:
    assert parse_delta_index("") == []
