"""The Anthropic adapter of the LLM fallback parser, on a mocked transport (no network):
what is sent, how the reply is read, and how SDK errors are mapped."""

import json
from collections.abc import Callable
from typing import Any

import httpx2
import pytest
from anthropic import AsyncAnthropic, DefaultAsyncHttpxClient
from pydantic import SecretStr

from app.core.config import Settings
from app.modules.contributions.llm_client import FALLBACK_BETA, MAX_TOKENS, AnthropicLabelLlm
from app.modules.contributions.llm_parser import (
    OUTPUT_SCHEMA,
    SYSTEM_PROMPT,
    LlmTimeoutError,
    LlmUnavailableError,
)

OCR = "Valeurs nutritionnelles pour 100 g\nSel 1,2 g"
ANSWER = '{"table_found": true}'
Handler = Callable[[httpx2.Request], httpx2.Response]


def message(**changes: Any) -> dict[str, Any]:
    body: dict[str, Any] = {
        "id": "msg_test",
        "type": "message",
        "role": "assistant",
        "model": "claude-opus-5-5",
        "content": [
            {"type": "thinking", "thinking": "", "signature": "sig"},
            {"type": "text", "text": ANSWER},
        ],
        "stop_reason": "end_turn",
        "stop_sequence": None,
        "usage": {"input_tokens": 900, "output_tokens": 120},
    }
    return body | changes


def llm_with(handler: Handler, *, effort: Any = "medium") -> AnthropicLabelLlm:
    client = AsyncAnthropic(
        api_key="sk-test",
        max_retries=0,
        http_client=DefaultAsyncHttpxClient(transport=httpx2.MockTransport(handler)),
    )
    return AnthropicLabelLlm(client, model="claude-opus-5-5", effort=effort)


async def test_request_holds_only_the_prompt_and_the_ocr_text() -> None:
    requests: list[httpx2.Request] = []

    def handler(request: httpx2.Request) -> httpx2.Response:
        requests.append(request)
        return httpx2.Response(200, json=message())

    llm = llm_with(handler, effort="low")

    reply = await llm.read(OCR)

    (request,) = requests
    assert request.url.path == "/v1/messages"
    assert request.headers["authorization"] == "Bearer sk-test"
    assert FALLBACK_BETA in request.headers["anthropic-beta"]
    body = json.loads(request.content)
    assert body == {
        "model": "claude-opus-5-5",
        "max_tokens": MAX_TOKENS,
        "system": SYSTEM_PROMPT,
        "messages": [{"role": "user", "content": f"<ocr_text>\n{OCR}\n</ocr_text>"}],
        "output_config": {
            "effort": "low",
            "format": {"type": "json_schema", "schema": OUTPUT_SCHEMA},
        },
        "fallbacks": "default",
    }
    assert (reply.text, reply.stop_reason, reply.model) == (ANSWER, "end_turn", "claude-opus-5-5")
    assert llm.model == "claude-opus-5-5"
    await llm.aclose()


async def test_reply_from_the_fallback_model_and_without_text() -> None:
    def handler(request: httpx2.Request) -> httpx2.Response:
        return httpx2.Response(
            200, json=message(model="claude-opus-4-8", content=[], stop_reason="refusal")
        )

    reply = await llm_with(handler).read(OCR)

    assert (reply.text, reply.stop_reason, reply.model) == (None, "refusal", "claude-opus-4-8")


def _status(code: int) -> Handler:
    def handler(request: httpx2.Request) -> httpx2.Response:
        return httpx2.Response(
            code, json={"type": "error", "error": {"type": "api_error", "message": "nope"}}
        )

    return handler


def _raise(error: Exception) -> Handler:
    def handler(request: httpx2.Request) -> httpx2.Response:
        raise error

    return handler


@pytest.mark.parametrize(
    ("handler", "expected"),
    [
        (_status(401), LlmUnavailableError),
        (_status(429), LlmUnavailableError),
        (_status(529), LlmUnavailableError),
        (_raise(httpx2.ConnectError("refused")), LlmUnavailableError),
        (_raise(httpx2.ReadTimeout("slow")), LlmTimeoutError),
        (lambda _: httpx2.Response(200, content=b"<html>"), LlmUnavailableError),
    ],
    ids=["401", "429", "529", "connection", "timeout", "not-json"],
)
async def test_sdk_errors_are_mapped(handler: Handler, expected: type[Exception]) -> None:
    with pytest.raises(expected):
        await llm_with(handler).read(OCR)


def test_from_settings() -> None:
    settings = Settings(
        _env_file=None,  # type: ignore[call-arg]
        database_url="postgresql+asyncpg://u:p@db:5432/q",  # type: ignore[arg-type]
        redis_url="redis://cache:6379/0",  # type: ignore[arg-type]
        llm_parser_enabled=True,
        llm_api_key=SecretStr("sk-from-settings"),
        llm_model="claude-haiku-5-5",
        llm_effort="high",
        llm_timeout_seconds=12,
    )

    llm = AnthropicLabelLlm.from_settings(settings)

    assert llm.model == "claude-haiku-5-5"
    client = llm._client
    assert (client.api_key, client.timeout, client.max_retries) == ("sk-from-settings", 12, 2)
