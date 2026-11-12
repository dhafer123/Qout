"""GTIN check digits and EAN normalisation."""

import pytest

from app.modules.products.ean import (
    InvalidEanError,
    check_digit,
    is_valid_gtin,
    normalize_ean,
    upc_a_to_ean13,
)


def fullwidth(digits: str) -> str:
    """The same digits in Unicode full-width form (isdigit() is True for them)."""
    return "".join(chr(0xFF10 + int(d)) for d in digits)


# Real-world style codes with correct check digits.
VALID = [
    "96385074",  # EAN-8
    "40170725",  # EAN-8
    "036000291452",  # UPC-A
    "012345678905",  # UPC-A
    "4006381333931",  # EAN-13
    "5449000000996",  # EAN-13
    "6194001800104",  # EAN-13, Tunisian prefix 619
    "3017620422003",  # EAN-13
    "10012345678902",  # GTIN-14
]


@pytest.mark.parametrize("code", VALID)
def test_valid_codes(code: str) -> None:
    assert is_valid_gtin(code)
    assert check_digit(code[:-1]) == int(code[-1])


@pytest.mark.parametrize("code", VALID)
def test_any_other_check_digit_is_wrong(code: str) -> None:
    for digit in "0123456789":
        if digit != code[-1]:
            assert not is_valid_gtin(code[:-1] + digit)


@pytest.mark.parametrize(
    "code",
    [
        "",
        "1234567",
        "123456789",
        "12345678901",
        "123456789012345",
        "40063813339a1",
        fullwidth("4006381333931"),
    ],
)
def test_invalid_shapes(code: str) -> None:
    assert not is_valid_gtin(code)


def test_check_digit_of_all_zeros() -> None:
    assert check_digit("000000000000") == 0


def test_upc_a_to_ean13() -> None:
    assert upc_a_to_ean13("036000291452") == "0036000291452"
    assert is_valid_gtin("0036000291452")


@pytest.mark.parametrize("code", ["036000291453", "4006381333931", "1234"])
def test_upc_a_to_ean13_rejects_non_upc(code: str) -> None:
    with pytest.raises(InvalidEanError, match="UPC-A"):
        upc_a_to_ean13(code)


@pytest.mark.parametrize(
    ("raw", "stored"),
    [
        ("4006381333931", "4006381333931"),
        (" 4006 3813 3393 1 ", "4006381333931"),
        ("036000291452", "0036000291452"),
        ("96385074", "96385074"),
        ("10012345678902", "10012345678902"),
    ],
)
def test_normalize_ean(raw: str, stored: str) -> None:
    assert normalize_ean(raw) == stored


@pytest.mark.parametrize(
    ("raw", "reason"),
    [
        ("40063813339-1", "only digits"),
        ("", "only digits"),
        (fullwidth("12345678"), "only digits"),
        ("1234567", "8, 12, 13 or 14 digits"),
        ("4006381333932", "check digit"),
    ],
)
def test_normalize_ean_rejects(raw: str, reason: str) -> None:
    with pytest.raises(InvalidEanError, match=reason) as excinfo:
        normalize_ean(raw)
    assert excinfo.value.code == raw
