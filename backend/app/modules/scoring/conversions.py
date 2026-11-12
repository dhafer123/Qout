"""Unit conversions for nutrition values. The only place where units are converted.

Sources (docs/specs/README.md, "Constants for later tasks"):
- salt = sodium x 2.5 (Q&A V11 p. 12; calculator sheet "Conversion tool").
- kJ = ROUND(kcal x 4.2, 0) (calculator sheet "Conversion tool"). Excel's ROUND rounds
  halves away from zero, so this uses ROUND_HALF_UP on exact decimals, not `round()`.
"""

import math
from decimal import ROUND_HALF_UP, Decimal

KJ_PER_KCAL = Decimal("4.2")
SALT_PER_SODIUM = Decimal("2.5")


def to_decimal(value: float) -> Decimal:
    """The decimal number a float was written as (4.1 -> Decimal('4.1'), not 4.0999...)."""
    return Decimal(repr(value))


def kj_from_kcal(kcal: float) -> int:
    """Energy in kJ from kcal, rounded like the official calculator."""
    _check(kcal, "kcal")
    return int((to_decimal(kcal) * KJ_PER_KCAL).quantize(Decimal(1), rounding=ROUND_HALF_UP))


def salt_from_sodium(sodium_g: float) -> float:
    """Salt in g from sodium in g (same unit, per 100 g or 100 mL)."""
    _check(sodium_g, "sodium_g")
    return float(to_decimal(sodium_g) * SALT_PER_SODIUM)


def _check(value: float, name: str) -> None:
    if not math.isfinite(value) or value < 0:
        msg = f"{name} must be a finite number >= 0, got {value!r}"
        raise ValueError(msg)
