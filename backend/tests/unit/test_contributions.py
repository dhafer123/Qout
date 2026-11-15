"""Contributions and error reports without the database: photo key ownership, nutrition
conversions, score preview (against every golden case), and request validation."""

import json
import uuid
from datetime import UTC, datetime
from decimal import Decimal
from pathlib import Path
from typing import Any

import pytest
from pydantic import ValidationError

from app.core.config import REPO_ROOT, Settings
from app.modules.contributions.models import Contribution, ReportReason
from app.modules.contributions.moderation import product_photo_key
from app.modules.contributions.nutrition import (
    engine_input,
    facts_values,
    score_preview,
    stored_nutrition,
)
from app.modules.contributions.schemas import (
    ContributionCreate,
    NutritionValues,
    PhotoKind,
    ReportCreate,
    ReviewDecision,
)
from app.modules.contributions.service import photo_key_problem
from app.modules.scoring import ENGINE_VERSION, Category, Grade

USER = uuid.UUID("11111111-1111-4111-8111-111111111111")
OTHER_USER = uuid.UUID("33333333-3333-4333-8333-333333333333")
CLIENT = uuid.UUID("22222222-2222-4222-8222-222222222222")
OTHER_CLIENT = uuid.UUID("44444444-4444-4444-8444-444444444444")
RANDOM = "0123456789abcdef"
GOLDEN = sorted((REPO_ROOT / "scoring-spec" / "golden").glob("*.json"))


def key(
    user: uuid.UUID = USER,
    client: uuid.UUID = CLIENT,
    name: str = f"nutrition-{RANDOM}.jpg",
) -> str:
    return f"contributions/{user}/{client}/{name}"


# ---------------------------------------------------------------- photo keys


@pytest.mark.parametrize(
    ("kind", "name"),
    [
        (PhotoKind.NUTRITION, f"nutrition-{RANDOM}.jpg"),
        (PhotoKind.FRONT, f"front-{RANDOM}.png"),
        (PhotoKind.INGREDIENTS, f"ingredients-{RANDOM}.jpg"),
    ],
)
def test_own_upload_is_accepted(kind: PhotoKind, name: str) -> None:
    assert photo_key_problem(USER, CLIENT, kind, key(name=name)) is None


@pytest.mark.parametrize(
    "candidate",
    [
        pytest.param(key(user=OTHER_USER), id="another-user"),
        pytest.param(key(client=OTHER_CLIENT), id="another-contribution"),
        pytest.param(key(name=f"front-{RANDOM}.jpg"), id="another-kind"),
        pytest.param(key(name=f"nutrition-{RANDOM}.gif"), id="extension"),
        pytest.param(key(name="nutrition-0123.jpg"), id="short-random-part"),
        pytest.param(key(name=f"nutrition-{RANDOM.upper()}.jpg"), id="upper-case"),
        pytest.param(key(name=f"nutrition-{RANDOM}.jpg/../x.jpg"), id="traversal"),
        pytest.param(key() + "x", id="trailing"),
        pytest.param("x" + key(), id="leading"),
        pytest.param(f"products/123/front-{RANDOM}.jpg", id="public-key"),
    ],
)
def test_other_keys_are_refused(candidate: str) -> None:
    problem = photo_key_problem(USER, CLIENT, PhotoKind.NUTRITION, candidate)

    assert problem == "nutrition photo: not an upload of yours for this contribution"


def test_approved_photo_key_is_unique_per_contribution() -> None:
    contribution = Contribution(id=CLIENT, ean="6191507220214")

    assert product_photo_key(contribution, key(name=f"front-{RANDOM}.png")) == (
        f"products/6191507220214/contribution-{CLIENT.hex}.png"
    )


# ---------------------------------------------------------------- nutrition


def test_amounts_are_stored_as_the_decimals_typed() -> None:
    values = NutritionValues(
        energy_kj=1234.5,
        sugars_g=0.1,
        salt_g=1.0,
        fibre_g=None,
        protein_g=3,
        non_nutritive_sweeteners=False,
    )

    record = stored_nutrition(values)

    assert record == {
        "energy_kj": "1234.5",
        "sugars_g": "0.1",
        "salt_g": "1.0",
        "protein_g": "3.0",
        "non_nutritive_sweeteners": False,
    }
    assert json.loads(json.dumps(record)) == record


def test_facts_values_from_a_stored_record() -> None:
    values = facts_values({"sugars_g": "0.1", "salt_g": "1.0"})

    assert values["sugars_g"] == Decimal("0.1")
    assert values["salt_g"] == Decimal("1.0")
    assert values["energy_kj"] is None
    assert values["non_nutritive_sweeteners"] is None
    assert set(values) == {
        "energy_kj",
        "sugars_g",
        "saturated_fat_g",
        "total_fat_g",
        "salt_g",
        "fibre_g",
        "protein_g",
        "fvl_percent",
        "non_nutritive_sweeteners",
    }


def test_engine_input_takes_every_value() -> None:
    values = NutritionValues(sugars_g=100, fvl_percent=40, non_nutritive_sweeteners=True)

    nutrition = engine_input(values)

    assert (nutrition.sugars_g, nutrition.fvl_percent) == (100, 40)
    assert nutrition.non_nutritive_sweeteners is True
    assert nutrition.energy_kj is None


def _golden(path: Path) -> dict[str, Any]:
    case: dict[str, Any] = json.loads(path.read_text(encoding="utf-8"))
    return case


@pytest.mark.parametrize("path", GOLDEN, ids=[p.stem for p in GOLDEN])
def test_preview_matches_every_golden_case(path: Path) -> None:
    case = _golden(path)
    inputs = {k: v for k, v in case["input"].items() if k in NutritionValues.model_fields}
    try:
        values = NutritionValues(**inputs)
    except ValidationError:
        pytest.skip("input outside the request's ranges")

    preview = score_preview(Category(case["category"]), values)

    expected = case["expected"]
    assert preview.breakdown == expected
    assert preview.engine_version == ENGINE_VERSION
    assert preview.grade == (Grade(expected["grade"]) if "grade" in expected else None)
    assert preview.total == expected.get("score")


def test_there_are_golden_cases() -> None:
    assert len(GOLDEN) >= 20


# ---------------------------------------------------------------- requests


def contribution(**values: object) -> dict[str, object]:
    body: dict[str, object] = {
        "client_id": str(CLIENT),
        "ean": "6191507220214",
        "category": "general",
        "basis": "per_100g",
        "nutrition": {"energy_kj": 1000},
        "photos": {"front": "f", "nutrition": "n"},
        "parser_used": "rules",
    }
    return body | values


def test_blank_name_and_brand_are_not_given() -> None:
    body = ContributionCreate.model_validate(contribution(name="  ", brand=" Sicam "))

    assert (body.name, body.brand) == (None, "Sicam")
    assert body.ocr_text.model_dump() == {"front": None, "nutrition": None, "ingredients": None}


@pytest.mark.parametrize(
    "values",
    [
        pytest.param({"photos": {"front": "f"}}, id="no-nutrition-photo"),
        pytest.param({"photos": {"nutrition": "n"}}, id="no-front-photo"),
        pytest.param({"nutrition": {"sugars_g": 101}}, id="over-100-g"),
        pytest.param({"nutrition": {"energy_kj": -1}}, id="negative"),
        pytest.param({"nutrition": {"kcal": 100}}, id="unknown-nutrient"),
        pytest.param({"category": "snacks"}, id="category"),
        pytest.param({"parser_used": "magic"}, id="parser"),
        pytest.param({"name": "x" * 201}, id="long-name"),
        pytest.param({"ocr_text": {"front": "x" * 20_001}}, id="long-ocr"),
        pytest.param({"extra": 1}, id="unknown-field"),
    ],
)
def test_invalid_contributions(values: dict[str, object]) -> None:
    with pytest.raises(ValidationError):
        ContributionCreate.model_validate(contribution(**values))


def report(**values: object) -> dict[str, object]:
    body: dict[str, object] = {
        "client_id": "0123456789abcdef0123456789abcdef",
        "ean": "6191507220214",
        "reasons": ["grade"],
        "comment": None,
        "product_updated_at": "2026-11-12T18:00:00.000Z",
        "created_at": "2026-11-15T09:30:00.000Z",
    }
    return body | values


def test_report_as_the_app_sends_it() -> None:
    body = ReportCreate.model_validate(
        report(reasons=["other", "name", "other"], comment="  Wrong brand  ")
    )

    assert body.reasons == [ReportReason.NAME, ReportReason.OTHER]
    assert body.comment == "Wrong brand"
    assert body.created_at == datetime(2026, 11, 15, 9, 30, tzinfo=UTC)


@pytest.mark.parametrize(
    "values",
    [
        pytest.param({"reasons": []}, id="no-reason"),
        pytest.param({"reasons": ["taste"]}, id="unknown-reason"),
        pytest.param({"reasons": ["other"]}, id="other-without-comment"),
        pytest.param({"reasons": ["other"], "comment": "   "}, id="other-blank-comment"),
        pytest.param({"comment": "x" * 501}, id="long-comment"),
        pytest.param({"client_id": "not-hex"}, id="client-id"),
        pytest.param({"client_id": "0123456789ABCDEF0123456789ABCDEF"}, id="upper-hex"),
        pytest.param({"created_at": "2026-11-15T09:30:00"}, id="naive-time"),
        pytest.param({"extra": True}, id="unknown-field"),
    ],
)
def test_invalid_reports(values: dict[str, object]) -> None:
    with pytest.raises(ValidationError):
        ReportCreate.model_validate(report(**values))


def test_review_note_is_trimmed() -> None:
    assert ReviewDecision(note="  blurry photo ").note == "blurry photo"
    assert ReviewDecision(note=" ").note is None
    with pytest.raises(ValidationError):
        ReviewDecision(note="x" * 501)


def _settings(**values: object) -> Settings:
    base: dict[str, object] = {
        "database_url": "postgresql+asyncpg://user:pw@db.example:5432/qout",
        "redis_url": "redis://cache.example:6379/0",
    }
    return Settings(_env_file=None, **(base | values))  # type: ignore[arg-type]


def test_report_limit_defaults(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("REPORT_MAX_PER_IP", raising=False)
    monkeypatch.delenv("REPORT_WINDOW_SECONDS", raising=False)

    settings = _settings()

    assert (settings.report_max_per_ip, settings.report_window_seconds) == (20, 3600)


@pytest.mark.parametrize("values", [{"report_max_per_ip": 0}, {"report_window_seconds": 0}])
def test_report_limits_are_bounded(values: dict[str, int]) -> None:
    with pytest.raises(ValidationError):
        _settings(**values)
