"""The exported OpenAPI document: stable, independent of the environment, committed."""

import runpy
import sys
from pathlib import Path

import pytest

from app.core.config import REPO_ROOT
from app.openapi import main, openapi_document, render

COMMITTED = REPO_ROOT / "api" / "openapi.json"


def test_committed_spec_is_up_to_date() -> None:
    """Fails when the API changes without `scripts/gen_client.sh` (spec + app client)."""
    assert COMMITTED.read_text(encoding="utf-8") == render(), (
        "api/openapi.json is out of date: run scripts/gen_client.sh and commit the result"
    )


def test_operation_ids_name_the_route_functions() -> None:
    operations = {
        f"{method.upper()} {path}": operation["operationId"]
        for path, methods in openapi_document()["paths"].items()
        for method, operation in methods.items()
    }
    assert operations == {
        "GET /health": "health",
        "GET /health/ready": "ready",
        "GET /v1/products/{ean}": "getProduct",
        "GET /v1/products/{ean}/alternatives": "getProductAlternatives",
        "POST /v1/auth/register": "register",
        "POST /v1/auth/login": "login",
        "POST /v1/auth/refresh": "refreshTokens",
        "POST /v1/auth/logout": "logout",
        "GET /v1/auth/me": "getMe",
        "POST /v1/uploads": "createUpload",
        "POST /v1/contributions": "submitContribution",
        "GET /v1/contributions": "listMyContributions",
        "GET /v1/contributions/{contribution_id}": "getMyContribution",
        "POST /v1/labels/parse": "parseLabelText",
        "GET /v1/labels/parse/{fallback_id}": "getLabelFallback",
        "POST /v1/score/preview": "previewScore",
        "POST /v1/reports": "reportError",
        "GET /v1/admin/contributions": "listContributions",
        "POST /v1/admin/contributions/{contribution_id}/approve": "approveContribution",
        "POST /v1/admin/contributions/{contribution_id}/reject": "rejectContribution",
        "GET /v1/admin/contributions/{contribution_id}": "getContribution",
        "PATCH /v1/admin/contributions/{contribution_id}": "editContribution",
        "GET /v1/admin/reports": "listReports",
        "POST /v1/admin/reports/{report_id}/resolve": "resolveReport",
        "POST /v1/admin/reports/{report_id}/dismiss": "dismissReport",
    }


def test_document_ignores_the_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    before = render()
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://someone@elsewhere/prod")
    monkeypatch.setenv("APP_ENV", "prod")
    assert render() == before
    assert before.endswith("}\n")


def test_main_prints_the_document(capsys: pytest.CaptureFixture[str]) -> None:
    assert main([]) == 0
    assert capsys.readouterr().out == render()


def test_check(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    current = tmp_path / "openapi.json"
    current.write_text(render(), encoding="utf-8")
    assert main(["--check", str(current)]) == 0
    assert "is up to date" in capsys.readouterr().out

    current.write_text("{}\n", encoding="utf-8")
    assert main(["--check", str(current)]) == 1
    assert "run scripts/gen_client.sh" in capsys.readouterr().err

    assert main(["--check", str(tmp_path / "missing.json")]) == 1


def test_module_entry_point(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(sys, "argv", ["app.openapi", "--check", str(COMMITTED)])
    monkeypatch.delitem(sys.modules, "app.openapi")  # run it fresh, as `python -m` does
    with pytest.raises(SystemExit) as exit_info:
        runpy.run_module("app.openapi", run_name="__main__")
    assert exit_info.value.code == 0
