"""Additive lookup from Open Food Facts tags."""

import dataclasses

import pytest

from app.modules.scoring import Additive, OverexposureRisk, additive, additives_from_off


@pytest.mark.parametrize(
    ("code", "expected"),
    [
        ("E951", "E951"),
        ("e951", "E951"),
        ("en:e951", "E951"),
        ("E339(i)", "E339(i)"),
        ("en:e339i", "E339(i)"),
        ("en:e160ai", "E160a(i)"),
        ("E 160 a (i)", "E160a(i)"),
    ],
)
def test_lookup_accepts_codes_and_tags(code: str, expected: str) -> None:
    found = additive(code)
    assert found is not None
    assert found.code == expected


def test_lookup_of_an_unknown_code() -> None:
    assert additive("E9999") is None


def test_each_risk_level() -> None:
    tags = ["en:e951", "en:e339", "en:e339i", "en:e330"]
    risks = {a.code: (a.risk, a.risk_from) for a in additives_from_off(tags)}
    assert risks == {
        "E951": (OverexposureRisk.NONE, "E951"),
        "E339": (OverexposureRisk.HIGH, "E339"),
        "E339(i)": (OverexposureRisk.HIGH, "E339"),
        "E330": (OverexposureRisk.UNKNOWN, None),
    }
    moderate = [a for a in _all_flagged() if a.risk is OverexposureRisk.MODERATE]
    assert moderate
    assert all(a.efsa_url for a in moderate)


def _all_flagged() -> list[Additive]:
    codes = [f"en:e{n}" for n in range(100, 1600)]
    return [a for a in additives_from_off(codes) if a.in_taxonomy and a.risk_from]


def test_known_additive_details() -> None:
    (aspartame,) = additives_from_off(["en:e951"])
    assert aspartame == Additive(
        code="E951",
        name="Aspartame",
        risk=OverexposureRisk.NONE,
        risk_from="E951",
        efsa_url="http://dx.doi.org/10.2903/j.efsa.2013.3496",
        in_taxonomy=True,
    )


def test_tag_missing_from_the_taxonomy_is_kept_as_unknown() -> None:
    (unknown,) = additives_from_off(["en:e9999ab"])
    assert unknown == Additive(
        code="E9999ab",
        name=None,
        risk=OverexposureRisk.UNKNOWN,
        risk_from=None,
        efsa_url=None,
        in_taxonomy=False,
    )


def test_order_is_kept_and_duplicates_dropped() -> None:
    tags = ["en:e330", "en:e951", "EN:E330", " en:e951 ", "en:e339"]
    assert [a.code for a in additives_from_off(tags)] == ["E330", "E951", "E339"]


@pytest.mark.parametrize(
    "bad",
    ["", "e330", "fr:e330", "en:", "en:330", "en:citric-acid", "en:e330-", None, 330, ["en:e330"]],
)
def test_malformed_tags_are_dropped(bad: object) -> None:
    assert additives_from_off([bad]) == ()


def test_empty_input() -> None:
    assert additives_from_off([]) == ()


def test_additives_are_immutable() -> None:
    (citric,) = additives_from_off(["en:e330"])
    with pytest.raises(dataclasses.FrozenInstanceError):
        citric.risk = OverexposureRisk.HIGH  # type: ignore[misc]


def test_unknown_is_not_none() -> None:
    assert OverexposureRisk.UNKNOWN is not OverexposureRisk.NONE
    assert {r.value for r in OverexposureRisk} == {"high", "moderate", "none", "unknown"}
