"""Factory helpers: build valid ORM objects with sensible defaults, override what matters.

    widget = await WidgetFactory.create(session, name="special")

`build()` returns an unsaved instance; `create()` adds it to the session and flushes,
so database defaults (id, timestamps) are populated.
"""

import itertools
from collections.abc import Iterator
from decimal import Decimal
from typing import Any, ClassVar

from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.products.models import (
    DataSource,
    NutritionBasis,
    NutritionFacts,
    Product,
    ScanEvent,
    ScanOutcome,
    Score,
)
from app.modules.scoring import ENGINE_VERSION, Grade
from tests.models import Widget


class Factory[T]:
    model: ClassVar[type[Any]]
    _sequence: ClassVar[Iterator[int]]

    def __init_subclass__(cls, **kwargs: Any) -> None:
        super().__init_subclass__(**kwargs)
        cls._sequence = itertools.count(1)

    @classmethod
    def next_n(cls) -> int:
        """A per-factory counter for unique values (names, EANs, emails...)."""
        return next(cls._sequence)

    @classmethod
    def defaults(cls) -> dict[str, Any]:
        return {}

    @classmethod
    def build(cls, **overrides: Any) -> T:
        unknown = set(overrides) - set(cls.model.__mapper__.attrs.keys())
        if unknown:
            raise TypeError(f"{cls.__name__}: unknown fields {sorted(unknown)}")
        instance: T = cls.model(**(cls.defaults() | overrides))
        return instance

    @classmethod
    async def create(cls, session: AsyncSession, **overrides: Any) -> T:
        instance = cls.build(**overrides)
        session.add(instance)
        await session.flush()
        return instance


class WidgetFactory(Factory[Widget]):
    model = Widget

    @classmethod
    def defaults(cls) -> dict[str, Any]:
        return {"name": f"widget-{cls.next_n()}"}


class ProductFactory(Factory[Product]):
    model = Product

    @classmethod
    def defaults(cls) -> dict[str, Any]:
        n = cls.next_n()
        return {
            "ean": f"{2000000000000 + n}",  # 13 digits, restricted-use prefix 2
            "name": f"Product {n}",
            "source": DataSource.OPEN_FOOD_FACTS,
        }


class NutritionFactsFactory(Factory[NutritionFacts]):
    """Pass `product_id`. Defaults: a complete general-food declaration (all zeros)."""

    model = NutritionFacts

    @classmethod
    def defaults(cls) -> dict[str, Any]:
        return {
            "version": 1,
            "basis": NutritionBasis.PER_100G,
            "source": DataSource.OPEN_FOOD_FACTS,
            "energy_kj": Decimal(0),
            "sugars_g": Decimal(0),
            "saturated_fat_g": Decimal(0),
            "salt_g": Decimal(0),
            "fibre_g": Decimal(0),
            "protein_g": Decimal(0),
            "fvl_percent": Decimal(0),
        }


class ScoreFactory(Factory[Score]):
    """Pass `product_id` (and usually `nutrition_facts_id`)."""

    model = Score

    @classmethod
    def defaults(cls) -> dict[str, Any]:
        return {
            "engine_version": ENGINE_VERSION,
            "grade": Grade.B,
            "total": 1,
            "breakdown": {"grade": "B"},
        }


class ScanEventFactory(Factory[ScanEvent]):
    model = ScanEvent

    @classmethod
    def defaults(cls) -> dict[str, Any]:
        return {"ean": f"{3000000000000 + cls.next_n()}", "outcome": ScanOutcome.NOT_FOUND}
