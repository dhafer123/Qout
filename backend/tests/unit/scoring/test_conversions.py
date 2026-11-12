"""Unit conversions: kcal -> kJ (calculator rounding) and sodium -> salt."""

import math

import pytest

from app.modules.scoring import kj_from_kcal, salt_from_sodium
from app.modules.scoring.conversions import to_decimal


@pytest.mark.parametrize(
    ("kcal", "kj"),
    [
        (0, 0),
        (100, 420),
        (1, 4),  # 4.2
        (0.5, 2),  # 2.1
        (2.5, 11),  # 10.5: half rounds up, like Excel ROUND (Python round() gives 10)
        (7.5, 32),  # 31.5
        (12.5, 53),  # 52.5
        (80.1, 336),  # 336.42
        (900, 3780),
    ],
)
def test_kj_from_kcal_rounds_like_the_calculator(kcal: float, kj: int) -> None:
    assert kj_from_kcal(kcal) == kj


@pytest.mark.parametrize(
    ("sodium", "salt"),
    [(0, 0.0), (0.4, 1.0), (1, 2.5), (0.08, 0.2), (0.12, 0.3), (1.28, 3.2)],
)
def test_salt_from_sodium(sodium: float, salt: float) -> None:
    assert salt_from_sodium(sodium) == salt


def test_salt_from_sodium_has_no_float_noise() -> None:
    # In binary floats 0.56 * 2.5 is 1.4000000000000001: just above the 1.4 g salt threshold.
    assert 0.56 * 2.5 > 1.4
    assert salt_from_sodium(0.56) == 1.4
    assert salt_from_sodium(1.36) == 3.4


@pytest.mark.parametrize("bad", [-1, -0.01, math.nan, math.inf])
def test_conversions_reject_impossible_values(bad: float) -> None:
    with pytest.raises(ValueError, match="finite number >= 0"):
        kj_from_kcal(bad)
    with pytest.raises(ValueError, match="finite number >= 0"):
        salt_from_sodium(bad)


def test_to_decimal_keeps_the_written_value() -> None:
    assert str(to_decimal(4.1)) == "4.1"
    assert str(to_decimal(3)) == "3"
