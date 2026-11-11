"""IdTimestampMixin behaviour against real Postgres."""

import uuid
from datetime import timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from tests.factories import WidgetFactory


async def test_insert_populates_id_and_timestamps(db_session: AsyncSession) -> None:
    widget = await WidgetFactory.create(db_session)

    assert isinstance(widget.id, uuid.UUID)
    assert widget.id.version == 4
    assert widget.created_at.utcoffset() == timedelta(0)
    assert widget.updated_at == widget.created_at


async def test_ids_are_unique(db_session: AsyncSession) -> None:
    widgets = [await WidgetFactory.create(db_session) for _ in range(5)]

    assert len({w.id for w in widgets}) == 5


async def test_update_moves_updated_at_forward_only(db_session: AsyncSession) -> None:
    widget = await WidgetFactory.create(db_session)
    created_at = widget.created_at

    widget.name = "renamed"
    await db_session.flush()

    assert widget.created_at == created_at
    assert widget.updated_at > created_at


async def test_timestamps_survive_commit_without_reload(db_session: AsyncSession) -> None:
    widget = await WidgetFactory.create(db_session)
    await db_session.commit()

    # expire_on_commit=False: no lazy load (which would fail in async code).
    assert widget.created_at is not None
