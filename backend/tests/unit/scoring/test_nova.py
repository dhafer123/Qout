"""NOVA group mapping from Open Food Facts values."""

import math

import pytest

from app.modules.scoring import NovaGroup, nova_group_from_off


@pytest.mark.parametrize(
    ("value", "group"),
    [
        (1, NovaGroup.UNPROCESSED_OR_MINIMALLY_PROCESSED),
        (2, NovaGroup.PROCESSED_CULINARY_INGREDIENTS),
        (3, NovaGroup.PROCESSED),
        (4, NovaGroup.ULTRA_PROCESSED),
        ("4", NovaGroup.ULTRA_PROCESSED),
        (" 3 ", NovaGroup.PROCESSED),
        (4.0, NovaGroup.ULTRA_PROCESSED),
        ("1.0", NovaGroup.UNPROCESSED_OR_MINIMALLY_PROCESSED),
    ],
)
def test_known_values(value: object, group: NovaGroup) -> None:
    assert nova_group_from_off(value) is group


@pytest.mark.parametrize(
    "value",
    [
        None,
        0,
        5,
        -1,
        3.5,
        "3.5",
        "",
        "four",
        "en:4",
        math.nan,
        math.inf,
        "nan",
        True,
        False,
        [4],
        {"nova_group": 4},
    ],
)
def test_unknown_values(value: object) -> None:
    assert nova_group_from_off(value) is None


def test_groups_are_numbered_1_to_4() -> None:
    assert [int(g) for g in NovaGroup] == [1, 2, 3, 4]
