"""Barcode helpers: GTIN check digits, UPC-A -> EAN-13.

Accepted: EAN-8, UPC-A (12 digits, stored as EAN-13 with a leading 0), EAN-13 and
GTIN-14. UPC-E (compressed UPC-A) is expanded by the app scanner (T19), not here.
"""

_LENGTHS = frozenset({8, 12, 13, 14})


class InvalidEanError(ValueError):
    def __init__(self, code: str, reason: str) -> None:
        super().__init__(f"invalid barcode {code!r}: {reason}")
        self.code = code
        self.reason = reason


def check_digit(body: str) -> int:
    """GTIN check digit for `body` (all digits but the last): weights 3, 1, 3... from the right."""
    total = sum(int(d) * (3 if i % 2 == 0 else 1) for i, d in enumerate(reversed(body)))
    return (10 - total % 10) % 10


def is_valid_gtin(code: str) -> bool:
    """True for an 8-, 12-, 13- or 14-digit code with a correct check digit."""
    return (
        code.isascii()
        and code.isdigit()
        and len(code) in _LENGTHS
        and check_digit(code[:-1]) == int(code[-1])
    )


def upc_a_to_ean13(code: str) -> str:
    """A UPC-A code is the EAN-13 with a leading zero (same check digit)."""
    if len(code) != 12 or not is_valid_gtin(code):
        raise InvalidEanError(code, "not a valid UPC-A code")
    return f"0{code}"


def normalize_ean(code: str) -> str:
    """The form we store: whitespace removed, check digit verified, UPC-A as EAN-13."""
    cleaned = "".join(code.split())
    if not (cleaned.isascii() and cleaned.isdigit()):
        raise InvalidEanError(code, "only digits allowed")
    if len(cleaned) not in _LENGTHS:
        raise InvalidEanError(code, "must have 8, 12, 13 or 14 digits")
    if not is_valid_gtin(cleaned):
        raise InvalidEanError(code, "wrong check digit")
    return upc_a_to_ean13(cleaned) if len(cleaned) == 12 else cleaned
