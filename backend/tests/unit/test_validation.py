"""Validation report metrics and Markdown on a fixed list of comparisons."""

from datetime import date

from app.modules.products.validation import (
    INSUFFICIENT,
    SMALL_SAMPLE,
    Comparison,
    Rate,
    render_markdown,
    validate,
)
from app.modules.scoring import Category, Grade

A, B, C, D, E = Grade.A, Grade.B, Grade.C, Grade.D, Grade.E
GENERAL, CHEESE, BEVERAGE = Category.GENERAL, Category.CHEESE, Category.BEVERAGE


def comparison(
    ean: str,
    ours: Grade | None,
    off: Grade,
    category: Category = GENERAL,
    *,
    estimated: bool | None = False,
    name: str | None = None,
    **extra: object,
) -> Comparison:
    return Comparison(
        ean=ean,
        name=name or f"Product {ean}",
        category=category,
        ours=ours,
        off=off,
        off_estimated=estimated,
        total=None if ours is None else 5,
        **extra,  # type: ignore[arg-type]
    )


FIXTURE = [
    comparison("1", A, A),
    comparison("2", B, B),
    comparison("3", C, D, estimated=True, assumed_zero=("fibre_g",)),
    comparison("4", E, B, CHEESE, estimated=None),
    comparison("5", None, C, estimated=True, missing=("salt_g", "sugars_g")),
    comparison("6", D, D, BEVERAGE),
]


def test_metrics() -> None:
    v = validate(scorable=10, scored=8, comparisons=FIXTURE)

    assert (v.scorable, v.scored, len(v.comparisons), v.graded) == (10, 8, 6, 5)
    assert v.exact == Rate(3, 5)
    assert v.exact.percent == 60.0
    assert v.within_one == Rate(4, 5)
    assert [c.ean for c in v.insufficient] == ["5"]
    assert v.insufficient[0].distance is None  # no grade of ours to compare
    assert v.confusion == {
        ("A", A): 1,
        ("B", B): 1,
        ("C", D): 1,
        ("E", B): 1,
        ("D", D): 1,
        (INSUFFICIENT, C): 1,
    }
    assert v.by_category == {GENERAL: Rate(2, 3), CHEESE: Rate(0, 1), BEVERAGE: Rate(1, 1)}
    assert v.by_estimated == {
        "not estimated": Rate(3, 3),
        "estimated": Rate(0, 1),
        "unknown": Rate(0, 1),
    }
    assert [(c.ean, c.distance) for c in v.mismatches] == [("4", 3), ("3", 1)]


def test_mismatches_with_equal_distance_are_ordered_by_ean() -> None:
    v = validate(scorable=3, scored=3, comparisons=[comparison("9", A, B), comparison("1", C, D)])
    assert [c.ean for c in v.mismatches] == ["1", "9"]


def test_no_comparisons() -> None:
    v = validate(scorable=0, scored=0, comparisons=[])
    assert (v.exact.percent, v.within_one.percent, v.graded) == (None, None, 0)
    assert (v.by_category, v.by_estimated, v.mismatches) == ({}, {}, ())

    report = render_markdown(v, generated_on=date(2026, 11, 12), source="nowhere")
    assert "| **Same grade** | **-** |" in report
    assert report.count("None.") == 2


def test_markdown() -> None:
    v = validate(scorable=10, scored=8, comparisons=FIXTURE)

    report = render_markdown(v, generated_on=date(2026, 11, 12), source="the dev database")

    assert report.startswith("# Engine validation: `nutriscore-")
    assert "Generated 2026-11-12 from the dev database." in report
    assert "**Small sample: 5 products graded by both**" in report
    assert "| **Same grade** | **3 (60.0 %)** |" in report
    assert "| Within one grade | 4 (80.0 %) |" in report
    assert "| OFF grades, we report insufficient data | 1 |" in report
    assert "2 scorable products have no score with this engine yet" in report
    assert "| A | **1** | · | · | · | · |" in report
    assert "| E | · | 1 | · | · | · |" in report
    assert "| Insufficient data | · | · | 1 | · | · |" in report
    assert "| cheese | 1 | 0 (0.0 %) |" in report
    assert "| estimated | 1 | 0 (0.0 %) |" in report
    mismatch_rows = [line for line in report.splitlines() if line.startswith(("| 4 |", "| 3 |"))]
    assert mismatch_rows == [
        "| 4 | Product 4 | cheese | E | B | 3 | 5 | - | unknown |",
        "| 3 | Product 3 | general | C | D | 1 | 5 | fibre_g | estimated |",
    ]
    assert "| 5 | Product 5 | general | C | estimated | salt_g, sugars_g |" in report
    assert report.endswith("|\n")


def test_markdown_truncates_and_escapes() -> None:
    rows = [
        comparison("1", A, C, name="Pipe | name"),
        comparison("2", A, B),
        comparison("3", None, B),
        comparison("4", None, B),
    ]
    v = validate(scorable=4, scored=4, comparisons=rows)

    report = render_markdown(v, generated_on=date(2026, 11, 12), source="x", top=1)

    assert "| 1 | Pipe \\| name |" in report
    assert report.count("1 more not shown.") == 2
    assert "| 2 | Product 2 |" not in report


def test_large_sample_has_no_warning() -> None:
    rows = [comparison(str(n), B, B) for n in range(SMALL_SAMPLE)]
    v = validate(scorable=SMALL_SAMPLE, scored=SMALL_SAMPLE, comparisons=rows)
    report = render_markdown(v, generated_on=date(2026, 11, 12), source="x")
    assert "Small sample" not in report
    assert "no score with this engine yet" not in report
    assert f"| **Same grade** | **{SMALL_SAMPLE} (100.0 %)** |" in report
