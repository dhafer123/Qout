"""Alembic migrations against the real test database.

These tests are synchronous on purpose: Alembic's env.py runs its own event loop.
"""

import asyncio

from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.runtime.migration import MigrationContext
from alembic.script import ScriptDirectory
from sqlalchemy import Connection, inspect
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.pool import NullPool

from app.models import Base
from tests.integration.conftest import alembic_config


def _inspect_db(database_url: str) -> tuple[str | None, set[str], list[object]]:
    """Return (current revision, public tables, model-vs-schema differences)."""

    def inspect_sync(connection: Connection) -> tuple[str | None, set[str], list[object]]:
        context = MigrationContext.configure(connection, opts={"compare_type": True})
        tables = set(inspect(connection).get_table_names(schema="public"))
        return context.get_current_revision(), tables, compare_metadata(context, Base.metadata)

    async def run() -> tuple[str | None, set[str], list[object]]:
        engine = create_async_engine(database_url, poolclass=NullPool)
        try:
            async with engine.connect() as connection:
                return await connection.run_sync(inspect_sync)
        finally:
            await engine.dispose()

    return asyncio.run(run())


def test_migrations_round_trip(migrated_database: str) -> None:
    config = alembic_config(migrated_database)
    head = ScriptDirectory.from_config(config).get_current_head()

    command.downgrade(config, "base")
    revision, tables, _ = _inspect_db(migrated_database)
    assert revision is None
    assert tables - {"alembic_version"} == set()

    command.upgrade(config, "head")
    revision, _, _ = _inspect_db(migrated_database)
    assert revision == head


def test_each_migration_downgrades_and_reapplies(migrated_database: str) -> None:
    """Stairway: for every revision, upgrade to it, step back once, upgrade again."""
    config = alembic_config(migrated_database)
    revisions = list(reversed(list(ScriptDirectory.from_config(config).walk_revisions())))
    assert revisions, "expected at least the baseline revision"

    command.downgrade(config, "base")
    try:
        for script in revisions:
            command.upgrade(config, script.revision)
            command.downgrade(config, script.down_revision or "base")
            command.upgrade(config, script.revision)
            assert _inspect_db(migrated_database)[0] == script.revision
    finally:
        command.upgrade(config, "head")


def test_models_match_migrations(migrated_database: str) -> None:
    """Drift guard: changing a model without a migration fails here."""
    _, _, differences = _inspect_db(migrated_database)

    assert differences == []
