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
        path: operation["operationId"]
        for path, methods in openapi_document()["paths"].items()
        for operation in methods.values()
    }
    assert operations == {
        "/health": "health",
        "/health/ready": "ready",
        "/v1/products/{ean}": "getProduct",
        "/v1/products/{ean}/alternatives": "getProductAlternatives",
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
