import json
import logging
import sys
from collections.abc import Iterator
from typing import Any

import pytest

from app.core.logging import JsonFormatter, configure_logging, request_id_var


def make_record(
    msg: str = "hello %s", args: tuple[Any, ...] = ("world",), **extra: Any
) -> logging.LogRecord:
    record = logging.LogRecord(
        name="qout.test",
        level=logging.WARNING,
        pathname=__file__,
        lineno=1,
        msg=msg,
        args=args,
        exc_info=None,
    )
    for key, value in extra.items():
        setattr(record, key, value)
    return record


def render(record: logging.LogRecord) -> dict[str, Any]:
    output = JsonFormatter().format(record)
    assert "\n" not in output
    parsed: dict[str, Any] = json.loads(output)
    return parsed


def test_formats_core_fields_as_json() -> None:
    payload = render(make_record())

    assert payload["message"] == "hello world"
    assert payload["level"] == "WARNING"
    assert payload["logger"] == "qout.test"
    assert payload["timestamp"].endswith("+00:00")
    assert "request_id" not in payload


def test_includes_extra_fields_and_stringifies_unknown_types() -> None:
    class Opaque:
        def __str__(self) -> str:
            return "opaque!"

    payload = render(make_record(ean="3017620422003", count=3, thing=Opaque(), _private=1))

    assert payload["ean"] == "3017620422003"
    assert payload["count"] == 3
    assert payload["thing"] == "opaque!"
    assert "_private" not in payload
    assert "pathname" not in payload


def test_drops_uvicorn_color_message() -> None:
    payload = render(make_record(color_message="\x1b[36mhello\x1b[0m"))

    assert "color_message" not in payload


def test_includes_current_request_id() -> None:
    token = request_id_var.set("req-123")
    try:
        payload = render(make_record())
    finally:
        request_id_var.reset(token)

    assert payload["request_id"] == "req-123"


def test_renders_exception_and_stack_info() -> None:
    try:
        raise ValueError("boom")
    except ValueError:
        record = make_record()
        record.exc_info = sys.exc_info()
    record.stack_info = "Stack (most recent call last):\n  frame"

    payload = render(record)

    assert "ValueError: boom" in payload["exception"]
    assert "frame" in payload["stack"]


def test_keeps_non_ascii_text_readable() -> None:
    payload = render(make_record("قوت %s", ("é",)))

    assert payload["message"] == "قوت é"


@pytest.fixture
def restore_logging() -> Iterator[None]:
    root = logging.getLogger()
    saved_handlers, saved_level = list(root.handlers), root.level
    access = logging.getLogger("uvicorn.access")
    saved_disabled = access.disabled
    yield
    root.handlers[:] = saved_handlers
    root.setLevel(saved_level)
    access.disabled = saved_disabled


@pytest.mark.usefixtures("restore_logging")
def test_configure_logging_is_idempotent_and_keeps_foreign_handlers(
    capsys: pytest.CaptureFixture[str],
) -> None:
    foreign = logging.NullHandler()
    logging.getLogger().addHandler(foreign)

    configure_logging("DEBUG")
    configure_logging("DEBUG")

    root = logging.getLogger()
    json_handlers = [h for h in root.handlers if isinstance(h.formatter, JsonFormatter)]
    assert len(json_handlers) == 1
    assert foreign in root.handlers
    assert root.level == logging.DEBUG
    assert logging.getLogger("uvicorn.access").disabled
    assert logging.getLogger("uvicorn.error").propagate

    logging.getLogger("qout.test").info("configured", extra={"step": 1})
    line = capsys.readouterr().out.strip().splitlines()[-1]
    assert json.loads(line) | {"timestamp": None} == {
        "timestamp": None,
        "level": "INFO",
        "logger": "qout.test",
        "message": "configured",
        "step": 1,
    }
