"""Request-id propagation and access logging, as plain ASGI middleware.

- Reuses a well-formed incoming `X-Request-ID`, otherwise generates one.
- Makes it available to log records for the duration of the request.
- Echoes it in the response `X-Request-ID` header.
- Logs one access line per HTTP request (method, path, status, duration).
"""

import logging
import re
import time
import uuid

from starlette.datastructures import MutableHeaders
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.core.logging import request_id_var

REQUEST_ID_HEADER = "X-Request-ID"
_REQUEST_ID_HEADER_RAW = REQUEST_ID_HEADER.lower().encode("latin-1")
_VALID_REQUEST_ID = re.compile(r"[A-Za-z0-9._-]{1,128}")

access_logger = logging.getLogger("app.access")


def new_request_id() -> str:
    return uuid.uuid4().hex


def incoming_request_id(scope: Scope) -> str | None:
    """Return the client-supplied request id if it is safe to reuse."""
    for name, value in scope.get("headers", ()):
        if name == _REQUEST_ID_HEADER_RAW:
            candidate: str = value.decode("latin-1")
            return candidate if _VALID_REQUEST_ID.fullmatch(candidate) else None
    return None


class RequestIdMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        request_id = incoming_request_id(scope) or new_request_id()
        token = request_id_var.set(request_id)
        status_code = 500  # reported if the app raises before sending a response
        started = time.perf_counter()

        async def send_with_request_id(message: Message) -> None:
            nonlocal status_code
            if message["type"] == "http.response.start":
                status_code = message["status"]
                MutableHeaders(scope=message)[REQUEST_ID_HEADER] = request_id
            await send(message)

        try:
            await self.app(scope, receive, send_with_request_id)
        finally:
            access_logger.info(
                "%s %s %d",
                scope["method"],
                scope["path"],
                status_code,
                extra={
                    "http_method": scope["method"],
                    "http_path": scope["path"],
                    "http_status": status_code,
                    "duration_ms": round((time.perf_counter() - started) * 1000, 2),
                },
            )
            request_id_var.reset(token)
