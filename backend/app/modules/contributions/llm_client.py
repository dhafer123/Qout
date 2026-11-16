"""`LabelLlm` on the Google Gemini API (official `google-genai` SDK).

One request per label: the system instruction and the OCR text, with a JSON answer
constrained to `OUTPUT_SCHEMA` (structured output). Nothing else is sent. The SDK runs on
our own `httpx` client, so requests go through the same HTTP stack as the rest of the
backend (and tests mock it with respx). SDK and transport errors become
`LlmTimeoutError` / `LlmUnavailableError`.
"""

import httpx
from google import genai
from google.genai import errors, types

from app.core.config import Settings
from app.modules.contributions.llm_parser import (
    OUTPUT_SCHEMA,
    SYSTEM_PROMPT,
    LlmFinish,
    LlmReply,
    LlmTimeoutError,
    LlmUnavailableError,
    user_message,
)

MAX_OUTPUT_TOKENS = 16_000
"""Room for the model's thinking plus the JSON answer (~1 000 tokens)."""
ATTEMPTS = 3
"""The SDK retries 408, 429 and 5xx (bounded by the time limit)."""

_FINISH = {
    types.FinishReason.STOP: LlmFinish.COMPLETE,
    types.FinishReason.MAX_TOKENS: LlmFinish.TRUNCATED,
    types.FinishReason.SAFETY: LlmFinish.REFUSED,
    types.FinishReason.PROHIBITED_CONTENT: LlmFinish.REFUSED,
    types.FinishReason.BLOCKLIST: LlmFinish.REFUSED,
    types.FinishReason.SPII: LlmFinish.REFUSED,
    types.FinishReason.RECITATION: LlmFinish.REFUSED,
}


class GeminiLabelLlm:
    def __init__(self, client: genai.Client, http: httpx.AsyncClient, *, model: str) -> None:
        self._client = client
        self._http = http
        self._model = model

    @classmethod
    def from_settings(
        cls, settings: Settings, http: httpx.AsyncClient | None = None
    ) -> "GeminiLabelLlm":
        http = http or httpx.AsyncClient(timeout=settings.llm_timeout_seconds)
        client = genai.Client(
            api_key=settings.llm_api_key.get_secret_value(),
            http_options=types.HttpOptions(
                timeout=int(settings.llm_timeout_seconds * 1000),  # milliseconds
                retry_options=types.HttpRetryOptions(attempts=ATTEMPTS),
                httpx_async_client=http,
            ),
        )
        return cls(client, http, model=settings.llm_model)

    @property
    def model(self) -> str:
        return self._model

    async def read(self, ocr_text: str) -> LlmReply:
        try:
            response = await self._client.aio.models.generate_content(
                model=self._model,
                contents=user_message(ocr_text),
                config=types.GenerateContentConfig(
                    system_instruction=SYSTEM_PROMPT,
                    response_mime_type="application/json",
                    response_json_schema=OUTPUT_SCHEMA,
                    max_output_tokens=MAX_OUTPUT_TOKENS,
                ),
            )
        except httpx.TimeoutException as error:
            raise LlmTimeoutError from error
        except errors.APIError as error:
            raise LlmUnavailableError(f"HTTP {error.code}: {error.message}") from error
        except (httpx.HTTPError, ValueError) as error:  # connection, unreadable response
            raise LlmUnavailableError(type(error).__name__) from error
        return _reply(response, self._model)

    async def aclose(self) -> None:
        await self._client.aio.aclose()
        await self._http.aclose()


def _reply(response: types.GenerateContentResponse, model: str) -> LlmReply:
    answered_by = response.model_version or model
    feedback = response.prompt_feedback
    if feedback is not None and feedback.block_reason is not None:
        return LlmReply(None, LlmFinish.REFUSED, answered_by)
    if not response.candidates:
        return LlmReply(None, LlmFinish.OTHER, answered_by)
    reason = response.candidates[0].finish_reason
    finish = LlmFinish.OTHER if reason is None else _FINISH.get(reason, LlmFinish.OTHER)
    return LlmReply(response.text, finish, answered_by)
