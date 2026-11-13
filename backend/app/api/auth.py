"""Contributor accounts: register, login, refresh, logout, current user."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.api.deps import SessionDep
from app.core.config import Settings
from app.modules.auth.models import User
from app.modules.auth.rate_limit import RateLimiter
from app.modules.auth.schemas import Credentials, RefreshRequest, TokenPair, UserRead
from app.modules.auth.service import (
    AuthService,
    EmailTakenError,
    InvalidCredentialsError,
    InvalidRefreshTokenError,
    NotAuthenticatedError,
    RateLimitedError,
    Tokens,
)
from app.modules.products.schemas import ErrorResponse

router = APIRouter(prefix="/v1/auth", tags=["auth"])

_bearer = HTTPBearer(auto_error=False)
_UNAUTHORIZED = {"model": ErrorResponse, "description": "Missing, invalid or expired token"}
_RATE_LIMITED = {"model": ErrorResponse, "description": "Too many attempts; see Retry-After"}


def get_auth_service(request: Request, session: SessionDep) -> AuthService:
    settings: Settings = request.app.state.settings
    return AuthService(session, settings, RateLimiter(request.app.state.redis))


AuthServiceDep = Annotated[AuthService, Depends(get_auth_service)]


async def get_current_user(
    service: AuthServiceDep,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> User:
    """The signed-in user (valid `Authorization: Bearer <access token>`), else 401."""
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise _unauthorized("not signed in")
    try:
        return await service.current_user(credentials.credentials)
    except NotAuthenticatedError as error:
        raise _unauthorized("invalid or expired access token") from error


CurrentUser = Annotated[User, Depends(get_current_user)]


@router.post(
    "/register",
    status_code=status.HTTP_201_CREATED,
    summary="Create a contributor account",
    description="Scanning needs no account; contributing does. Signs the new user in.",
    responses={
        status.HTTP_409_CONFLICT: {"model": ErrorResponse, "description": "Email taken"},
        status.HTTP_422_UNPROCESSABLE_CONTENT: {
            "model": ErrorResponse,
            "description": "Invalid email, or password shorter than 10 characters",
        },
        status.HTTP_429_TOO_MANY_REQUESTS: _RATE_LIMITED,
    },
)
async def register(body: Credentials, request: Request, service: AuthServiceDep) -> TokenPair:
    try:
        tokens = await service.register(body.email, body.password, client_ip=_ip(request))
    except ValueError as error:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, str(error)) from error
    except EmailTakenError as error:
        raise HTTPException(
            status.HTTP_409_CONFLICT, "an account with this email already exists"
        ) from error
    except RateLimitedError as error:
        raise _rate_limited(error) from error
    return _pair(tokens)


@router.post(
    "/login",
    summary="Sign in",
    responses={
        status.HTTP_401_UNAUTHORIZED: {
            "model": ErrorResponse,
            "description": "Wrong email or password",
        },
        status.HTTP_429_TOO_MANY_REQUESTS: _RATE_LIMITED,
    },
)
async def login(body: Credentials, request: Request, service: AuthServiceDep) -> TokenPair:
    try:
        tokens = await service.login(body.email, body.password, client_ip=_ip(request))
    except InvalidCredentialsError as error:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "wrong email or password") from error
    except RateLimitedError as error:
        raise _rate_limited(error) from error
    return _pair(tokens)


@router.post(
    "/refresh",
    summary="Exchange a refresh token for new tokens",
    description=(
        "Each refresh token works once. Presenting one again signs out every device that "
        "shares its session (the token was probably copied)."
    ),
    responses={status.HTTP_401_UNAUTHORIZED: _UNAUTHORIZED},
)
async def refresh_tokens(body: RefreshRequest, service: AuthServiceDep) -> TokenPair:
    try:
        tokens = await service.refresh(body.refresh_token)
    except InvalidRefreshTokenError as error:
        raise _unauthorized("invalid, expired or already used refresh token") from error
    return _pair(tokens)


@router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Sign out (this device)",
    description="Revokes the refresh token's session. Always succeeds.",
)
async def logout(body: RefreshRequest, service: AuthServiceDep) -> Response:
    await service.logout(body.refresh_token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get(
    "/me",
    summary="The signed-in user",
    responses={status.HTTP_401_UNAUTHORIZED: _UNAUTHORIZED},
)
async def get_me(user: CurrentUser) -> UserRead:
    return UserRead.model_validate(user)


def _pair(tokens: Tokens) -> TokenPair:
    return TokenPair(
        access_token=tokens.access_token,
        expires_in=tokens.access_expires_in,
        refresh_token=tokens.refresh_token,
        refresh_expires_in=tokens.refresh_expires_in,
    )


def _ip(request: Request) -> str:
    # The direct peer. Behind a reverse proxy this needs the forwarded address (T32/T35).
    return request.client.host if request.client is not None else "unknown"


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status.HTTP_401_UNAUTHORIZED, detail, headers={"WWW-Authenticate": "Bearer"}
    )


def _rate_limited(error: RateLimitedError) -> HTTPException:
    return HTTPException(
        status.HTTP_429_TOO_MANY_REQUESTS,
        str(error),
        headers={"Retry-After": str(error.retry_after)},
    )
