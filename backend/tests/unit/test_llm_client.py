"""The Gemini adapter of the LLM fallback parser, with the HTTP calls mocked by respx (no
network): what is sent, how the reply is read, and how SDK errors are mapped."""

import json
from collections.abc import AsyncIterator, Callable, Iterator
from typing import Any

import httpx
import pytest
import respx
from google import genai
from google.genai import types
from pydantic import SecretStr

from app.core.config import Settings
from app.modules.contributions.llm_client import MAX_OUTPUT_TOKENS, GeminiLabelLlm
from app.modules.contributions.llm_parser import (
    OUTPUT_SCHEMA,
    SYSTEM_PROMPT,
    LlmFinish,
    LlmTimeoutError,
    LlmUnavailableError,
)

MODEL = "gemini-3.8-flash"
HOST = "https://generativelanguage.googleapis.com"


def url(model: str = MODEL) -> str:
    """The generateContent endpoint of `model`, any API version (`v1`, `v1beta`)."""
    return rf"{HOST}/v1\w*/models/{model.replace('.', r'\.')}:generateContent"


OCR = "Valeurs nutritionnelles pour 100 g\nSel 1,2 g"
ANSWER = '{"table_found": true}'


def response(finish: str | None = "STOP", text: str | None = ANSWER, **extra: Any) -> Any:
    candidate: dict[str, Any] = {}
    if text is not None:
        candidate["content"] = {"role": "model", "parts": [{"text": text}]}
    if finish is not None:
        candidate["finishReason"] = finish
    body: dict[str, Any] = {
        "candidates": [candidate],
        "modelVersion": f"{MODEL}-001",
        "usageMetadata": {"promptTokenCount": 900, "candidatesTokenCount": 120},
    }
    return body | extra


def settings(**values: Any) -> Settings:
    return Settings(
        _env_file=None,  # type: ignore[call-arg]
        database_url="postgresql+asyncpg://u:p@db:5432/q",  # type: ignore[arg-type]
        redis_url="redis://cache:6379/0",  # type: ignore[arg-type]
        **({"llm_api_key": SecretStr("test-gemini-key"), "llm_model": MODEL} | values),
    )


@pytest.fixture
def gemini() -> Iterator[respx.MockRouter]:
    with respx.mock(assert_all_called=False) as router:
        yield router


@pytest.fixture
async def llm() -> AsyncIterator[GeminiLabelLlm]:
    """No retries, so error tests answer at once."""
    http = httpx.AsyncClient()
    client = genai.Client(
        api_key="test-gemini-key",
        http_options=types.HttpOptions(
            retry_options=types.HttpRetryOptions(attempts=1), httpx_async_client=http
        ),
    )
    reader = GeminiLabelLlm(client, http, model=MODEL)
    yield reader
    await reader.aclose()


async def test_request_holds_only_the_instructions_and_the_ocr_text(
    gemini: respx.MockRouter, llm: GeminiLabelLlm
) -> None:
    route = gemini.post(url__regex=url()).respond(200, json=response())

    reply = await llm.read(OCR)

    request = route.calls.last.request
    assert request.headers["x-goog-api-key"] == "test-gemini-key"
    body = json.loads(request.content)
    assert body["contents"] == [
        {"role": "user", "parts": [{"text": f"<ocr_text>\n{OCR}\n</ocr_text>"}]}
    ]
    assert body["systemInstruction"]["parts"] == [{"text": SYSTEM_PROMPT}]
    assert body["generationConfig"] == {
        "responseMimeType": "application/json",
        "responseJsonSchema": OUTPUT_SCHEMA,
        "maxOutputTokens": MAX_OUTPUT_TOKENS,
    }
    assert set(body) == {"contents", "systemInstruction", "generationConfig"}
    assert (reply.text, reply.finish, reply.model) == (ANSWER, LlmFinish.COMPLETE, f"{MODEL}-001")
    assert llm.model == MODEL


@pytest.mark.parametrize(
    ("body", "finish", "text"),
    [
        (response("MAX_TOKENS", '{"table_found": tr'), LlmFinish.TRUNCATED, '{"table_found": tr'),
        (response("SAFETY", None), LlmFinish.REFUSED, None),
        (response("RECITATION", None), LlmFinish.REFUSED, None),
        (response("MALFORMED_FUNCTION_CALL", None), LlmFinish.OTHER, None),
        (response(None), LlmFinish.OTHER, ANSWER),
        ({"promptFeedback": {"blockReason": "SAFETY"}}, LlmFinish.REFUSED, None),
        ({"candidates": []}, LlmFinish.OTHER, None),
    ],
    ids=["truncated", "safety", "recitation", "other", "no-finish", "blocked", "no-candidate"],
)
async def test_how_the_reply_ended(
    gemini: respx.MockRouter,
    llm: GeminiLabelLlm,
    body: dict[str, Any],
    finish: LlmFinish,
    text: str | None,
) -> None:
    gemini.post(url__regex=url()).respond(200, json=body)

    reply = await llm.read(OCR)

    assert (reply.finish, reply.text) == (finish, text)


def _status(code: int) -> Callable[[httpx.Request], httpx.Response]:
    def answer(_: httpx.Request) -> httpx.Response:
        error = {"code": code, "message": "nope", "status": "FAILED"}
        return httpx.Response(code, json={"error": error})

    return answer


@pytest.mark.parametrize(
    ("side_effect", "expected"),
    [
        (_status(400), LlmUnavailableError),
        (_status(403), LlmUnavailableError),
        (_status(429), LlmUnavailableError),
        (_status(503), LlmUnavailableError),
        (httpx.ConnectError("refused"), LlmUnavailableError),
        (httpx.ReadTimeout("slow"), LlmTimeoutError),
        (lambda _: httpx.Response(200, content=b"<html>"), LlmUnavailableError),
    ],
    ids=["400", "403", "429", "503", "connection", "timeout", "not-json"],
)
async def test_sdk_errors_are_mapped(
    gemini: respx.MockRouter, llm: GeminiLabelLlm, side_effect: Any, expected: type[Exception]
) -> None:
    gemini.post(url__regex=url()).mock(side_effect=side_effect)

    with pytest.raises(expected):
        await llm.read(OCR)


async def test_from_settings(gemini: respx.MockRouter) -> None:
    route = gemini.post(url__regex=url("gemini-3.6-flash")).respond(200, json=response())
    llm = GeminiLabelLlm.from_settings(
        settings(llm_model="gemini-3.6-flash", llm_timeout_seconds=12)
    )

    await llm.read(OCR)
    await llm.aclose()

    assert llm.model == "gemini-3.6-flash"
    assert route.calls.last.request.headers["x-goog-api-key"] == "test-gemini-key"
    assert llm._http.is_closed
