"""Nutri-Score point tables and grade bands (updated algorithm, 2023).

Every number here comes from docs/specs/ (CLAUDE.md rule 2); each table cites its source.
"Q&A" is nutri-score-qa-v11.pdf, "2022 report" the foods report, "2023 report" the
beverages report. Each table was also checked against the official calculator
(nutri-score-calculator-2024-04-04.xlsx).

Reading a table (docs/specs/README.md, decision 1): a value exactly on a threshold gets the
lower points ("0 points: <= t1; 1 point: > t1"). The only exception is the saturates/fat
ratio of the fats category, written with "<" (decision 2). Beverage salt of exactly 3.2 g
gets 15 points like any other threshold (decision 3; the calculator's "< 3.2" is a typo).
"""

from bisect import bisect_left, bisect_right
from dataclasses import dataclass
from decimal import Decimal

from app.modules.scoring.models import Grade


def _d(*values: str) -> tuple[Decimal, ...]:
    return tuple(Decimal(v) for v in values)


@dataclass(frozen=True, slots=True)
class PointTable:
    """Ascending thresholds; crossing the i-th threshold (1-based) gives `steps[i - 1]` points.

    `steps` defaults to 1, 2, 3, ... (one more point per threshold). With `strict`, a value
    equal to a threshold already counts as crossing it ("<" tables).
    """

    thresholds: tuple[Decimal, ...]
    steps: tuple[int, ...] = ()
    strict: bool = False

    def __post_init__(self) -> None:
        if list(self.thresholds) != sorted(set(self.thresholds)):
            msg = "thresholds must be strictly ascending"
            raise ValueError(msg)
        if not self.steps:
            object.__setattr__(self, "steps", tuple(range(1, len(self.thresholds) + 1)))
        if len(self.steps) != len(self.thresholds):
            msg = "one step per threshold"
            raise ValueError(msg)

    @property
    def max_points(self) -> int:
        return self.steps[-1]

    def points(self, value: Decimal) -> int:
        crossed = (bisect_right if self.strict else bisect_left)(self.thresholds, value)
        return self.steps[crossed - 1] if crossed else 0


@dataclass(frozen=True, slots=True)
class GradeBands:
    """Highest score (inclusive) for each grade, best first; any higher score gets `worst`."""

    upper_bounds: tuple[tuple[int, Grade], ...]
    worst: Grade

    def grade(self, score: int) -> Grade:
        for upper, grade in self.upper_bounds:
            if score <= upper:
                return grade
        return self.worst


# --------------------------------------------------------------------------------------
# Shared by general foods, red meat, cheese and fats/oils/nuts/seeds.

# Q&A Table 5; 2022 report recap. 0-15 points.
SUGARS_G = PointTable(
    _d("3.4", "6.8", "10", "14", "17", "20", "24", "27", "31", "34", "37", "41", "44", "48", "51")
)

# Q&A Tables 5, 7 and 9 (same salt scale for foods, fats and beverages). 0-20 points.
SALT_G = PointTable(tuple(Decimal(n) / 5 for n in range(1, 21)))  # 0.2, 0.4, ..., 4.0

# Q&A Tables 6 and 8. 0-7 points.
PROTEIN_G = PointTable(_d("2.4", "4.8", "7.2", "9.6", "12", "14", "17"))

# Q&A Tables 6, 8 and 10 (same fibre scale everywhere). 0-5 points.
FIBRE_G = PointTable(_d("3.0", "4.1", "5.2", "6.3", "7.4"))

# Q&A Tables 6 and 8: 0, 1, 2 or 5 points (> 40 %, > 60 %, > 80 %).
FVL_PERCENT = PointTable(_d("40", "60", "80"), steps=(1, 2, 5))

# --------------------------------------------------------------------------------------
# General foods, red meat, cheese.

# Q&A Table 5. 0-10 points.
ENERGY_KJ = PointTable(tuple(Decimal(335 * n) for n in range(1, 11)))  # 335, 670, ..., 3350

# Q&A Table 5. 0-10 points.
SATURATED_FAT_G = PointTable(tuple(Decimal(n) for n in range(1, 11)))  # 1, 2, ..., 10

# Q&A Table 6, footnote: red meat and products thereof get at most 2 protein points.
RED_MEAT_MAX_PROTEIN_POINTS = 2

# Q&A p. 28: with N >= 11 (and not cheese), protein points are not subtracted.
FOODS_PROTEIN_N_LIMIT = 11

# 2022 report §1.8.2 p. 50 (calculator: "< 1" A, "< 3" B, "< 11" C, "< 19" D).
FOODS_GRADES = GradeBands(((0, Grade.A), (2, Grade.B), (10, Grade.C), (18, Grade.D)), worst=Grade.E)

# --------------------------------------------------------------------------------------
# Fats, oils, nuts and seeds.

# Q&A Table 7: energy from saturates (kJ/100 g) = saturated fat (g/100 g) x 37.
KJ_PER_G_SATURATED_FAT = Decimal(37)

# Q&A Table 7. 0-10 points.
ENERGY_FROM_SATURATES_KJ = PointTable(tuple(Decimal(120 * n) for n in range(1, 11)))

# Q&A Table 7: saturates / lipids in %, written with "<" (decision 2). 0-10 points.
SATURATED_FAT_RATIO_PERCENT = PointTable(
    _d("10", "16", "22", "28", "34", "40", "46", "52", "58", "64"), strict=True
)

# Q&A p. 30: with N >= 7, protein points are not subtracted.
FATS_PROTEIN_N_LIMIT = 7

# 2022 report §2.4.3 p. 73 (calculator: "< -5" A, "< 3" B, "< 11" C, "< 19" D).
FATS_GRADES = GradeBands(((-6, Grade.A), (2, Grade.B), (10, Grade.C), (18, Grade.D)), worst=Grade.E)

# --------------------------------------------------------------------------------------
# Beverages (per 100 mL).

# Q&A Table 9; 2023 report p. 73. 0-10 points.
BEVERAGE_ENERGY_KJ = PointTable(
    _d("30", "90", "150", "210", "240", "270", "300", "330", "360", "390")
)

# Q&A Table 9. 0-10 points.
BEVERAGE_SUGARS_G = PointTable(_d("0.5", "2", "3.5", "5", "6", "7", "8", "9", "10", "11"))

# Q&A Table 9: same scale as foods. 0-10 points.
BEVERAGE_SATURATED_FAT_G = SATURATED_FAT_G

# Q&A Table 9: presence of non-nutritive sweeteners.
NON_NUTRITIVE_SWEETENERS_POINTS = 4

# Q&A Table 10. 0-7 points.
BEVERAGE_PROTEIN_G = PointTable(_d("1.2", "1.5", "1.8", "2.1", "2.4", "2.7", "3.0"))

# Q&A Table 10: 0, 2, 4 or 6 points (> 40 %, > 60 %, > 80 %).
BEVERAGE_FVL_PERCENT = PointTable(_d("40", "60", "80"), steps=(2, 4, 6))

# 2023 report §6.7.3 p. 48 and p. 74. Only water is A (handled by the engine).
BEVERAGE_GRADES = GradeBands(((2, Grade.B), (6, Grade.C), (9, Grade.D)), worst=Grade.E)
