import logging

import httpx
import pytest
from starlette.applications import Starlette
from starlette.requests import Request
from starlette.responses import JSONResponse
from starlette.routing import Route

from app.core.logging import request_id_var
from app.core.request_id import REQUEST_ID_HEADER, RequestIdMiddleware

_HEX32 = r"[0-9a-f]{32}"


async def echo_request_id(request: Request) -> JSONResponse:
    logging.getLogger("qout.test").info("inside handler")
    return JSONResponse({"request_id": request_id_var.get()}, status_code=201)


async def explode(request: Request) -> JSONResponse:
    raise RuntimeError("boom")


def make_client() -> httpx.AsyncClient:
    app = Starlette(routes=[Route("/echo", echo_request_id), Route("/explode", explode)])
    wrapped = RequestIdMiddleware(app)
    transport = httpx.ASGITransport(app=wrapped, raise_app_exceptions=True)
    return httpx.AsyncClient(transport=transport, base_url="http://test")


async def test_generates_request_id_when_absent() -> None:
    async with make_client() as client:
        response = await client.get("/echo")

    request_id = response.headers[REQUEST_ID_HEADER]
    assert len(request_id) == 32
    assert response.json() == {"request_id": request_id}
    assert request_id_var.get() is None  # reset after the request


async def test_generated_ids_are_unique() -> None:
    async with make_client() as client:
        ids = {(await client.get("/echo")).headers[REQUEST_ID_HEADER] for _ in range(5)}

    assert len(ids) == 5


async def test_reuses_valid_incoming_request_id() -> None:
    async with make_client() as client:
        response = await client.get("/echo", headers={REQUEST_ID_HEADER: "abc-123_X.y"})

    assert response.headers[REQUEST_ID_HEADER] == "abc-123_X.y"
    assert response.json() == {"request_id": "abc-123_X.y"}


@pytest.mark.parametrize(
    "bad_value",
    ["", "has space", "new\\nline", 'quote"', "x" * 129, "ünïcode"],
)
async def test_replaces_unsafe_incoming_request_id(bad_value: str) -> None:
    async with make_client() as client:
        response = await client.get(
            "/echo", headers=[(REQUEST_ID_HEADER, bad_value.encode("utf-8"))]
        )

    request_id = response.headers[REQUEST_ID_HEADER]
    assert request_id != bad_value
    assert len(request_id) == 32


async def test_logs_access_line_with_request_id(caplog: pytest.LogCaptureFixture) -> None:
    caplog.set_level(logging.INFO)

    async with make_client() as client:
        await client.get("/echo", headers={REQUEST_ID_HEADER: "trace-me"})

    access = [r for r in caplog.records if r.name == "app.access"]
    assert len(access) == 1
    record = access[0]
    assert record.getMessage() == "GET /echo 201"
    assert record.__dict__["http_status"] == 201
    assert record.__dict__["http_path"] == "/echo"
    assert record.__dict__["duration_ms"] >= 0


async def test_logs_status_500_when_app_raises(caplog: pytest.LogCaptureFixture) -> None:
    caplog.set_level(logging.INFO)

    async with make_client() as client:
        with pytest.raises(RuntimeError, match="boom"):
            await client.get("/explode")

    access = [r for r in caplog.records if r.name == "app.access"]
    assert access[0].__dict__["http_status"] == 500
    assert request_id_var.get() is None


async def test_passes_through_non_http_scopes() -> None:
    seen: list[str] = []

    async def inner(scope: dict[str, object], receive: object, send: object) -> None:
        seen.append(str(scope["type"]))

    middleware = RequestIdMiddleware(inner)  # type: ignore[arg-type]

    async def noop_receive() -> dict[str, object]:
        return {}

    async def noop_send(message: dict[str, object]) -> None:
        return None

    await middleware({"type": "lifespan"}, noop_receive, noop_send)

    assert seen == ["lifespan"]
