"""Every point table and grade band, at and around every threshold.

The expected values are transcribed separately from the official calculator
(docs/specs/nutri-score-calculator-2024-04-04.xlsx, "Scenario" sheet and the per-category
formulas), so a typo in `tables.py` fails here.
"""

from decimal import Decimal

import pytest

from app.modules.scoring import Grade
from app.modules.scoring import tables as t

EPS = Decimal("0.001")

# (table, [(threshold, points just above it), ...]); 0 points at or below the first one.
LE_TABLES: dict[str, tuple[t.PointTable, list[tuple[str, int]]]] = {
    "energy_kj": (
        t.ENERGY_KJ,
        [
            ("335", 1),
            ("670", 2),
            ("1005", 3),
            ("1340", 4),
            ("1675", 5),
            ("2010", 6),
            ("2345", 7),
            ("2680", 8),
            ("3015", 9),
            ("3350", 10),
        ],
    ),
    "saturated_fat_g": (
        t.SATURATED_FAT_G,
        [(str(n), n) for n in range(1, 11)],
    ),
    "sugars_g": (
        t.SUGARS_G,
        [
            ("3.4", 1),
            ("6.8", 2),
            ("10", 3),
            ("14", 4),
            ("17", 5),
            ("20", 6),
            ("24", 7),
            ("27", 8),
            ("31", 9),
            ("34", 10),
            ("37", 11),
            ("41", 12),
            ("44", 13),
            ("48", 14),
            ("51", 15),
        ],
    ),
    "salt_g": (
        t.SALT_G,
        [
            ("0.2", 1),
            ("0.4", 2),
            ("0.6", 3),
            ("0.8", 4),
            ("1", 5),
            ("1.2", 6),
            ("1.4", 7),
            ("1.6", 8),
            ("1.8", 9),
            ("2", 10),
            ("2.2", 11),
            ("2.4", 12),
            ("2.6", 13),
            ("2.8", 14),
            ("3", 15),
            ("3.2", 16),
            ("3.4", 17),
            ("3.6", 18),
            ("3.8", 19),
            ("4", 20),
        ],
    ),
    "protein_g": (
        t.PROTEIN_G,
        [("2.4", 1), ("4.8", 2), ("7.2", 3), ("9.6", 4), ("12", 5), ("14", 6), ("17", 7)],
    ),
    "fibre_g": (
        t.FIBRE_G,
        [("3", 1), ("4.1", 2), ("5.2", 3), ("6.3", 4), ("7.4", 5)],
    ),
    "fvl_percent": (t.FVL_PERCENT, [("40", 1), ("60", 2), ("80", 5)]),
    "energy_from_saturates_kj": (
        t.ENERGY_FROM_SATURATES_KJ,
        [(str(120 * n), n) for n in range(1, 11)],
    ),
    "beverage_energy_kj": (
        t.BEVERAGE_ENERGY_KJ,
        [
            ("30", 1),
            ("90", 2),
            ("150", 3),
            ("210", 4),
            ("240", 5),
            ("270", 6),
            ("300", 7),
            ("330", 8),
            ("360", 9),
            ("390", 10),
        ],
    ),
    "beverage_sugars_g": (
        t.BEVERAGE_SUGARS_G,
        [
            ("0.5", 1),
            ("2", 2),
            ("3.5", 3),
            ("5", 4),
            ("6", 5),
            ("7", 6),
            ("8", 7),
            ("9", 8),
            ("10", 9),
            ("11", 10),
        ],
    ),
    "beverage_saturated_fat_g": (
        t.BEVERAGE_SATURATED_FAT_G,
        [(str(n), n) for n in range(1, 11)],
    ),
    "beverage_protein_g": (
        t.BEVERAGE_PROTEIN_G,
        [("1.2", 1), ("1.5", 2), ("1.8", 3), ("2.1", 4), ("2.4", 5), ("2.7", 6), ("3", 7)],
    ),
    "beverage_fvl_percent": (t.BEVERAGE_FVL_PERCENT, [("40", 2), ("60", 4), ("80", 6)]),
}

LE_CASES = [
    pytest.param(table, Decimal(threshold), index, points, id=f"{name}-{threshold}")
    for name, (table, rows) in LE_TABLES.items()
    for index, (threshold, points) in enumerate(rows)
]


@pytest.mark.parametrize(("name", "table_and_rows"), list(LE_TABLES.items()))
def test_table_has_exactly_the_expected_thresholds(
    name: str, table_and_rows: tuple[t.PointTable, list[tuple[str, int]]]
) -> None:
    table, rows = table_and_rows
    assert table.thresholds == tuple(Decimal(value) for value, _ in rows), name
    assert table.steps == tuple(points for _, points in rows), name
    assert not table.strict


@pytest.mark.parametrize(("table", "threshold", "index", "points"), LE_CASES)
def test_value_on_a_threshold_gets_the_lower_points(
    table: t.PointTable, threshold: Decimal, index: int, points: int
) -> None:
    below = table.steps[index - 1] if index else 0
    assert table.points(threshold - EPS) == below
    assert table.points(threshold) == below
    assert table.points(threshold + EPS) == points


@pytest.mark.parametrize(("name", "table_and_rows"), list(LE_TABLES.items()))
def test_zero_and_huge_values(
    name: str, table_and_rows: tuple[t.PointTable, list[tuple[str, int]]]
) -> None:
    table, rows = table_and_rows
    assert table.points(Decimal(0)) == 0, name
    assert table.points(Decimal(100_000)) == rows[-1][1] == table.max_points, name


SATURATED_RATIO = [("10", 1), ("16", 2), ("22", 3), ("28", 4), ("34", 5), ("40", 6),
                   ("46", 7), ("52", 8), ("58", 9), ("64", 10)]  # fmt: skip


@pytest.mark.parametrize(("index", "row"), list(enumerate(SATURATED_RATIO)), ids=str)
def test_saturated_fat_ratio_is_strict(index: int, row: tuple[str, int]) -> None:
    """Q&A Table 7 uses "<": a ratio exactly on a threshold gets the higher points."""
    threshold, points = Decimal(row[0]), row[1]
    table = t.SATURATED_FAT_RATIO_PERCENT
    assert table.strict
    assert table.points(threshold - EPS) == index  # previous step: 0, 1, ..., 9
    assert table.points(threshold) == points
    assert table.points(threshold + EPS) == points


def test_saturated_fat_ratio_thresholds() -> None:
    table = t.SATURATED_FAT_RATIO_PERCENT
    assert table.thresholds == tuple(Decimal(v) for v, _ in SATURATED_RATIO)
    assert table.points(Decimal(0)) == 0
    assert table.points(Decimal(100)) == 10


def test_beverage_salt_at_3_2_gets_15_points() -> None:
    """Decision 3: the tables say "> 3.2" for 16 points; the calculator's "< 3.2" is a typo."""
    assert t.SALT_G.points(Decimal("3.2")) == 15
    assert t.SALT_G.points(Decimal("3.21")) == 16


def test_constants() -> None:
    assert t.RED_MEAT_MAX_PROTEIN_POINTS == 2
    assert t.FOODS_PROTEIN_N_LIMIT == 11
    assert t.FATS_PROTEIN_N_LIMIT == 7
    assert t.KJ_PER_G_SATURATED_FAT == 37
    assert t.NON_NUTRITIVE_SWEETENERS_POINTS == 4


GRADE_CASES = [
    # foods: A <= 0, B 1-2, C 3-10, D 11-18, E >= 19
    (t.FOODS_GRADES, [(-15, "A"), (0, "A"), (1, "B"), (2, "B"), (3, "C"), (10, "C"),
                      (11, "D"), (18, "D"), (19, "E"), (40, "E")]),
    # fats: A <= -6, B -5 to 2, C 3-10, D 11-18, E >= 19
    (t.FATS_GRADES, [(-17, "A"), (-6, "A"), (-5, "B"), (2, "B"), (3, "C"), (10, "C"),
                     (11, "D"), (18, "D"), (19, "E"), (55, "E")]),
    # beverages: B <= 2, C 3-6, D 7-9, E >= 10 (A only for water)
    (t.BEVERAGE_GRADES, [(-18, "B"), (2, "B"), (3, "C"), (6, "C"), (7, "D"), (9, "D"),
                         (10, "E"), (49, "E")]),
]  # fmt: skip


@pytest.mark.parametrize(
    ("bands", "score", "grade"),
    [(bands, score, grade) for bands, rows in GRADE_CASES for score, grade in rows],
)
def test_grade_bands(bands: t.GradeBands, score: int, grade: str) -> None:
    assert bands.grade(score) == Grade(grade)


def test_point_table_rejects_unsorted_thresholds() -> None:
    with pytest.raises(ValueError, match="ascending"):
        t.PointTable((Decimal(2), Decimal(1)))
    with pytest.raises(ValueError, match="ascending"):
        t.PointTable((Decimal(1), Decimal(1)))


def test_point_table_rejects_mismatched_steps() -> None:
    with pytest.raises(ValueError, match="one step per threshold"):
        t.PointTable((Decimal(1), Decimal(2)), steps=(1,))
