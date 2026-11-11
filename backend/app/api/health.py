"""Liveness and readiness endpoints."""

from collections.abc import Mapping
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Request, Response, status
from pydantic import BaseModel

from app.core.config import Settings
from app.core.health import CheckStatus, ReadinessCheck, run_checks

router = APIRouter(tags=["health"])


class HealthResponse(BaseModel):
    status: Literal["ok"]


class ReadinessResponse(BaseModel):
    status: Literal["ready", "not_ready"]
    checks: dict[str, CheckStatus]


def get_readiness_checks(request: Request) -> Mapping[str, ReadinessCheck]:
    checks: Mapping[str, ReadinessCheck] = request.app.state.readiness_checks
    return checks


def get_app_settings(request: Request) -> Settings:
    settings: Settings = request.app.state.settings
    return settings


@router.get("/health", summary="Liveness: the process is up")
async def health() -> HealthResponse:
    return HealthResponse(status="ok")


@router.get(
    "/health/ready",
    summary="Readiness: database and Redis are reachable",
    responses={status.HTTP_503_SERVICE_UNAVAILABLE: {"model": ReadinessResponse}},
)
async def ready(
    response: Response,
    checks: Annotated[Mapping[str, ReadinessCheck], Depends(get_readiness_checks)],
    settings: Annotated[Settings, Depends(get_app_settings)],
) -> ReadinessResponse:
    results = await run_checks(checks, timeout_s=settings.readiness_timeout_seconds)
    if all(result == "ok" for result in results.values()):
        return ReadinessResponse(status="ready", checks=results)
    response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    return ReadinessResponse(status="not_ready", checks=results)
