"""Better alternatives to a product: same kind of food, better Nutri-Score grade.

Candidates (`AlternativesFinder`, from our database only):
- same Nutri-Score category (the same scoring rules, so grades compare);
- a strictly better grade, from the score of their latest nutrition with the current
  engine (products not rescored yet are skipped until the rescoring job catches up);
- not hidden, not the product itself;
- sharing at least one Open Food Facts food category when the product has any.

Ranking (`rank_alternatives`, pure):
1. more shared food categories first: tags run general to specific, so more shared tags
   means a closer kind of food (`en:harissa-sauces` beats `en:sauces` alone);
2. closer nutrient profile (`nutrient_distance`);
3. better score (lower total), then EAN, so the order is deterministic.
"""

from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass, field
from decimal import Decimal
from typing import cast

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.products.ean import normalize_ean
from app.modules.products.models import NutritionFacts, Product, ProductStatus, Score
from app.modules.products.repository import NutritionFactsRepository, ProductRepository
from app.modules.products.rescoring import ensure_current_score
from app.modules.scoring import ENGINE_VERSION, Category, Grade
from app.modules.scoring import tables as t

SIMILARITY_NUTRIENTS = (
    "energy_kj",
    "sugars_g",
    "saturated_fat_g",
    "salt_g",
    "protein_g",
    "fibre_g",
)
"""Declared values compared for similarity (the Nutri-Score inputs every category has)."""

_FOOD_SCALES: dict[str, Decimal] = {
    "energy_kj": t.ENERGY_KJ.thresholds[-1],
    "sugars_g": t.SUGARS_G.thresholds[-1],
    "saturated_fat_g": t.SATURATED_FAT_G.thresholds[-1],
    "salt_g": t.SALT_G.thresholds[-1],
    "protein_g": t.PROTEIN_G.thresholds[-1],
    "fibre_g": t.FIBRE_G.thresholds[-1],
}
_BEVERAGE_SCALES: dict[str, Decimal] = {
    "energy_kj": t.BEVERAGE_ENERGY_KJ.thresholds[-1],
    "sugars_g": t.BEVERAGE_SUGARS_G.thresholds[-1],
    "saturated_fat_g": t.BEVERAGE_SATURATED_FAT_G.thresholds[-1],
    "salt_g": t.SALT_G.thresholds[-1],
    "protein_g": t.BEVERAGE_PROTEIN_G.thresholds[-1],
    "fibre_g": t.FIBRE_G.thresholds[-1],
}

_GRADE_ORDER = (Grade.A, Grade.B, Grade.C, Grade.D, Grade.E)
_NO_TOTAL = 10**6  # sorts after every real score

MAX_CANDIDATES = 1000
"""Candidates ranked at most; the best grades come first if there are more."""


def similarity_scales(category: Category) -> dict[str, Decimal]:
    """How far apart two values are, per nutrient: the top threshold of the category's
    Nutri-Score point table (docs/specs/, via `scoring.tables`), so a gap is measured
    against the range the score itself uses. Fats are scored on energy from saturates and
    the saturates/fat ratio, but their declared values compare on the foods scale."""
    return dict(_BEVERAGE_SCALES if category == Category.BEVERAGE else _FOOD_SCALES)


def better_grades(grade: Grade) -> tuple[Grade, ...]:
    """Grades strictly better than `grade`."""
    return _GRADE_ORDER[: _GRADE_ORDER.index(grade)]


def nutrient_distance(
    a: Mapping[str, Decimal | None],
    b: Mapping[str, Decimal | None],
    scales: Mapping[str, Decimal],
) -> Decimal | None:
    """Mean scaled gap over the nutrients declared on both sides; None when they share
    none. Each gap is capped at 1: past the top of the table, more makes no difference to
    the score either."""
    gaps = [
        min(abs(x - y) / scales[name], Decimal(1))
        for name in SIMILARITY_NUTRIENTS
        if (x := a.get(name)) is not None and (y := b.get(name)) is not None
    ]
    if not gaps:
        return None
    return sum(gaps, Decimal(0)) / len(gaps)


@dataclass(frozen=True)
class Candidate:
    """A product as the ranking sees it."""

    ean: str
    grade: Grade
    total: int | None
    food_categories: tuple[str, ...] = ()
    nutrients: Mapping[str, Decimal | None] = field(default_factory=dict)
    name: str | None = None
    brand: str | None = None
    nova_group: int | None = None


def rank_alternatives(
    product: Candidate,
    category: Category,
    candidates: Iterable[Candidate],
    *,
    limit: int,
) -> list[Candidate]:
    """The best `limit` alternatives to `product` among `candidates` (any order, may
    include unsuitable ones: worse or equal grades, the product itself, other kinds of
    food)."""
    better = set(better_grades(product.grade))
    own = set(product.food_categories)
    scales = similarity_scales(category)

    ranked: list[tuple[tuple[int, int, Decimal, int, str], Candidate]] = []
    for candidate in candidates:
        if candidate.ean == product.ean or candidate.grade not in better:
            continue
        shared = len(own.intersection(candidate.food_categories))
        if own and shared == 0:
            continue
        distance = nutrient_distance(product.nutrients, candidate.nutrients, scales)
        key = (
            -shared,
            distance is None,  # comparable profiles first
            distance if distance is not None else Decimal(0),
            candidate.total if candidate.total is not None else _NO_TOTAL,
            candidate.ean,
        )
        ranked.append((key, candidate))
    ranked.sort(key=lambda item: item[0])
    return [candidate for _, candidate in ranked[:limit]]


# ---------------------------------------------------------------- database


class AlternativesProductNotFoundError(Exception):
    def __init__(self, ean: str) -> None:
        super().__init__(f"product {ean} not found")
        self.ean = ean


@dataclass(frozen=True)
class Alternatives:
    ean: str
    """The product they replace, as stored."""
    items: Sequence[Candidate]


class AlternativesFinder:
    """Reads our database only: never calls Open Food Facts."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._products = ProductRepository(session)
        self._nutrition = NutritionFactsRepository(session)

    async def find(self, code: str, *, limit: int) -> Alternatives:
        """Raises InvalidEanError (bad barcode) and AlternativesProductNotFoundError (not
        stored, or hidden). A product without a category or grade has no alternatives."""
        ean = normalize_ean(code)
        product = await self._products.get_by_ean(ean)
        if product is None or product.status == ProductStatus.HIDDEN:
            raise AlternativesProductNotFoundError(ean)
        facts = await self._nutrition.latest(product.id)
        current = await ensure_current_score(self._session, product, facts)
        if current.created:
            await self._session.commit()
        score = current.score
        # No nutrition: water (nothing beats A) or ungraded, nothing to compare.
        if product.category is None or facts is None or score is None or score.grade is None:
            return Alternatives(ean, [])
        better = better_grades(score.grade)
        if not better:
            return Alternatives(ean, [])

        own = Candidate(
            ean=ean,
            grade=score.grade,
            total=score.total,
            food_categories=tuple(product.food_categories),
            nutrients=_nutrients(facts),
        )
        candidates = await self._candidates(product, product.category, better)
        return Alternatives(ean, rank_alternatives(own, product.category, candidates, limit=limit))

    async def _candidates(
        self, product: Product, category: Category, grades: Sequence[Grade]
    ) -> list[Candidate]:
        latest = (
            select(
                NutritionFacts.product_id,
                func.max(NutritionFacts.version).label("version"),
            )
            .group_by(NutritionFacts.product_id)
            .subquery()
        )
        query = (
            select(Product, NutritionFacts, Score)
            .join(latest, latest.c.product_id == Product.id)
            .join(
                NutritionFacts,
                and_(
                    NutritionFacts.product_id == Product.id,
                    NutritionFacts.version == latest.c.version,
                ),
            )
            .join(
                Score,
                and_(
                    Score.nutrition_facts_id == NutritionFacts.id,
                    Score.engine_version == ENGINE_VERSION,
                ),
            )
            .where(
                Product.category == category,
                Product.status != ProductStatus.HIDDEN,
                Product.id != product.id,
                Score.grade.in_(grades),
            )
            .order_by(Score.grade, Product.id)
            .limit(MAX_CANDIDATES)
        )
        if product.food_categories:
            query = query.where(Product.food_categories.overlap(product.food_categories))
        rows = await self._session.execute(query)
        return [_candidate(p, f, s) for p, f, s in rows]


def _nutrients(facts: NutritionFacts) -> dict[str, Decimal | None]:
    return {name: getattr(facts, name) for name in SIMILARITY_NUTRIENTS}


def _candidate(product: Product, facts: NutritionFacts, score: Score) -> Candidate:
    return Candidate(
        ean=product.ean,
        grade=cast("Grade", score.grade),  # the query keeps graded scores only
        total=score.total,
        food_categories=tuple(product.food_categories),
        nutrients=_nutrients(facts),
        name=product.name,
        brand=product.brand,
        nova_group=product.nova_group,
    )


__all__ = [
    "SIMILARITY_NUTRIENTS",
    "Alternatives",
    "AlternativesFinder",
    "AlternativesProductNotFoundError",
    "Candidate",
    "better_grades",
    "nutrient_distance",
    "rank_alternatives",
    "similarity_scales",
]
