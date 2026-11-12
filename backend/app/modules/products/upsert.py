"""Store a normalised Open Food Facts product: insert it, or bring a stored copy up to date.

Used by the barcode lookup (new products) and the bulk import (T15). Idempotent: storing
the same record twice changes nothing the second time. Rules:

- Only products that came from OFF are updated. Contributions and manual entries are
  never overwritten, and a product's moderation `status` is never touched.
- A record older than the stored one (`source_modified_at`) is ignored, so an old delta
  file processed late cannot undo newer data.
- Nutrition facts are versioned: a new version is added only when the declared values
  change, or when the category changes (same values, different scoring rules).
- The product is (re)scored when its nutrition or category changed, or when it has no
  score for the current engine yet. OFF's own grade (and whether OFF estimated inputs for
  it) is metadata for the validation report (T16), so a change there is written onto the
  current score in place.

Flushes only; the caller commits, and invalidates the product cache after committing.
"""

from dataclasses import dataclass
from enum import StrEnum

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.ingestion.off_normaliser import NormalizedProduct
from app.modules.products.models import (
    AMOUNT_COLUMNS,
    DataSource,
    NutritionFacts,
    Product,
)
from app.modules.products.repository import (
    DuplicateEanError,
    NutritionFactsRepository,
    ProductRepository,
    ScoreRepository,
)
from app.modules.products.schemas import NutritionFactsCreate, ProductFields
from app.modules.products.scoring import nutrition_input, score_row
from app.modules.scoring import ENGINE_VERSION, NutritionInput, ScoreResult, score

_NUTRITION_FIELDS = (*AMOUNT_COLUMNS, "non_nutritive_sweeteners", "basis", "source")
_PRODUCT_FIELDS = tuple(ProductFields.model_fields)


class UpsertOutcome(StrEnum):
    INSERTED = "inserted"
    UPDATED = "updated"
    UNCHANGED = "unchanged"
    NOT_FROM_OFF = "not_from_off"
    """Stored from another source (contribution, manual): left alone."""
    STALE = "stale"
    """The record is older than the stored data: ignored."""


@dataclass(frozen=True)
class UpsertResult:
    product: Product
    outcome: UpsertOutcome

    @property
    def changed(self) -> bool:
        """Whether anything was written (the cached response is out of date)."""
        return self.outcome in (UpsertOutcome.INSERTED, UpsertOutcome.UPDATED)


class ProductUpserter:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._products = ProductRepository(session)
        self._nutrition = NutritionFactsRepository(session)
        self._scores = ScoreRepository(session)

    async def upsert(self, record: NormalizedProduct) -> UpsertResult:
        ean = record.product.ean
        product = await self._products.get_by_ean(ean)
        if product is None:
            try:
                return await self._insert(record)
            except DuplicateEanError:
                # Stored concurrently by someone else (committed, or we would still wait).
                product = await self._products.get_by_ean(ean)
                if product is None:  # pragma: no cover - deleted in between
                    raise
        return await self._update(product, record)

    # ------------------------------------------------------------ insert

    async def _insert(self, record: NormalizedProduct) -> UpsertResult:
        product = await self._products.add(Product(**record.product.model_dump()))
        facts = None
        if record.nutrition is not None:
            facts = await self._nutrition.add_version(_facts(product, record.nutrition))
        await self._add_score(product, facts, record)
        return UpsertResult(product, UpsertOutcome.INSERTED)

    # ------------------------------------------------------------ update

    async def _update(self, product: Product, record: NormalizedProduct) -> UpsertResult:
        if product.source != DataSource.OPEN_FOOD_FACTS:
            return UpsertResult(product, UpsertOutcome.NOT_FROM_OFF)
        incoming, stored = record.product.source_modified_at, product.source_modified_at
        if incoming is not None and stored is not None and incoming < stored:
            return UpsertResult(product, UpsertOutcome.STALE)

        changed = False
        category_changed = product.category != record.product.category
        changes = {
            name: value
            for name, value in record.product.model_dump(include=set(_PRODUCT_FIELDS)).items()
            if getattr(product, name) != value
        }
        if changes:
            await self._products.update(product, **changes)
            changed = True

        facts = await self._nutrition.latest(product.id)
        new_facts: NutritionFacts | None = None
        if record.nutrition is not None:
            if facts is None or category_changed or _nutrition_differs(facts, record.nutrition):
                new_facts = _facts(product, record.nutrition)
        elif facts is not None and category_changed:
            # No nutrition in the record: stored values are kept (declared data is never
            # deleted), re-versioned so they can be scored with the new category's rules.
            new_facts = _copy(facts)
        if new_facts is not None:
            facts = await self._nutrition.add_version(new_facts)
            changed = True

        current = await self._scores.latest(product.id, engine_version=ENGINE_VERSION)
        facts_id = None if facts is None else facts.id
        if current is None or current.nutrition_facts_id != facts_id or category_changed:
            changed |= await self._add_score(product, facts, record)
        elif (current.off_grade, current.off_grade_estimated) != (
            record.off_grade,
            record.off_grade_estimated,
        ):
            current.off_grade = record.off_grade
            current.off_grade_estimated = record.off_grade_estimated
            await self._session.flush()
            changed = True

        outcome = UpsertOutcome.UPDATED if changed else UpsertOutcome.UNCHANGED
        return UpsertResult(product, outcome)

    # ------------------------------------------------------------ scoring

    async def _add_score(
        self, product: Product, facts: NutritionFacts | None, record: NormalizedProduct
    ) -> bool:
        """Score with the current engine; False if there is nothing to score or the same
        score was stored concurrently."""
        result = score_product(product, facts)
        if result is None:
            return False
        row = score_row(
            result,
            product_id=product.id,
            nutrition_facts_id=None if facts is None else facts.id,
            off_grade=record.off_grade,
            off_grade_estimated=record.off_grade_estimated,
        )
        try:
            async with self._session.begin_nested():
                await self._scores.add(row)
        except IntegrityError:
            return False  # same (nutrition, engine version) stored by a concurrent writer
        return True


def score_product(product: Product, facts: NutritionFacts | None) -> ScoreResult | None:
    """Engine result, or None when the category is unknown (nothing to score with)."""
    if product.category is None:
        return None
    nutrition = NutritionInput() if facts is None else nutrition_input(facts)
    return score(product.category, nutrition)


def _facts(product: Product, nutrition: NutritionFactsCreate) -> NutritionFacts:
    return NutritionFacts(product_id=product.id, **nutrition.model_dump())


def _copy(facts: NutritionFacts) -> NutritionFacts:
    values = {name: getattr(facts, name) for name in _NUTRITION_FIELDS}
    return NutritionFacts(product_id=facts.product_id, **values)


def _nutrition_differs(stored: NutritionFacts, incoming: NutritionFactsCreate) -> bool:
    # Decimal comparison is by value: NUMERIC 1.50 equals a declared 1.5.
    return any(getattr(stored, name) != getattr(incoming, name) for name in _NUTRITION_FIELDS)
