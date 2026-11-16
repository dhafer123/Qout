"""`LabelLlm` on the Anthropic Messages API (official SDK).

One request per label: the system prompt and the OCR text, structured output with
`OUTPUT_SCHEMA`, and the API's server-side refusal fallback (`fallbacks: "default"`: if the
model declines, the API retries on its default fallback model in the same call). Nothing
else is sent. SDK errors become `LlmTimeoutError` / `LlmUnavailableError`.
"""

from typing import Any

import anthropic
from anthropic import AsyncAnthropic

from app.core.config import LlmEffort, Settings
from app.modules.contributions.llm_parser import (
    OUTPUT_SCHEMA,
    SYSTEM_PROMPT,
    LlmReply,
    LlmTimeoutError,
    LlmUnavailableError,
    user_message,
)

MAX_TOKENS = 16_000
"""Room for adaptive thinking plus the JSON answer (~1 000 tokens)."""
MAX_RETRIES = 2
"""SDK retries on connection errors, 408, 409, 429 and 5xx (bounded by the timeout)."""
FALLBACK_BETA = "server-side-fallback-2026-07-01"


class AnthropicLabelLlm:
    def __init__(self, client: AsyncAnthropic, *, model: str, effort: LlmEffort) -> None:
        self._client = client
        self._model = model
        self._effort: LlmEffort = effort

    @classmethod
    def from_settings(
        cls, settings: Settings, client: AsyncAnthropic | None = None
    ) -> "AnthropicLabelLlm":
        client = client or AsyncAnthropic(
            api_key=settings.llm_api_key.get_secret_value(),
            timeout=settings.llm_timeout_seconds,
            max_retries=MAX_RETRIES,
        )
        return cls(client, model=settings.llm_model, effort=settings.llm_effort)

    @property
    def model(self) -> str:
        return self._model

    async def read(self, ocr_text: str) -> LlmReply:
        try:
            message = await self._client.beta.messages.create(
                model=self._model,
                max_tokens=MAX_TOKENS,
                system=SYSTEM_PROMPT,
                messages=[{"role": "user", "content": user_message(ocr_text)}],
                output_config={
                    "effort": self._effort,
                    "format": {"type": "json_schema", "schema": OUTPUT_SCHEMA},
                },
                betas=[FALLBACK_BETA],
                fallbacks="default",
            )
        except anthropic.APITimeoutError as error:
            raise LlmTimeoutError from error
        except anthropic.APIStatusError as error:
            raise LlmUnavailableError(f"HTTP {error.status_code}: {error.message}") from error
        except anthropic.APIError as error:  # connection errors, unreadable responses
            raise LlmUnavailableError(type(error).__name__) from error
        content: Any = getattr(message, "content", None)
        if not isinstance(content, list):  # a 200 whose body isn't a message (proxy page)
            raise LlmUnavailableError("unreadable response")
        text = next((block.text for block in content if block.type == "text"), None)
        return LlmReply(text=text, stop_reason=message.stop_reason, model=message.model)

    async def aclose(self) -> None:
        await self._client.close()
