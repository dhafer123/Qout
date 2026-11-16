"""The LLM fallback parser end to end (T28), against real Postgres and Redis with a fake
model: `POST /v1/labels/parse` stores and queues a request, the worker job reads it, and
`GET /v1/labels/parse/{id}` returns the reading or why there is none."""

import json
import uuid
from collections.abc import AsyncIterator, Callable
from contextlib import AbstractAsyncContextManager
from typing import Any

import httpx
import pytest
from arq import Worker, create_pool
from arq.connections import ArqRedis
from arq.constants import in_progress_key_prefix, job_key_prefix, result_key_prefix
from pydantic import SecretStr
from redis.asyncio import Redis
from redis.exceptions import ConnectionError as RedisConnectionError
from sqlalchemy import func, select, text, update
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.api.contributions import get_job_queue
from app.core.config import Settings
from app.core.queue import redis_settings
from app.factory import create_app
from app.modules.contributions.fallbacks import JOB_NAME, job_id
from app.modules.contributions.label_parser import parse_label
from app.modules.contributions.llm_client import AnthropicLabelLlm
from app.modules.contributions.llm_parser import LlmReply, LlmUnavailableError
from app.modules.contributions.models import LabelFallback
from app.worker import jobs
from app.worker.settings import worker_settings
from tests.integration.conftest import IntegrationEnv, running_client

Sessions = async_sessionmaker[AsyncSession]
PASSWORD = "a long enough password"
MODEL = "claude-test"

# A column-by-column table where the OCR read `50g` as `508`: the rules parser reads 508 g
# of carbohydrate and fails its checks; the model fixes it to 50.
OCR = """Valeurs nutritionnelles pour 100 g
Energie
Matières grasses
dont acides gras saturés
Glucides
dont sucres
Protéines
Sel
1386 kJ / 330 kcal
10 g
2 g
508
5 g
10 g
1 g"""


def grams(amount: float) -> dict[str, Any]:
    return {"amount": amount, "unit": "g"}


ANSWER = {
    "table_found": True,
    "basis": "per_100g",
    "values": {
        "energy_kj": {"amount": 1386},
        "energy_kcal": {"amount": 330},
        "total_fat_g": grams(10),
        "saturated_fat_g": grams(2),
        "carbohydrates_g": grams(50),
        "sugars_g": grams(5),
        "fibre_g": None,
        "protein_g": grams(10),
        "salt_g": grams(1),
        "sodium_g": None,
    },
    "approximate": [],
}


class FakeLlm:
    """Answers every label with `answer` (or raises `error`); records what it was sent."""

    model = MODEL

    def __init__(self, answer: object = ANSWER, error: Exception | None = None) -> None:
        self.answer = answer
        self.error = error
        self.texts: list[str] = []

    async def read(self, ocr_text: str) -> LlmReply:
        self.texts.append(ocr_text)
        if self.error is not None:
            raise self.error
        return LlmReply(json.dumps(self.answer), "end_turn", MODEL)


class BrokenQueue:
    async def enqueue_job(self, _function: str, *_args: Any, **_kwargs: Any) -> None:
        raise RedisConnectionError("queue down")


# ---------------------------------------------------------------- fixtures


async def _clear(engine: AsyncEngine, redis: Redis) -> None:
    async with engine.begin() as connection:
        await connection.execute(text("TRUNCATE users CASCADE"))
    keys = [key async for key in redis.scan_iter(match="qout:ratelimit:*")]
    if keys:
        await redis.delete(*keys)


@pytest.fixture
async def redis(integration_env: IntegrationEnv) -> AsyncIterator[Redis]:
    client = Redis.from_url(str(integration_env.redis_url))
    yield client
    await client.aclose()


@pytest.fixture
async def sessions(db_engine: AsyncEngine, redis: Redis) -> AsyncIterator[Sessions]:
    await _clear(db_engine, redis)
    yield async_sessionmaker(db_engine, expire_on_commit=False)
    await _clear(db_engine, redis)


@pytest.fixture
def settings(make_settings: Callable[..., Settings]) -> Callable[..., Settings]:
    def _settings(**overrides: object) -> Settings:
        values: dict[str, object] = {
            "llm_parser_enabled": True,
            "llm_api_key": SecretStr("sk-test-not-used"),
            "import_delta_cron_enabled": False,
            "product_images_cron_enabled": False,
        }
        return make_settings(**(values | overrides))

    return _settings


@pytest.fixture
def queue_name() -> str:
    return f"qout:test-queue:{uuid.uuid4().hex}"


@pytest.fixture
async def queue(make_settings: Callable[..., Settings], queue_name: str) -> AsyncIterator[ArqRedis]:
    pool = await create_pool(redis_settings(make_settings()), default_queue_name=queue_name)
    yield pool
    await pool.delete(queue_name)
    await pool.aclose()


ApiFactory = Callable[..., AbstractAsyncContextManager[httpx.AsyncClient]]


@pytest.fixture
def api_with(settings: Callable[..., Settings], sessions: Sessions, queue: ArqRedis) -> ApiFactory:
    """The API on the test stack, queueing jobs on the test queue (not the dev worker's)."""

    def _api(job_queue: object = queue, **overrides: object) -> Any:
        app = create_app(settings(**overrides))
        app.dependency_overrides[get_job_queue] = lambda: job_queue
        return running_client(app)

    return _api


@pytest.fixture
async def api(api_with: ApiFactory) -> AsyncIterator[httpx.AsyncClient]:
    async with api_with() as client:
        yield client


@pytest.fixture
async def worker_ctx(settings: Callable[..., Settings]) -> AsyncIterator[jobs.Context]:
    """The worker's resources, with the fake model."""
    llm = FakeLlm()
    ctx: jobs.Context = {"settings": settings(), "label_llm": llm}
    await jobs.startup(ctx)
    yield ctx
    await jobs.shutdown(ctx)


# ---------------------------------------------------------------- helpers


async def sign_in(api: httpx.AsyncClient, email: str = "contributor@example.tn") -> dict[str, str]:
    response = await api.post("/v1/auth/register", json={"email": email, "password": PASSWORD})
    assert response.status_code == 201, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


async def parse(
    api: httpx.AsyncClient, headers: dict[str, str], ocr_text: str = OCR
) -> dict[str, Any]:
    response = await api.post("/v1/labels/parse", json={"ocr_text": ocr_text}, headers=headers)
    assert response.status_code == 200, response.text
    body: dict[str, Any] = response.json()
    return body


async def fallback_count(sessions: Sessions) -> int:
    async with sessions() as session:
        return await session.scalar(select(func.count()).select_from(LabelFallback)) or 0


async def queued(queue: ArqRedis) -> list[tuple[str, tuple[Any, ...]]]:
    return [(job.function, job.args) for job in await queue.queued_jobs()]


async def age(sessions: Sessions, fallback_id: str, seconds: int) -> None:
    """Pretend the request was made `seconds` ago."""
    async with sessions() as session:
        await session.execute(
            update(LabelFallback)
            .where(LabelFallback.id == uuid.UUID(fallback_id))
            .values(created_at=func.now() - func.make_interval(0, 0, 0, 0, 0, 0, seconds))
        )
        await session.commit()


# ---------------------------------------------------------------- asking


def test_the_example_fails_the_rules() -> None:
    assert not parse_label(OCR).ok


async def test_failed_rules_reading_queues_a_fallback(
    api: httpx.AsyncClient, sessions: Sessions, queue: ArqRedis
) -> None:
    headers = await sign_in(api)

    body = await parse(api, headers)

    assert (body["parser_used"], body["ok"]) == ("rules", False)
    fallback = body["fallback"]
    assert (fallback["status"], fallback["reason"], fallback["result"]) == ("pending", None, None)
    assert await queued(queue) == [(JOB_NAME, (fallback["id"],))]
    async with sessions() as session:
        row = await session.get(LabelFallback, uuid.UUID(fallback["id"]))
    assert row is not None
    assert row.ocr_text == OCR


async def test_no_fallback_when_the_rules_reading_is_ok(
    api: httpx.AsyncClient, sessions: Sessions, queue: ArqRedis
) -> None:
    headers = await sign_in(api)
    ocr = OCR.replace("508", "50 g")

    body = await parse(api, headers, ocr)

    assert (body["ok"], body["fallback"]) == (True, None)
    assert await fallback_count(sessions) == 0
    assert await queued(queue) == []


async def test_no_fallback_when_turned_off(
    api_with: ApiFactory, sessions: Sessions, queue: ArqRedis
) -> None:
    async with api_with(llm_parser_enabled=False) as api:
        headers = await sign_in(api)
        body = await parse(api, headers)

    assert (body["ok"], body["fallback"]) == (False, None)
    assert await fallback_count(sessions) == 0
    assert await queued(queue) == []


async def test_fallbacks_are_rate_limited_per_user(
    api_with: ApiFactory, sessions: Sessions, queue: ArqRedis
) -> None:
    async with api_with(llm_parse_max_per_user=1) as api:
        headers = await sign_in(api)
        first = (await parse(api, headers))["fallback"]
        second = (await parse(api, headers))["fallback"]
        other = (await parse(api, await sign_in(api, "other@example.tn")))["fallback"]

    assert first["status"] == "pending"
    assert (second["status"], second["reason"]) == ("needs_manual_entry", "rate_limited")
    assert second["completed_at"] is not None
    assert other["status"] == "pending"
    assert [args for _, args in await queued(queue)] == [(first["id"],), (other["id"],)]


async def test_queue_down_gives_manual_entry(api_with: ApiFactory, sessions: Sessions) -> None:
    async with api_with(job_queue=BrokenQueue()) as api:
        body = await parse(api, await sign_in(api))

    assert (body["fallback"]["status"], body["fallback"]["reason"]) == (
        "needs_manual_entry",
        "unavailable",
    )


# ---------------------------------------------------------------- the worker job


async def test_job_stores_the_llm_reading(
    api: httpx.AsyncClient, sessions: Sessions, worker_ctx: jobs.Context
) -> None:
    headers = await sign_in(api)
    fallback_id = (await parse(api, headers))["fallback"]["id"]

    status = await jobs.parse_label_with_llm(worker_ctx, fallback_id)

    assert status == "done"
    assert worker_ctx["label_llm"].texts == [OCR]
    response = await api.get(f"/v1/labels/parse/{fallback_id}", headers=headers)
    assert response.status_code == 200
    body = response.json()
    assert (body["status"], body["reason"]) == ("done", None)
    assert body["completed_at"] is not None
    result = body["result"]
    assert (result["parser_used"], result["ok"], result["basis"]) == ("llm", True, "per_100g")
    assert result["values"]["carbohydrates_g"] == 50
    assert result["values"]["energy_kj"] == 1386
    assert result["issues"] == []
    async with sessions() as session:
        row = await session.get(LabelFallback, uuid.UUID(fallback_id))
    assert row is not None
    assert row.model == MODEL


@pytest.mark.parametrize(
    ("llm", "reason"),
    [
        (FakeLlm(ANSWER | {"basis": "per_portion_only"}), "failed_checks"),
        (
            FakeLlm(ANSWER | {"values": ANSWER["values"] | {"protein_g": grams(12)}}),
            "ungrounded_value",
        ),
        (FakeLlm({"table_found": True}), "invalid_output"),
        (FakeLlm(error=LlmUnavailableError("HTTP 529")), "unavailable"),
    ],
    ids=["failed-checks", "ungrounded", "invalid", "unavailable"],
)
async def test_job_without_a_usable_reading(
    api: httpx.AsyncClient, worker_ctx: jobs.Context, llm: FakeLlm, reason: str
) -> None:
    worker_ctx["label_llm"] = llm
    headers = await sign_in(api)
    fallback_id = (await parse(api, headers))["fallback"]["id"]

    status = await jobs.parse_label_with_llm(worker_ctx, fallback_id)

    body = (await api.get(f"/v1/labels/parse/{fallback_id}", headers=headers)).json()
    assert status == "needs_manual_entry"
    assert (body["status"], body["reason"], body["result"]) == ("needs_manual_entry", reason, None)


async def test_job_with_the_fallback_off_in_the_worker(
    api: httpx.AsyncClient, worker_ctx: jobs.Context
) -> None:
    del worker_ctx["label_llm"]
    headers = await sign_in(api)
    fallback_id = (await parse(api, headers))["fallback"]["id"]

    await jobs.parse_label_with_llm(worker_ctx, fallback_id)

    body = (await api.get(f"/v1/labels/parse/{fallback_id}", headers=headers)).json()
    assert (body["status"], body["reason"]) == ("needs_manual_entry", "disabled")


async def test_job_too_late_does_not_ask_the_model(
    api: httpx.AsyncClient, sessions: Sessions, worker_ctx: jobs.Context
) -> None:
    headers = await sign_in(api)
    fallback_id = (await parse(api, headers))["fallback"]["id"]
    await age(sessions, fallback_id, 91)

    status = await jobs.parse_label_with_llm(worker_ctx, fallback_id)

    body = (await api.get(f"/v1/labels/parse/{fallback_id}", headers=headers)).json()
    assert status == "needs_manual_entry"
    assert (body["status"], body["reason"]) == ("needs_manual_entry", "timeout")
    assert worker_ctx["label_llm"].texts == []


async def test_job_for_a_finished_or_unknown_request(
    api: httpx.AsyncClient, worker_ctx: jobs.Context
) -> None:
    headers = await sign_in(api)
    fallback_id = (await parse(api, headers))["fallback"]["id"]
    await jobs.parse_label_with_llm(worker_ctx, fallback_id)

    again = await jobs.parse_label_with_llm(worker_ctx, fallback_id)
    unknown = await jobs.parse_label_with_llm(worker_ctx, str(uuid.uuid4()))

    assert (again, unknown) == (None, None)
    assert worker_ctx["label_llm"].texts == [OCR]


async def test_reading_finished_after_a_timeout_is_not_stored(
    api: httpx.AsyncClient, sessions: Sessions, worker_ctx: jobs.Context
) -> None:
    """The contributor gave up waiting (timeout on read) while the model was answering."""
    headers = await sign_in(api)
    fallback_id = (await parse(api, headers))["fallback"]["id"]

    class SlowLlm(FakeLlm):
        async def read(self, ocr_text: str) -> LlmReply:
            await age(sessions, fallback_id, 91)
            await api.get(f"/v1/labels/parse/{fallback_id}", headers=headers)  # gives up
            return await super().read(ocr_text)

    worker_ctx["label_llm"] = SlowLlm()

    status = await jobs.parse_label_with_llm(worker_ctx, fallback_id)

    body = (await api.get(f"/v1/labels/parse/{fallback_id}", headers=headers)).json()
    assert status is None
    assert (body["status"], body["reason"], body["result"]) == (
        "needs_manual_entry",
        "timeout",
        None,
    )


async def test_the_worker_runs_queued_fallbacks(
    api: httpx.AsyncClient,
    settings: Callable[..., Settings],
    queue: ArqRedis,
    queue_name: str,
) -> None:
    """Through a real arq worker: the job is registered and finds the request."""
    headers = await sign_in(api)
    fallback_id = (await parse(api, headers))["fallback"]["id"]
    config = worker_settings(settings(), queue_name=queue_name)
    config["ctx"]["label_llm"] = FakeLlm()
    rescore_keys = [p + jobs.rescore_job_id() for p in (job_key_prefix, result_key_prefix)]
    rescore_keys.append(in_progress_key_prefix + jobs.rescore_job_id())
    await queue.delete(*rescore_keys)  # shared with dev: see tests/integration/ingestion
    worker = Worker(**config, burst=True, handle_signals=False, poll_delay=0.01)
    try:
        await worker.main()
    finally:
        await worker.close()
        await queue.delete(*rescore_keys)

    body = (await api.get(f"/v1/labels/parse/{fallback_id}", headers=headers)).json()
    assert body["status"] == "done"
    assert await queue.exists(result_key_prefix + job_id(uuid.UUID(fallback_id)))
    await queue.delete(result_key_prefix + job_id(uuid.UUID(fallback_id)))


# ---------------------------------------------------------------- reading


async def test_pending_past_the_deadline_is_given_up(
    api: httpx.AsyncClient, sessions: Sessions
) -> None:
    headers = await sign_in(api)
    fallback_id = (await parse(api, headers))["fallback"]["id"]

    fresh = (await api.get(f"/v1/labels/parse/{fallback_id}", headers=headers)).json()
    await age(sessions, fallback_id, 91)
    late = (await api.get(f"/v1/labels/parse/{fallback_id}", headers=headers)).json()

    assert (fresh["status"], fresh["completed_at"]) == ("pending", None)
    assert (late["status"], late["reason"]) == ("needs_manual_entry", "timeout")
    assert late["completed_at"] is not None


async def test_only_the_requester_reads_it(api: httpx.AsyncClient) -> None:
    headers = await sign_in(api)
    fallback_id = (await parse(api, headers))["fallback"]["id"]
    other = await sign_in(api, "other@example.tn")

    by_other = await api.get(f"/v1/labels/parse/{fallback_id}", headers=other)
    unknown = await api.get(f"/v1/labels/parse/{uuid.uuid4()}", headers=headers)
    anonymous = await api.get(f"/v1/labels/parse/{fallback_id}")

    assert (by_other.status_code, unknown.status_code, anonymous.status_code) == (404, 404, 401)


async def test_requests_go_with_the_account(api: httpx.AsyncClient, sessions: Sessions) -> None:
    await parse(api, await sign_in(api))
    async with sessions() as session:
        await session.execute(text("DELETE FROM users"))
        await session.commit()

    assert await fallback_count(sessions) == 0


async def test_worker_builds_the_anthropic_reader_when_enabled(
    settings: Callable[..., Settings],
) -> None:
    ctx: jobs.Context = {"settings": settings(llm_model="claude-haiku-5-5")}
    await jobs.startup(ctx)
    llm = ctx["label_llm"]
    await jobs.shutdown(ctx)

    assert isinstance(llm, AnthropicLabelLlm)
    assert llm.model == "claude-haiku-5-5"
    assert llm._client.is_closed()


async def test_worker_has_no_reader_when_disabled(settings: Callable[..., Settings]) -> None:
    ctx: jobs.Context = {"settings": settings(llm_parser_enabled=False)}
    await jobs.startup(ctx)
    await jobs.shutdown(ctx)

    assert "label_llm" not in ctx
