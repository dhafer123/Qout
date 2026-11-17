"""The moderation review form: what it shows, and reading what the moderator typed back
into a `ContributionEdit`. Pure functions (no request, no database).

Amounts are typed as on the label: decimal point or comma, blank for "not declared".
"""

from collections.abc import Mapping
from dataclasses import dataclass, field
from decimal import Decimal
from typing import Any

from pydantic import ValidationError

from app.modules.contributions.models import Contribution
from app.modules.contributions.nutrition import FLAG, stored_nutrition
from app.modules.contributions.schemas import ContributionEdit


@dataclass(frozen=True)
class Nutrient:
    name: str
    label: str
    unit: str


NUTRIENTS = (
    Nutrient("energy_kj", "Energy", "kJ"),
    Nutrient("total_fat_g", "Fat", "g"),
    Nutrient("saturated_fat_g", "of which saturates", "g"),
    Nutrient("sugars_g", "Sugars", "g"),
    Nutrient("fibre_g", "Fibre", "g"),
    Nutrient("protein_g", "Protein", "g"),
    Nutrient("salt_g", "Salt", "g"),
    Nutrient("fvl_percent", "Fruit, vegetables, legumes", "%"),
)
SWEETENER_CHOICES = {"": None, "yes": True, "no": False}


@dataclass
class FormResult:
    edit: ContributionEdit | None
    """None when the form has errors."""
    errors: dict[str, str] = field(default_factory=dict)
    """Field name -> message."""


def form_values(contribution: Contribution) -> dict[str, str]:
    """The form's fields filled from a stored contribution."""
    values = {
        "name": contribution.name or "",
        "brand": contribution.brand or "",
        "category": contribution.category.value,
        "basis": contribution.basis.value,
    }
    for nutrient in NUTRIENTS:
        values[nutrient.name] = contribution.nutrition.get(nutrient.name) or ""
    flag = contribution.nutrition.get(FLAG)
    values[FLAG] = "" if flag is None else ("yes" if flag else "no")
    return values


def read_form(form: Mapping[str, Any]) -> FormResult:
    """Every field of the review form, as a full `ContributionEdit`."""
    errors: dict[str, str] = {}
    nutrition: dict[str, Any] = {}
    for nutrient in NUTRIENTS:
        raw = str(form.get(nutrient.name, "")).strip().replace(",", ".")
        if not raw:
            continue
        try:
            nutrition[nutrient.name] = float(raw)
        except ValueError:
            errors[nutrient.name] = "Not a number"
    sweetener = str(form.get(FLAG, ""))
    if sweetener not in SWEETENER_CHOICES:
        errors[FLAG] = "Choose yes, no or not stated"
    else:
        nutrition[FLAG] = SWEETENER_CHOICES[sweetener]
    if errors:
        return FormResult(None, errors)

    data = {
        "name": form.get("name", ""),
        "brand": form.get("brand", ""),
        "category": form.get("category"),
        "basis": form.get("basis"),
        "nutrition": nutrition,
    }
    try:
        return FormResult(ContributionEdit.model_validate(data))
    except ValidationError as error:
        for problem in error.errors():
            location = [str(part) for part in problem["loc"]]  # ("nutrition", "salt_g")
            errors.setdefault(location[-1] if location else "form", problem["msg"])
        return FormResult(None, errors)


def same_nutrition(left: Mapping[str, Any], right: Mapping[str, Any]) -> bool:
    """Same declared values: amounts compared as numbers (`"400"` is `"400.0"`)."""
    if left.keys() != right.keys():
        return False
    return all(
        left[key] == right[key] if key == FLAG else Decimal(left[key]) == Decimal(right[key])
        for key in left
    )


def changes(contribution: Contribution, edit: ContributionEdit) -> ContributionEdit | None:
    """Only what differs from the stored contribution; None if nothing does."""
    changed: dict[str, Any] = {}
    for name in ("name", "brand", "category", "basis"):
        if getattr(edit, name) != getattr(contribution, name):
            changed[name] = getattr(edit, name)
    if edit.nutrition is not None and not same_nutrition(
        stored_nutrition(edit.nutrition), contribution.nutrition
    ):
        changed["nutrition"] = edit.nutrition
    if not changed:
        return None
    return ContributionEdit.model_validate(
        {k: v.model_dump() if k == "nutrition" else v for k, v in changed.items()}
    )
