"""FastAPI application factory."""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from functools import partial

from fastapi import FastAPI
from redis.asyncio import Redis

from app import __version__
from app.api.health import router as health_router
from app.api.products import router as products_router
from app.core.config import Settings, get_settings
from app.core.db import create_engine, create_session_factory
from app.core.health import ReadinessCheck, check_database, check_redis
from app.core.logging import configure_logging
from app.core.request_id import RequestIdMiddleware
from app.modules.ingestion.off_client import OffClient


def create_app(settings: Settings | None = None) -> FastAPI:
    """Build the API. Connections are opened on startup and closed on shutdown."""
    settings = settings or get_settings()
    configure_logging(settings.log_level)

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        engine = create_engine(settings)
        redis = Redis.from_url(str(settings.redis_url))
        checks: dict[str, ReadinessCheck] = {
            "database": partial(check_database, engine),
            "redis": partial(check_redis, redis),
        }
        app.state.session_factory = create_session_factory(engine)
        app.state.readiness_checks = checks
        app.state.redis = redis
        app.state.off_client = OffClient.from_settings(settings)
        try:
            yield
        finally:
            await app.state.off_client.aclose()
            await redis.aclose()
            await engine.dispose()

    app = FastAPI(title="Qout API", version=__version__, lifespan=lifespan)
    app.state.settings = settings
    app.add_middleware(RequestIdMiddleware)
    app.include_router(health_router)
    app.include_router(products_router)
    return app
