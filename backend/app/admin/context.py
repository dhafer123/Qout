"""What the panel's views need from the API application.

The panel is a Starlette app mounted inside the API, so `request.app` is the panel: a small
middleware puts the API application in the scope, and its state (settings, database
sessions, Redis, storage, opened by the API's lifespan) is read from there.
"""

import uuid
from typing import Any

from sqladmin.authentication import get_current_user_id
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
from starlette.datastructures import State
from starlette.requests import Request
from starlette.types import ASGIApp, Receive, Scope, Send

from app.core.config import Settings
from app.core.storage import Storage
from app.modules.contributions.moderation import ModerationService
from app.modules.products.cache import ProductCache

_MAIN_APP = "qout.main_app"


class MainAppMiddleware:
    def __init__(self, app: ASGIApp, main: Any) -> None:
        self.app = app
        self.main = main

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        scope[_MAIN_APP] = self.main
        await self.app(scope, receive, send)


def main_state(request: Request) -> State:
    state: State = request.scope[_MAIN_APP].state
    return state


def settings_of(request: Request) -> Settings:
    settings: Settings = main_state(request).settings
    return settings


def sessions_of(request: Request) -> async_sessionmaker[AsyncSession]:
    sessions: async_sessionmaker[AsyncSession] = main_state(request).session_factory
    return sessions


def product_cache(request: Request) -> ProductCache:
    settings = settings_of(request)
    return ProductCache(
        main_state(request).redis,
        ttl_seconds=settings.product_cache_ttl_seconds,
        not_found_ttl_seconds=settings.product_not_found_ttl_seconds,
    )


def moderation_service(request: Request, session: AsyncSession) -> ModerationService:
    storage: Storage = main_state(request).storage
    return ModerationService(session, storage, product_cache(request))


def signed_in_admin(request: Request) -> uuid.UUID:
    """The moderator using the panel (set by the authentication backend)."""
    return uuid.UUID(str(get_current_user_id(request)))
