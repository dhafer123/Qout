"""Each test gets a clean database: everything written in a test is rolled back."""

import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession

from tests.factories import WidgetFactory
from tests.models import Widget

# Shared between the two ordered tests below (pytest runs a module top to bottom).
_created_in_first_test: list[uuid.UUID] = []


async def count_widgets(session: AsyncSession) -> int:
    return (await session.scalar(select(func.count()).select_from(Widget))) or 0


async def test_1_committed_writes_are_visible_within_the_test(db_session: AsyncSession) -> None:
    widget = await WidgetFactory.create(db_session)
    await db_session.commit()

    assert await count_widgets(db_session) == 1
    _created_in_first_test.append(widget.id)


async def test_2_next_test_starts_clean(db_session: AsyncSession) -> None:
    assert _created_in_first_test, "test_1 must run first"

    assert await count_widgets(db_session) == 0
    assert await db_session.get(Widget, _created_in_first_test[0]) is None


async def test_writes_are_invisible_to_other_connections(
    db_session: AsyncSession, db_engine: AsyncEngine
) -> None:
    await WidgetFactory.create(db_session)
    await db_session.commit()

    async with AsyncSession(db_engine) as other:
        assert await count_widgets(other) == 0


async def test_rollback_inside_a_test_works(db_session: AsyncSession) -> None:
    await WidgetFactory.create(db_session, name="kept")
    await db_session.commit()
    await WidgetFactory.create(db_session, name="discarded")
    await db_session.rollback()

    names = (await db_session.scalars(select(Widget.name))).all()
    assert names == ["kept"]
