"""Products router with a fake lookup service: status codes, headers, OpenAPI."""

from collections.abc import AsyncIterator
from datetime import UTC, datetime

import httpx
import pytest
from fastapi import FastAPI

from app.api.products import RETRY_AFTER_SECONDS, get_product_lookup
from app.core.config import Settings
from app.factory import create_app
from app.modules.products.ean import normalize_ean
from app.modules.products.lookup import ProductNotFoundError, ProductSourceUnavailableError
from app.modules.products.models import DataSource, ProductStatus
from app.modules.products.schemas import ProductDetail

KNOWN = "3017620422003"
UNKNOWN = "6190000000019"
OFF_DOWN = "6194039501011"


class FakeLookup:
    async def lookup(self, code: str) -> ProductDetail:
        ean = normalize_ean(code)
        if ean == UNKNOWN:
            raise ProductNotFoundError(ean)
        if ean == OFF_DOWN:
            raise ProductSourceUnavailableError(ean)
        return ProductDetail(
            ean=ean,
            name="Nutella",
            brand=None,
            image_url=None,
            category=None,
            source=DataSource.OPEN_FOOD_FACTS,
            status=ProductStatus.UNVERIFIED,
            quality_flag=None,
            nova_group=None,
            additives=[],
            nutrition=None,
            score=None,
            updated_at=datetime(2026, 11, 12, tzinfo=UTC),
        )


@pytest.fixture
def app() -> FastAPI:
    settings = Settings(
        _env_file=None,
        database_url="postgresql+asyncpg://u:p@localhost:1/x",  # type: ignore[arg-type]
        redis_url="redis://localhost:1/0",  # type: ignore[arg-type]
    )
    app = create_app(settings)
    app.dependency_overrides[get_product_lookup] = FakeLookup
    return app


@pytest.fixture
async def client(app: FastAPI) -> AsyncIterator[httpx.AsyncClient]:
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


async def test_found(client: httpx.AsyncClient) -> None:
    response = await client.get(f"/v1/products/{KNOWN}")
    assert response.status_code == 200
    assert response.json()["ean"] == KNOWN


@pytest.mark.parametrize(
    ("code", "reason"),
    [
        ("3017620422004", "wrong check digit"),
        ("12345", "must have 8, 12, 13 or 14 digits"),
        ("30176204220ab", "only digits allowed"),
    ],
)
async def test_invalid_barcode_is_422(client: httpx.AsyncClient, code: str, reason: str) -> None:
    response = await client.get(f"/v1/products/{code}")
    assert response.status_code == 422
    assert reason in response.json()["detail"]


async def test_unknown_is_404(client: httpx.AsyncClient) -> None:
    response = await client.get(f"/v1/products/{UNKNOWN}")
    assert response.status_code == 404
    assert response.json() == {"detail": f"no product with barcode {UNKNOWN}"}


async def test_source_unavailable_is_503_with_retry_after(client: httpx.AsyncClient) -> None:
    response = await client.get(f"/v1/products/{OFF_DOWN}")
    assert response.status_code == 503
    assert response.headers["Retry-After"] == str(RETRY_AFTER_SECONDS)
    assert "unavailable" in response.json()["detail"]


async def test_endpoint_is_documented(client: httpx.AsyncClient) -> None:
    spec = (await client.get("/openapi.json")).json()
    operation = spec["paths"]["/v1/products/{ean}"]["get"]
    assert set(operation["responses"]) == {"200", "404", "422", "503"}
    assert operation["responses"]["200"]["content"]["application/json"]["schema"] == {
        "$ref": "#/components/schemas/ProductDetail"
    }
    assert operation["responses"]["503"]["content"]["application/json"]["schema"] == {
        "$ref": "#/components/schemas/ErrorResponse"
    }
