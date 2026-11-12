"""NOVA processing group, taken from Open Food Facts (`nova_group`), never computed.

See docs/specs/README.md, "NOVA".
"""

import math
from enum import IntEnum


class NovaGroup(IntEnum):
    UNPROCESSED_OR_MINIMALLY_PROCESSED = 1
    PROCESSED_CULINARY_INGREDIENTS = 2
    PROCESSED = 3
    ULTRA_PROCESSED = 4


def nova_group_from_off(value: object) -> NovaGroup | None:
    """The NOVA group from an Open Food Facts `nova_group` value; None when unknown.

    Accepts the forms seen in OFF data (4, "4", 4.0). Anything else (missing, out of range,
    fractional, booleans, other text) is unknown rather than guessed.
    """
    if isinstance(value, bool):
        return None
    number: float
    if isinstance(value, int | float):
        number = value
    elif isinstance(value, str):
        try:
            number = float(value.strip())
        except ValueError:
            return None
    else:
        return None
    if not math.isfinite(number) or not number.is_integer():
        return None
    try:
        return NovaGroup(int(number))
    except ValueError:
        return None
