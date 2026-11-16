"""LLM fallback requests (T28): stored by the API, run by the worker, read by the contributor.

`POST /v1/labels/parse` asks for one when the rule-based reading is not ok and the fallback
is enabled (`LabelFallbackService.start`): a `pending` row is stored and a worker job
queued. The job (`FallbackRunner.run`) sends the OCR text to the model outside any
database transaction, then stores the reading (`done`, `parser_used` `llm`) or why there
is none (`needs_manual_entry`). A request still pending after the deadline (worker down,
queue backed up) is given up as `timeout`, by the job or by the next read, whichever comes
first. Every change is a conditional update from `pending`, so a finished request never
changes again.
"""

import logging
import uuid
from dataclasses import dataclass
from datetime import timedelta
from typing import Any

from redis.exceptions import RedisError
from sqlalchemy import func, update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.config import Settings
from app.core.queue import JobQueue
from app.modules.auth.rate_limit import RateLimiter
from app.modules.contributions.label_parser import label_reading
from app.modules.contributions.llm_parser import LabelLlm, LlmReading, read_with_llm
from app.modules.contributions.models import (
    FallbackReason,
    FallbackStatus,
    LabelFallback,
    ParserUsed,
)

logger = logging.getLogger(__name__)

JOB_NAME = "parse_label_with_llm"


@dataclass(frozen=True)
class FallbackSettings:
    enabled: bool
    max_per_user: int
    window_seconds: int
    deadline_seconds: int
    time_limit_seconds: float

    @classmethod
    def from_settings(cls, settings: Settings) -> "FallbackSettings":
        return cls(
            enabled=settings.llm_parser_enabled,
            max_per_user=settings.llm_parse_max_per_user,
            window_seconds=settings.llm_parse_window_seconds,
            deadline_seconds=settings.llm_parse_deadline_seconds,
            time_limit_seconds=settings.llm_timeout_seconds,
        )


def job_id(fallback_id: uuid.UUID) -> str:
    return f"label-fallback:{fallback_id}"


class FallbackNotFoundError(Exception):
    def __init__(self, fallback_id: uuid.UUID) -> None:
        super().__init__(f"no label reading {fallback_id}")


class LabelFallbackService:
    """The API side: ask for a fallback, read it."""

    def __init__(
        self,
        session: AsyncSession,
        settings: FallbackSettings,
        limiter: RateLimiter,
        queue: JobQueue,
    ) -> None:
        self._session = session
        self._settings = settings
        self._limiter = limiter
        self._queue = queue

    async def start(self, user_id: uuid.UUID, ocr_text: str) -> LabelFallback | None:
        """None when the fallback is turned off. Otherwise the stored request: `pending`,
        or `needs_manual_entry` right away (rate limit reached, queue unavailable)."""
        if not self._settings.enabled:
            return None
        limit = await self._limiter.hit(
            f"llm-parse:user:{user_id}",
            limit=self._settings.max_per_user,
            window=self._settings.window_seconds,
        )
        fallback = LabelFallback(user_id=user_id, ocr_text=ocr_text)
        if not limit.allowed:
            fallback.status = FallbackStatus.NEEDS_MANUAL_ENTRY
            fallback.reason = FallbackReason.RATE_LIMITED
            fallback.completed_at = func.clock_timestamp()
        self._session.add(fallback)
        await self._session.commit()  # before queueing: the job must find the row

        if fallback.status == FallbackStatus.PENDING:
            try:
                await self._queue.enqueue_job(
                    JOB_NAME,
                    str(fallback.id),
                    _job_id=job_id(fallback.id),
                    _expires=timedelta(seconds=self._settings.deadline_seconds),
                )
            except (RedisError, OSError):
                logger.warning("label fallback not queued", extra={"fallback": str(fallback.id)})
                await give_up(self._session, fallback.id, FallbackReason.UNAVAILABLE)
        await self._session.refresh(fallback)
        return fallback

    async def get(self, user_id: uuid.UUID, fallback_id: uuid.UUID) -> LabelFallback:
        """Someone else's request is reported as not found. A request pending past the
        deadline is given up (`timeout`) first."""
        fallback = await self._session.get(LabelFallback, fallback_id)
        if fallback is None or fallback.user_id != user_id:
            raise FallbackNotFoundError(fallback_id)
        if fallback.status == FallbackStatus.PENDING and await give_up(
            self._session,
            fallback_id,
            FallbackReason.TIMEOUT,
            older_than=self._settings.deadline_seconds,
        ):
            await self._session.refresh(fallback)
        return fallback


class FallbackRunner:
    """The worker side: read one pending request with the model."""

    def __init__(
        self,
        sessions: async_sessionmaker[AsyncSession],
        llm: LabelLlm | None,
        settings: FallbackSettings,
    ) -> None:
        self._sessions = sessions
        self._llm = llm
        self._settings = settings

    async def run(self, fallback_id: uuid.UUID) -> FallbackStatus | None:
        """The status it ended with; None if it was not pending (missing, already done)."""
        async with self._sessions() as session:
            fallback = await session.get(LabelFallback, fallback_id)
            if fallback is None or fallback.status != FallbackStatus.PENDING:
                return None
            if await give_up(
                session,
                fallback_id,
                FallbackReason.TIMEOUT,
                older_than=self._settings.deadline_seconds,
            ):
                return FallbackStatus.NEEDS_MANUAL_ENTRY  # too late to be worth asking
            ocr_text = fallback.ocr_text

        reading = await self._read(ocr_text)
        async with self._sessions() as session:
            if reading.accepted and reading.parse is not None:
                result = label_reading(reading.parse, ParserUsed.LLM).model_dump(mode="json")
                stored = await store_reading(session, fallback_id, result, reading.model)
                status = FallbackStatus.DONE
            else:
                reason = reading.reason or FallbackReason.INVALID_OUTPUT
                stored = await give_up(session, fallback_id, reason, reading.model)
                status = FallbackStatus.NEEDS_MANUAL_ENTRY
        logger.info(
            "label fallback read",
            extra={
                "fallback": str(fallback_id),
                "status": status.value,
                "reason": None if reading.reason is None else reading.reason.value,
                "model": reading.model,
                "stored": stored,
            },
        )
        return status if stored else None

    async def _read(self, ocr_text: str) -> LlmReading:
        if self._llm is None:  # turned off in the worker after the API queued it
            return LlmReading(None, FallbackReason.DISABLED, None)
        return await read_with_llm(
            self._llm, ocr_text, time_limit=self._settings.time_limit_seconds
        )


async def give_up(
    session: AsyncSession,
    fallback_id: uuid.UUID,
    reason: FallbackReason,
    model: str | None = None,
    *,
    older_than: int | None = None,
) -> bool:
    """Finish a pending request as `needs_manual_entry`; with `older_than`, only if it was
    created at least that many seconds ago. False if it was not pending (or not old
    enough)."""
    values = {"status": FallbackStatus.NEEDS_MANUAL_ENTRY, "reason": reason, "model": model}
    return await _finish(session, fallback_id, values, older_than=older_than)


async def store_reading(
    session: AsyncSession, fallback_id: uuid.UUID, result: dict[str, Any], model: str | None
) -> bool:
    """Finish a pending request as `done`. False if it was not pending any more."""
    values = {"status": FallbackStatus.DONE, "result": result, "model": model}
    return await _finish(session, fallback_id, values)


async def _finish(
    session: AsyncSession,
    fallback_id: uuid.UUID,
    values: dict[str, Any],
    *,
    older_than: int | None = None,
) -> bool:
    """A conditional update from `pending` (so a finished request never changes), then
    commit."""
    statement = (
        update(LabelFallback)
        .where(LabelFallback.id == fallback_id, LabelFallback.status == FallbackStatus.PENDING)
        .values(**values, completed_at=func.clock_timestamp())
        .returning(LabelFallback.id)
    )
    if older_than is not None:
        cutoff = func.clock_timestamp() - timedelta(seconds=older_than)
        statement = statement.where(LabelFallback.created_at < cutoff)
    updated = (await session.execute(statement)).scalar_one_or_none()
    await session.commit()
    return updated is not None
