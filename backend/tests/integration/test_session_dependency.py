"""The per-request session dependency, through a real HTTP request."""

from collections.abc import Callable

import httpx
from sqlalchemy import text

from app.api.deps import SessionDep
from app.core.config import Settings
from app.factory import create_app
from tests.integration.conftest import running_client


async def test_route_gets_a_working_session(
    make_settings: Callable[..., Settings], migrated_database: str
) -> None:
    app = create_app(make_settings())
    sessions: list[object] = []

    @app.get("/_test/db")
    async def probe(session: SessionDep) -> dict[str, str | None]:
        sessions.append(session)
        database = await session.scalar(text("SELECT current_database()"))
        return {"database": database}

    async with running_client(app) as client:
        first: httpx.Response = await client.get("/_test/db")
        second = await client.get("/_test/db")

    assert first.status_code == 200
    assert first.json() == {"database": migrated_database.rsplit("/", 1)[1]}
    assert second.status_code == 200
    assert sessions[0] is not sessions[1]  # a fresh session per request
