"""Admin panel (T31), pure parts: the review form, session checks, moderator edits, the
panel's settings and the `make-admin` command line."""

import runpy
import sys
import uuid
from typing import Any

import pytest
from pydantic import ValidationError

from app.admin import cli
from app.admin.auth import may_moderate, session_valid
from app.admin.forms import changes, form_values, read_form, same_nutrition
from app.core.config import DEV_ADMIN_SESSION_SECRET, Settings
from app.modules.auth.models import User, UserRole
from app.modules.contributions.models import Contribution, ReportStatus
from app.modules.contributions.moderation import ModerationService, submitted_snapshot
from app.modules.contributions.schemas import ContributionEdit
from app.modules.products.models import NutritionBasis
from app.modules.scoring import Category

REQUIRED = {"database_url": "postgresql+asyncpg://u:p@db:5432/q", "redis_url": "redis://r:6379/0"}
FORM = {
    "name": " Harissa ",
    "brand": "",
    "category": "general",
    "basis": "per_100g",
    "energy_kj": "400",
    "total_fat_g": "2",
    "saturated_fat_g": "0,5",
    "sugars_g": "4",
    "fibre_g": "",
    "protein_g": "3",
    "salt_g": "3",
    "fvl_percent": "60",
    "non_nutritive_sweeteners": "",
}


def contribution(**values: Any) -> Contribution:
    defaults: dict[str, Any] = {
        "name": "Harissa",
        "brand": None,
        "category": Category.GENERAL,
        "basis": NutritionBasis.PER_100G,
        "nutrition": {
            "energy_kj": "400",
            "total_fat_g": "2",
            "saturated_fat_g": "0.5",
            "sugars_g": "4",
            "protein_g": "3",
            "salt_g": "3",
            "fvl_percent": "60",
        },
    }
    return Contribution(**(defaults | values))


def settings(**overrides: object) -> Settings:
    return Settings(_env_file=None, **{**REQUIRED, **overrides})  # type: ignore[arg-type]


# ---------------------------------------------------------------- review form


def test_form_reads_amounts_as_typed_on_labels() -> None:
    result = read_form(FORM)

    assert result.errors == {}
    edit = result.edit
    assert edit is not None
    assert (edit.name, edit.brand, edit.category) == ("Harissa", None, Category.GENERAL)
    assert edit.nutrition is not None
    assert edit.nutrition.saturated_fat_g == 0.5  # decimal comma
    assert edit.nutrition.fibre_g is None  # blank: not declared
    assert edit.nutrition.non_nutritive_sweeteners is None


@pytest.mark.parametrize(("raw", "flag"), [("yes", True), ("no", False), ("", None)])
def test_sweetener_choice(raw: str, flag: bool | None) -> None:
    edit = read_form(FORM | {"non_nutritive_sweeteners": raw}).edit
    assert edit is not None
    assert edit.nutrition is not None
    assert edit.nutrition.non_nutritive_sweeteners is flag


@pytest.mark.parametrize(
    ("changes_", "field"),
    [
        ({"sugars_g": "4 g"}, "sugars_g"),
        ({"salt_g": "101"}, "salt_g"),
        ({"energy_kj": "-1"}, "energy_kj"),
        ({"non_nutritive_sweeteners": "maybe"}, "non_nutritive_sweeteners"),
        ({"category": "soup"}, "category"),
        ({"basis": ""}, "basis"),
        ({"name": "x" * 201}, "name"),
    ],
)
def test_form_errors_name_the_field(changes_: dict[str, str], field: str) -> None:
    result = read_form(FORM | changes_)
    assert result.edit is None
    assert field in result.errors


def test_form_without_a_category_or_basis() -> None:
    result = read_form({k: v for k, v in FORM.items() if k not in ("category", "basis")})
    assert result.edit is None
    assert result.errors == {"form": "Value error, category can't be removed"}


def test_form_values_from_a_contribution() -> None:
    values = form_values(
        contribution(nutrition={"salt_g": "1.2", "non_nutritive_sweeteners": True})
    )
    assert values["name"] == "Harissa"
    assert (values["brand"], values["sugars_g"]) == ("", "")
    assert (values["salt_g"], values["non_nutritive_sweeteners"]) == ("1.2", "yes")
    assert (
        form_values(contribution(nutrition={"non_nutritive_sweeteners": False}))[
            "non_nutritive_sweeteners"
        ]
        == "no"
    )


def test_unchanged_form_has_no_changes() -> None:
    edit = read_form(FORM).edit
    assert edit is not None
    assert changes(contribution(), edit) is None


def test_changes_keep_only_what_differs() -> None:
    edit = read_form(FORM | {"brand": "Cap Bon", "sugars_g": "5"}).edit
    assert edit is not None

    changed = changes(contribution(), edit)

    assert changed is not None
    assert changed.model_fields_set == {"brand", "nutrition"}
    assert changed.nutrition is not None
    assert changed.nutrition.sugars_g == 5


@pytest.mark.parametrize(
    ("left", "right", "same"),
    [
        ({"energy_kj": "400"}, {"energy_kj": "400.0"}, True),
        ({"energy_kj": "400"}, {"energy_kj": "401"}, False),
        ({"energy_kj": "400"}, {}, False),
        ({"non_nutritive_sweeteners": True}, {"non_nutritive_sweeteners": True}, True),
        ({"non_nutritive_sweeteners": True}, {"non_nutritive_sweeteners": False}, False),
    ],
)
def test_same_nutrition_compares_numbers(
    left: dict[str, Any], right: dict[str, Any], *, same: bool
) -> None:
    assert same_nutrition(left, right) is same


# ---------------------------------------------------------------- moderator edits


def test_an_edit_needs_something_to_change() -> None:
    with pytest.raises(ValidationError, match="nothing to change"):
        ContributionEdit.model_validate({})


@pytest.mark.parametrize("field", ["category", "basis", "nutrition"])
def test_required_fields_cannot_be_removed(field: str) -> None:
    with pytest.raises(ValidationError, match=f"{field} can't be removed"):
        ContributionEdit.model_validate({field: None})


def test_name_and_brand_can_be_cleared() -> None:
    edit = ContributionEdit.model_validate({"name": "  ", "brand": None})
    assert (edit.name, edit.brand) == (None, None)
    assert edit.model_fields_set == {"name", "brand"}


def test_submitted_snapshot_is_json() -> None:
    assert submitted_snapshot(contribution(brand="Cap Bon")) == {
        "name": "Harissa",
        "brand": "Cap Bon",
        "category": "general",
        "basis": "per_100g",
        "nutrition": contribution().nutrition,
    }


async def test_a_report_is_not_reopened() -> None:
    service = ModerationService(None, None, None)  # type: ignore[arg-type]
    with pytest.raises(ValueError, match="not reopened"):
        await service.decide_report(uuid.uuid4(), uuid.uuid4(), ReportStatus.OPEN)


# ---------------------------------------------------------------- sessions


@pytest.mark.parametrize(
    ("signed_in_at", "now", "valid"),
    [
        (1000.0, 1000.0, True),
        (1000, 1000 + 299, True),
        (1000.0, 1000.0 + 300, False),  # lifetime over
        (1000.0, 999.0, False),  # from the future
        (None, 1000.0, False),
        ("1000", 1000.0, False),
        (True, 1.0, False),
    ],
)
def test_session_lifetime(signed_in_at: object, now: float, *, valid: bool) -> None:
    assert session_valid(signed_in_at, now, 300) is valid


@pytest.mark.parametrize(
    ("role", "active", "allowed"),
    [
        (UserRole.ADMIN, True, True),
        (UserRole.ADMIN, False, False),
        (UserRole.CONTRIBUTOR, True, False),
    ],
)
def test_who_may_moderate(role: UserRole, *, active: bool, allowed: bool) -> None:
    user = User(email="a@example.tn", password_hash="x", role=role, is_active=active)
    assert may_moderate(user) is allowed
    assert may_moderate(None) is False


# ---------------------------------------------------------------- settings


def test_panel_defaults() -> None:
    config = settings()
    assert config.admin_session_secret.get_secret_value() == DEV_ADMIN_SESSION_SECRET
    assert (config.admin_session_ttl_seconds, config.admin_photo_url_ttl_seconds) == (28800, 300)
    assert config.deployed is False


def test_panel_secret_must_be_long() -> None:
    with pytest.raises(ValidationError, match="ADMIN_SESSION_SECRET must be at least 32"):
        settings(admin_session_secret="short")


DEPLOYED = {
    "app_env": "prod",
    "jwt_secret": "j" * 40,
    "s3_access_key": "prod-key",
    "s3_secret_key": "prod-secret",
}


@pytest.mark.parametrize(
    "secret", [DEV_ADMIN_SESSION_SECRET, "change-me-to-a-long-random-string-please", "j" * 40]
)
def test_deployed_panel_needs_its_own_secret(secret: str) -> None:
    with pytest.raises(ValidationError, match="ADMIN_SESSION_SECRET: set a real random secret"):
        settings(**DEPLOYED, admin_session_secret=secret)


def test_deployed_panel_with_a_real_secret() -> None:
    assert settings(**DEPLOYED, admin_session_secret="a" * 40).deployed is True


# ---------------------------------------------------------------- command line


async def test_make_admin_refuses_a_bad_email(capsys: pytest.CaptureFixture[str]) -> None:
    assert await cli.amain(["make-admin", "not an email"]) == 2
    assert "not an email address" in capsys.readouterr().err


def test_command_is_required() -> None:
    with pytest.raises(SystemExit):
        cli.parser().parse_args([])


def test_module_entry_point(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setattr(sys, "argv", ["python -m app.admin", "make-admin", "not an email"])
    with pytest.raises(SystemExit) as exit_info:
        runpy.run_module("app.admin", run_name="__main__")
    assert exit_info.value.code == 2
    assert "not an email address" in capsys.readouterr().err
