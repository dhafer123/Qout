"""Engine validation: our Nutri-Score grades against Open Food Facts' own (2023 algorithm).

`load_comparisons` reads the current-engine score of every scorable product; `validate`
computes the metrics and `render_markdown` writes the report (both pure). The script
`scripts/validate_engine.py` puts them together.

Only products OFF grades are compared. OFF sometimes estimates inputs (usually the
fruit/vegetable share from the ingredients) and says so; those comparisons are shown
apart because a difference there can come from the estimate rather than the engine.
"""

from collections import Counter
from collections.abc import Iterable
from dataclasses import dataclass, field
from datetime import date

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.modules.products.models import Product, ProductStatus, Score
from app.modules.scoring import ENGINE_VERSION, Category, Grade

INSUFFICIENT = "insufficient data"
SMALL_SAMPLE = 300
"""Below this many products graded by both, the report says it is not representative."""
_GRADES = tuple(Grade)
_ESTIMATED_LABELS = {False: "not estimated", True: "estimated", None: "unknown"}
_EMPTY = "-"


@dataclass(frozen=True)
class Comparison:
    ean: str
    name: str | None
    category: Category
    ours: Grade | None
    """None: insufficient data."""
    off: Grade
    off_estimated: bool | None
    total: int | None
    assumed_zero: tuple[str, ...] = ()
    missing: tuple[str, ...] = ()
    """Our missing inputs when `ours` is None."""

    @property
    def distance(self) -> int | None:
        if self.ours is None:
            return None
        return abs(_GRADES.index(self.ours) - _GRADES.index(self.off))


@dataclass(frozen=True)
class Rate:
    matching: int
    total: int

    @property
    def percent(self) -> float | None:
        return None if self.total == 0 else 100 * self.matching / self.total


@dataclass(frozen=True)
class Validation:
    scorable: int
    """Products with a known category (not hidden)."""
    scored: int
    """Of those, scored with the current engine."""
    comparisons: tuple[Comparison, ...]
    """Products OFF grades."""
    exact: Rate
    within_one: Rate
    insufficient: tuple[Comparison, ...]
    """OFF grades them, we report insufficient data."""
    confusion: Counter[tuple[str, Grade]] = field(default_factory=Counter)
    """(our grade or INSUFFICIENT, OFF's grade) -> products."""
    by_category: dict[Category, Rate] = field(default_factory=dict)
    by_estimated: dict[str, Rate] = field(default_factory=dict)
    mismatches: tuple[Comparison, ...] = ()
    """Graded by both with different grades: largest distance first, then by EAN."""

    @property
    def graded(self) -> int:
        return self.exact.total


def validate(*, scorable: int, scored: int, comparisons: Iterable[Comparison]) -> Validation:
    rows = tuple(comparisons)
    graded = [c for c in rows if c.ours is not None]
    confusion: Counter[tuple[str, Grade]] = Counter(
        (INSUFFICIENT if c.ours is None else c.ours.value, c.off) for c in rows
    )
    mismatches = sorted(
        (c for c in graded if c.ours != c.off), key=lambda c: (-(c.distance or 0), c.ean)
    )
    return Validation(
        scorable=scorable,
        scored=scored,
        comparisons=rows,
        exact=_rate(graded),
        within_one=Rate(sum((c.distance or 0) <= 1 for c in graded), len(graded)),
        insufficient=tuple(sorted((c for c in rows if c.ours is None), key=lambda c: c.ean)),
        confusion=confusion,
        by_category={
            category: _rate([c for c in graded if c.category == category])
            for category in Category
            if any(c.category == category for c in graded)
        },
        by_estimated={
            label: _rate([c for c in graded if c.off_estimated is value])
            for value, label in _ESTIMATED_LABELS.items()
            if any(c.off_estimated is value for c in graded)
        },
        mismatches=tuple(mismatches),
    )


def _rate(graded: list[Comparison]) -> Rate:
    return Rate(sum(c.ours == c.off for c in graded), len(graded))


# ---------------------------------------------------------------- database


async def load_comparisons(session: AsyncSession) -> Validation:
    """Metrics for the products in the database (latest current-engine score each)."""
    scorable_filter = (Product.category.is_not(None), Product.status != ProductStatus.HIDDEN)
    scorable = (
        await session.scalar(select(func.count()).select_from(Product).where(*scorable_filter)) or 0
    )
    ranked = (
        select(
            Score,
            func.row_number()
            .over(
                partition_by=Score.product_id, order_by=(Score.created_at.desc(), Score.id.desc())
            )
            .label("rank"),
        )
        .join(Product, Product.id == Score.product_id)
        .where(Score.engine_version == ENGINE_VERSION, *scorable_filter)
        .subquery()
    )
    latest = aliased(Score, ranked)
    result = await session.execute(
        select(latest, Product)
        .join(Product, Product.id == latest.product_id)
        .where(ranked.c.rank == 1)
        .order_by(Product.ean)
    )
    rows = result.all()
    comparisons = [
        _comparison(score, product, off=score.off_grade, category=product.category)
        for score, product in rows
        if score.off_grade is not None and product.category is not None
    ]
    return validate(scorable=scorable, scored=len(rows), comparisons=comparisons)


def _comparison(score: Score, product: Product, *, off: Grade, category: Category) -> Comparison:
    breakdown = score.breakdown
    return Comparison(
        ean=product.ean,
        name=product.name,
        category=category,
        ours=score.grade,
        off=off,
        off_estimated=score.off_grade_estimated,
        total=score.total,
        assumed_zero=tuple(breakdown.get("assumed_zero", ())),
        missing=tuple(breakdown.get("insufficient_data", ())),
    )


# ---------------------------------------------------------------- Markdown


def render_markdown(
    validation: Validation, *, generated_on: date, source: str, top: int = 25
) -> str:
    v = validation
    lines = [
        f"# Engine validation: `{ENGINE_VERSION}`",
        "",
        f"Generated {generated_on.isoformat()} from {source}. Our grade (Python engine "
        f"`{ENGINE_VERSION}`) compared with Open Food Facts' own Nutri-Score grade "
        "(2023 algorithm), for every product OFF grades.",
        "",
    ]
    if v.graded < SMALL_SAMPLE:
        lines += [
            f"> **Small sample: {v.graded} products graded by both** (fewer than "
            f"{SMALL_SAMPLE}). The numbers below are not representative; regenerate after "
            "the full Open Food Facts import (`python -m app.worker run export`).",
            "",
        ]
    lines += [
        "## Summary",
        "",
        "| | Products |",
        "|---|---:|",
        f"| Scorable (known category, not hidden) | {v.scorable} |",
        f"| Scored with `{ENGINE_VERSION}` | {v.scored} |",
        f"| Graded by OFF | {len(v.comparisons)} |",
        f"| Graded by both | {v.graded} |",
        f"| **Same grade** | **{_rate_text(v.exact)}** |",
        f"| Within one grade | {_rate_text(v.within_one)} |",
        f"| OFF grades, we report insufficient data | {len(v.insufficient)} |",
        "",
    ]
    if v.scored < v.scorable:
        lines += [
            f"{v.scorable - v.scored} scorable products have no score with this engine yet "
            "and are left out (`python -m app.worker run rescore`).",
            "",
        ]
    lines += _confusion(v) + _breakdowns(v) + _mismatches(v, top) + _insufficient(v, top)
    return "\n".join(lines).rstrip() + "\n"


def _confusion(v: Validation) -> list[str]:
    header = "| Ours \\ OFF | " + " | ".join(g.value for g in _GRADES) + " |"
    lines = ["## Confusion matrix", "", "Rows: our grade. Columns: OFF's grade.", ""]
    lines += [header, "|---|" + "---:|" * len(_GRADES)]
    for ours in [*(g.value for g in _GRADES), INSUFFICIENT]:
        counts = [_cell(v.confusion[(ours, off)], diagonal=ours == off.value) for off in _GRADES]
        cells = " | ".join(counts)
        lines.append(f"| {ours.capitalize() if ours == INSUFFICIENT else ours} | {cells} |")
    return [*lines, ""]


def _cell(count: int, *, diagonal: bool) -> str:
    if count == 0:
        return "·"
    return f"**{count}**" if diagonal else str(count)


def _breakdowns(v: Validation) -> list[str]:
    lines = ["## Agreement by category", "", "| Category | Graded by both | Same grade |"]
    lines.append("|---|---:|---:|")
    lines += [f"| {c.value} | {r.total} | {_rate_text(r)} |" for c, r in v.by_category.items()]
    lines += ["", "## Agreement by OFF estimation", ""]
    lines += [
        "OFF marks a grade as estimated when some inputs (usually the fruit/vegetable share) "
        "come from the ingredient list rather than the label.",
        "",
        "| OFF inputs | Graded by both | Same grade |",
        "|---|---:|---:|",
    ]
    lines += [f"| {label} | {r.total} | {_rate_text(r)} |" for label, r in v.by_estimated.items()]
    return [*lines, ""]


def _mismatches(v: Validation, top: int) -> list[str]:
    lines = [f"## Mismatches (top {top})", ""]
    if not v.mismatches:
        return [*lines, "None.", ""]
    lines += [
        "| EAN | Product | Category | Ours | OFF | Distance | Our total | Assumed 0 | "
        "OFF estimated |",
        "|---|---|---|---|---|---:|---:|---|---|",
    ]
    for c in v.mismatches[:top]:
        lines.append(
            f"| {c.ean} | {_text(c.name)} | {c.category.value} | {_grade(c.ours)} | "
            f"{c.off.value} | {c.distance} | {_text(c.total)} | "
            f"{', '.join(c.assumed_zero) or _EMPTY} | {_ESTIMATED_LABELS[c.off_estimated]} |"
        )
    if len(v.mismatches) > top:
        lines.append(f"\n{len(v.mismatches) - top} more not shown.")
    return [*lines, ""]


def _insufficient(v: Validation, top: int) -> list[str]:
    lines = [f"## OFF grades, we report insufficient data (first {top})", ""]
    if not v.insufficient:
        return [*lines, "None.", ""]
    lines += [
        "| EAN | Product | Category | OFF | OFF estimated | Our missing inputs |",
        "|---|---|---|---|---|---|",
    ]
    lines += [
        f"| {c.ean} | {_text(c.name)} | {c.category.value} | {c.off.value} | "
        f"{_ESTIMATED_LABELS[c.off_estimated]} | {', '.join(c.missing)} |"
        for c in v.insufficient[:top]
    ]
    if len(v.insufficient) > top:
        lines.append(f"\n{len(v.insufficient) - top} more not shown.")
    return [*lines, ""]


def _rate_text(rate: Rate) -> str:
    percent = rate.percent
    return _EMPTY if percent is None else f"{rate.matching} ({percent:.1f} %)"


def _grade(grade: Grade | None) -> str:
    return _EMPTY if grade is None else grade.value


def _text(value: object) -> str:
    return _EMPTY if value is None else str(value).replace("|", "\\|").replace("\n", " ")
