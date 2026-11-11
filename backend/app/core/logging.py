"""Structured JSON logging on top of the standard library.

Every record becomes one JSON object per line: timestamp, level, logger, message,
the current request id (if any), any `extra={...}` fields, and exception details.
"""

import json
import logging
import sys
from contextvars import ContextVar
from datetime import UTC, datetime
from typing import Any

request_id_var: ContextVar[str | None] = ContextVar("request_id", default=None)

# Attributes every LogRecord has; anything else on a record came from `extra=`.
# `color_message` is uvicorn's ANSI-coloured duplicate of the message.
_STANDARD_ATTRS = frozenset(vars(logging.LogRecord("", logging.INFO, "", 0, "", None, None))) | {
    "message",
    "asctime",
    "color_message",
}

_UVICORN_LOGGERS = ("uvicorn", "uvicorn.error", "uvicorn.access")


class JsonFormatter(logging.Formatter):
    """Render log records as single-line JSON objects."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.fromtimestamp(record.created, tz=UTC).isoformat(
                timespec="milliseconds"
            ),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        request_id = request_id_var.get()
        if request_id is not None:
            payload["request_id"] = request_id
        for key, value in vars(record).items():
            if key not in _STANDARD_ATTRS and not key.startswith("_"):
                payload[key] = value
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        if record.stack_info:
            payload["stack"] = self.formatStack(record.stack_info)
        return json.dumps(payload, default=str, ensure_ascii=False)


class _JsonStreamHandler(logging.StreamHandler):  # type: ignore[type-arg]
    """Marker type so `configure_logging` can replace its own handler idempotently."""


def configure_logging(level: str = "INFO") -> None:
    """Send all logs (app and uvicorn) to stdout as JSON. Safe to call repeatedly."""
    root = logging.getLogger()
    for handler in [h for h in root.handlers if isinstance(h, _JsonStreamHandler)]:
        root.removeHandler(handler)

    handler = _JsonStreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    root.addHandler(handler)
    root.setLevel(level)

    # Route uvicorn's loggers through the root handler instead of its own formatters.
    for name in _UVICORN_LOGGERS:
        uvicorn_logger = logging.getLogger(name)
        uvicorn_logger.handlers.clear()
        uvicorn_logger.propagate = True
    # The request-id middleware writes the access log (with request id and duration).
    logging.getLogger("uvicorn.access").disabled = True
