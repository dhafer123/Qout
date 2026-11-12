"""Data access for import runs. Flushes only; the importer commits."""

import uuid
from collections.abc import Iterable

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.ingestion.models import ImportKind, ImportRun, ImportStatus


class ImportRunRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def add(self, run: ImportRun) -> ImportRun:
        self._session.add(run)
        await self._session.flush()
        return run

    async def get(self, run_id: uuid.UUID) -> ImportRun | None:
        return await self._session.get(ImportRun, run_id)

    async def latest(
        self, kind: ImportKind, source: str, countries: Iterable[str]
    ) -> ImportRun | None:
        """The most recent run of this file for exactly these countries."""
        result = await self._session.scalars(
            select(ImportRun)
            .where(
                ImportRun.kind == kind,
                ImportRun.source == source,
                ImportRun.countries == sorted(countries),
            )
            .order_by(ImportRun.created_at.desc(), ImportRun.id.desc())
            .limit(1)
        )
        return result.one_or_none()

    async def completed_sources(self, kind: ImportKind, countries: Iterable[str]) -> set[str]:
        """Files already imported completely for exactly these countries."""
        result = await self._session.scalars(
            select(ImportRun.source).where(
                ImportRun.kind == kind,
                ImportRun.countries == sorted(countries),
                ImportRun.status == ImportStatus.COMPLETED,
            )
        )
        return set(result.all())
