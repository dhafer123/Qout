"""Factory helpers: build valid ORM objects with sensible defaults, override what matters.

    widget = await WidgetFactory.create(session, name="special")

`build()` returns an unsaved instance; `create()` adds it to the session and flushes,
so database defaults (id, timestamps) are populated.
"""

import itertools
from collections.abc import Iterator
from typing import Any, ClassVar

from sqlalchemy.ext.asyncio import AsyncSession

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
