"""`refresh-off`: products stored before the serving and allergens were imported (T40)
are fetched again from OFF once (real Postgres and Redis; OFF faked or mocked)."""

import json
import re
from collections.abc import AsyncIterator, Callable
from pathlib import Path
from typing import Any

import httpx
import pytest
import respx
from arq import Retry
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.core.config import Settings
from app.modules.ingestion.off_client import OffUnavailableError
from app.modules.products.cache import ProductCache
from app.modules.products.models import DataSource, Product
from app.worker import cli, jobs
from tests.factories import ProductFactory

Sessions = async_sessionmaker[AsyncSession]
FIXTURES = Path(__file__).resolve().parents[2] / "fixtures" / "off"
OFF_BASE = "https://off.test"

BISCUITS = "6194002510064"  # the recorded fixture with a serving and allergens
GONE = "6190000000019"
BROKEN = "6191234567897"


def recorded() -> dict[str, Any]:
    data: dict[str, Any] = json.loads(
        (FIXTURES / "general-tunisian-biscuits-serving-allergens.json").read_text("utf-8")
    )
    return data["product"]


class FakeOff:
    """Serves the recorded biscuits; `GONE` is unknown to OFF, `BROKEN` fails."""

    def __init__(self) -> None:
        self.asked: list[str] = []

    async def get_product(self, ean: str) -> dict[str, Any] | None:
        self.asked.append(ean)
        if ean == BROKEN:
            raise OffUnavailableError("OFF is down")
        return recorded() if ean == BISCUITS else None


@pytest.fixture
async def ctx(make_settings: Callable[..., Settings]) -> AsyncIterator[jobs.Context]:
    context: jobs.Context = {"settings": make_settings(off_max_retries=0)}
    await jobs.startup(context)
    yield context
    await jobs.shutdown(context)


@pytest.fixture
async def import_lock(db_engine: AsyncEngine) -> AsyncIterator[None]:
    """A bulk import holds the lock the backfill shares."""
    async with db_engine.connect() as connection:
        await connection.execute(text("SELECT pg_advisory_lock(:k)"), {"k": jobs.IMPORT_LOCK_KEY})
        yield
        await connection.execute(text("SELECT pg_advisory_unlock(:k)"), {"k": jobs.IMPORT_LOCK_KEY})


async def make(sessions: Sessions, ean: str, **values: Any) -> None:
    async with sessions() as session:
        await ProductFactory.create(session, ean=ean, **values)
        await session.commit()


async def stored(sessions: Sessions, ean: str) -> Product:
    async with sessions() as session:
        product = await session.scalar(select(Product).where(Product.ean == ean))
        assert product is not None
        return product


async def test_fills_in_what_older_products_miss(
    ctx: jobs.Context, sessions: Sessions, cache: ProductCache
) -> None:
    await make(sessions, BISCUITS, name="Fourré")
    await make(sessions, GONE)
    await make(sessions, BROKEN)
    await make(sessions, "6194017503778", allergens=[], traces=[])  # imported after T40
    await make(sessions, "6111018501480", source=DataSource.CONTRIBUTION)
    await cache.set_not_found(BISCUITS)  # anything cached for it must go
    fake = FakeOff()
    ctx["off_source"] = fake

    stats = await jobs.run_refresh_off(ctx)

    assert sorted(fake.asked) == sorted([BISCUITS, GONE, BROKEN])
    assert (stats.checked, stats.updated, stats.unchanged, stats.missing, stats.failed) == (
        3,
        1,
        0,
        1,
        1,
    )
    biscuits = await stored(sessions, BISCUITS)
    assert (biscuits.allergens, biscuits.traces) == (["gluten", "soybeans", "milk"], ["nuts"])
    assert biscuits.serving_size == "21.7g"
    assert await cache.get(BISCUITS) is None
    assert (await stored(sessions, GONE)).allergens is None
    assert (await stored(sessions, "6111018501480")).allergens is None  # contribution

    # A second run asks only for what is still missing.
    fake.asked.clear()
    again = await jobs.run_refresh_off(ctx)
    assert sorted(fake.asked) == sorted([GONE, BROKEN])
    assert again.updated == 0


async def test_queued_job_waits_for_a_running_import(ctx: jobs.Context, import_lock: None) -> None:
    ctx["off_source"] = FakeOff()
    with pytest.raises(Retry):
        await jobs.refresh_off_products(ctx)


async def test_command_line_uses_the_real_off_client(
    make_settings: Callable[..., Settings],
    sessions: Sessions,
    capsys: pytest.CaptureFixture[str],
) -> None:
    await make(sessions, BISCUITS)
    product = re.compile(r"https://off\.test/api/v2/product/(\d+)\.json")
    with respx.mock(assert_all_called=True) as router:
        route = router.get(url__regex=product.pattern).mock(
            return_value=httpx.Response(
                200, json={"code": BISCUITS, "status": 1, "product": recorded()}
            )
        )
        code = await cli.amain(
            ["run", "refresh-off"],
            settings=make_settings(off_base_url=OFF_BASE, off_max_retries=0),
        )

    assert code == 0
    assert "allergens_tags" in route.calls.last.request.url.params["fields"]
    assert json.loads(capsys.readouterr().out.strip().splitlines()[-1])["updated"] == 1
    assert (await stored(sessions, BISCUITS)).allergens == ["gluten", "soybeans", "milk"]


async def test_a_record_that_cannot_be_stored_is_counted(
    ctx: jobs.Context, sessions: Sessions, monkeypatch: pytest.MonkeyPatch
) -> None:
    await make(sessions, BISCUITS)
    ctx["off_source"] = FakeOff()

    async def refuse(self: object, record: object) -> None:
        raise RuntimeError("database refused it")

    monkeypatch.setattr("app.modules.ingestion.refresh.ProductUpserter.upsert", refuse)
    stats = await jobs.run_refresh_off(ctx)

    assert (stats.checked, stats.failed, stats.updated) == (1, 1, 0)
    assert (await stored(sessions, BISCUITS)).allergens is None
