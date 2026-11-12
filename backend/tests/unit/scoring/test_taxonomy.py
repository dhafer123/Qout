"""Parsing the Open Food Facts additives taxonomy into the committed lookup file."""

import json
from pathlib import Path

import pytest

from app.modules.scoring.taxonomy import (
    DATA_PATH,
    TAXONOMY_PATH,
    build,
    parse_taxonomy,
    render,
)

SAMPLE = """\
# comment at the top
stopwords:en: of, for

synonyms:en: colour, color

en: E339, Sodium phosphates
fr: E339, Phosphates de sodium
efsa_evaluation_overexposure_risk:en: en:high
efsa_evaluation_url:en: https://example.org/e339

< en:E339
en: E339(i), Monosodium phosphate
# de: E339(i), commented out

en: E400, Alginic acid
efsa_evaluation_overexposure_risk:en: en:no

< en:E400
en: E400a, Made-up child

<en: E400a
en: E400a(i), Made-up grandchild

< en:E339
en: E339(ii)
efsa_evaluation_overexposure_risk:en: en:no
efsa_evaluation_url:en: https://example.org/e339ii

en: E951, Aspartame, APM
efsa_evaluation_overexposure_risk:en: en:moderate

en: E330, , Citric acid

en: E100, Curcumin
< en:maltitol

en: Exxx, Exxx food additive
efsa_evaluation_overexposure_risk:en: en:high

en: E14XX, Modified Starch

fr: E999, sans anglais

< en:E1001
en: E1000, Cholic acid

< en:E1000
en: E1001, Choline salts
"""


@pytest.fixture(scope="module")
def parsed() -> dict[str, dict[str, object]]:
    return dict(parse_taxonomy(SAMPLE))  # type: ignore[arg-type]


def test_keeps_only_e_numbered_english_entries(parsed: dict[str, object]) -> None:
    assert list(parsed) == [
        "E100",
        "E330",
        "E339",
        "E339(i)",
        "E339(ii)",
        "E400",
        "E400a",
        "E400a(i)",
        "E951",
        "E1000",
        "E1001",
    ]


def test_own_flag(parsed: dict[str, dict[str, object]]) -> None:
    assert parsed["E339"] == {
        "name": "Sodium phosphates",
        "risk": "high",
        "risk_from": "E339",
        "efsa_url": "https://example.org/e339",
    }
    assert parsed["E951"]["risk"] == "moderate"
    assert parsed["E951"]["efsa_url"] is None


def test_child_inherits_the_parent_flag(parsed: dict[str, dict[str, object]]) -> None:
    assert parsed["E339(i)"] == {
        "name": "Monosodium phosphate",
        "risk": "high",
        "risk_from": "E339",
        "efsa_url": "https://example.org/e339",
    }


def test_inheritance_walks_up_several_levels(parsed: dict[str, dict[str, object]]) -> None:
    assert parsed["E400a(i)"]["risk_from"] == "E400"
    assert parsed["E400a(i)"]["risk"] == "none"


def test_own_flag_wins_over_the_parent(parsed: dict[str, dict[str, object]]) -> None:
    assert parsed["E339(ii)"]["risk"] == "none"
    assert parsed["E339(ii)"]["risk_from"] == "E339(ii)"
    assert parsed["E339(ii)"]["name"] is None


def test_no_flag_anywhere_is_unknown(parsed: dict[str, dict[str, object]]) -> None:
    assert parsed["E100"] == {
        "name": "Curcumin",
        "risk": "unknown",
        "risk_from": None,
        "efsa_url": None,
    }


def test_blank_synonym_is_skipped_for_the_name(parsed: dict[str, dict[str, object]]) -> None:
    assert parsed["E330"]["name"] == "Citric acid"


def test_parent_cycle_ends_as_unknown(parsed: dict[str, dict[str, object]]) -> None:
    assert parsed["E1000"]["risk"] == "unknown"
    assert parsed["E1001"]["risk"] == "unknown"


def test_unexpected_risk_value_is_an_error() -> None:
    with pytest.raises(ValueError, match="E1: unexpected overexposure risk 'en:maybe'"):
        parse_taxonomy("en: E1, Thing\nefsa_evaluation_overexposure_risk:en: en:maybe\n")


def test_build_writes_the_lookup_file(tmp_path: Path) -> None:
    source = tmp_path / "taxonomy.txt"
    source.write_text(SAMPLE, encoding="utf-8")
    output = tmp_path / "out" / "additives.json"
    assert build(source, output) == 11
    document = json.loads(output.read_text(encoding="utf-8"))
    assert document["source"] == "taxonomy.txt"
    assert document["additives"]["E339(i)"]["risk"] == "high"


# ---------------------------------------------------------------- the real files


@pytest.fixture(scope="module")
def real() -> dict[str, dict[str, object]]:
    return dict(parse_taxonomy(TAXONOMY_PATH.read_text(encoding="utf-8")))  # type: ignore[arg-type]


def test_committed_lookup_matches_the_taxonomy() -> None:
    """Fails when docs/specs/ changed without regenerating data/additives.json."""
    entries = parse_taxonomy(TAXONOMY_PATH.read_text(encoding="utf-8"))
    expected = render(entries, TAXONOMY_PATH.name)
    assert DATA_PATH.read_text(encoding="utf-8") == expected, (
        "run: uv run python -m app.modules.scoring.taxonomy"
    )


def test_real_taxonomy_counts(real: dict[str, dict[str, object]]) -> None:
    """Figures quoted in docs/specs/README.md."""
    own = [code for code, entry in real.items() if entry["risk_from"] == code]
    inherited = [c for c, e in real.items() if e["risk_from"] not in (None, c)]
    unknown = [code for code, entry in real.items() if entry["risk"] == "unknown"]
    assert (len(real), len(own), len(inherited), len(unknown)) == (726, 65, 37, 624)


@pytest.mark.parametrize(
    ("code", "name", "risk", "risk_from"),
    [
        ("E951", "Aspartame", "none", "E951"),
        ("E339", "Sodium phosphates", "high", "E339"),
        ("E339(i)", "Monosodium phosphate", "high", "E339"),
        ("E330", "Citric acid", "unknown", None),
        ("E100", "Curcumin", "unknown", None),
    ],
)
def test_real_taxonomy_examples(
    real: dict[str, dict[str, object]], code: str, name: str, risk: str, risk_from: str | None
) -> None:
    assert (real[code]["name"], real[code]["risk"], real[code]["risk_from"]) == (
        name,
        risk,
        risk_from,
    )
