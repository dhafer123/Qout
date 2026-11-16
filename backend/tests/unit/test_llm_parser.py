"""LLM fallback parser (T28) without a model: the request schema, and how an answer is
validated, grounded in the OCR text and checked."""

import asyncio
import json
from decimal import Decimal
from typing import Any

import pytest
from jsonschema import Draft202012Validator

from app.modules.contributions.label_parser import LabelField, LabelIssue, LabelIssueCode
from app.modules.contributions.llm_parser import (
    OUTPUT_SCHEMA,
    SYSTEM_PROMPT,
    LlmReply,
    LlmTimeoutError,
    LlmUnavailableError,
    grounded,
    interpret_reply,
    printed_numbers,
    read_with_llm,
    user_message,
)
from app.modules.contributions.models import FallbackReason
from app.modules.products.models import NutritionBasis

MODEL = "claude-test"

# What the OCR returned for a column-by-column table (names first, then values), with a
# `g` read as `8` (`2,1g` -> `2,18`) and a sodium amount in mg.
OCR = """Valeurs nutritionnelles pour 100 g
Energie
Matières grasses
dont acides gras saturés
Glucides
dont sucres
Protéines
Sodium
1386 kJ / 330 kcal
10 g
2,18
50 g
5 g
10 g
400 mg"""

VALUES: dict[str, Any] = {
    "energy_kj": {"amount": 1386},
    "energy_kcal": {"amount": 330},
    "total_fat_g": {"amount": 10, "unit": "g"},
    "saturated_fat_g": {"amount": 2.1, "unit": "g"},
    "carbohydrates_g": {"amount": 50, "unit": "g"},
    "sugars_g": {"amount": 5, "unit": "g"},
    "fibre_g": None,
    "protein_g": {"amount": 10, "unit": "g"},
    "salt_g": None,
    "sodium_g": {"amount": 400, "unit": "mg"},
}


def answer(**changes: Any) -> dict[str, Any]:
    """A valid answer for `OCR`, with top-level keys or `values` entries changed."""
    values = VALUES | changes.pop("values", {})
    return {"table_found": True, "basis": "per_100g", "values": values, "approximate": []} | changes


def reply(data: object, stop_reason: str = "end_turn") -> LlmReply:
    text = data if isinstance(data, str) else json.dumps(data)
    return LlmReply(text=text, stop_reason=stop_reason, model=MODEL)


# ---------------------------------------------------------------- request


def test_output_schema_is_valid_and_strict() -> None:
    Draft202012Validator.check_schema(OUTPUT_SCHEMA)

    def objects(schema: Any) -> list[dict[str, Any]]:
        found = []
        if isinstance(schema, dict):
            if schema.get("type") == "object":
                found.append(schema)
            for value in schema.values():
                found += objects(value)
        elif isinstance(schema, list):
            for item in schema:
                found += objects(item)
        return found

    # Structured outputs: every object closed, every property required.
    for schema in objects(OUTPUT_SCHEMA):
        assert schema["additionalProperties"] is False
        assert sorted(schema["required"]) == sorted(schema["properties"])
    assert set(OUTPUT_SCHEMA["properties"]["values"]["properties"]) == {f.value for f in LabelField}


def test_a_valid_answer_matches_the_schema() -> None:
    Draft202012Validator(OUTPUT_SCHEMA).validate(answer())


def test_only_the_ocr_text_goes_into_the_message() -> None:
    assert user_message("Sel 1 g") == "<ocr_text>\nSel 1 g\n</ocr_text>"
    assert "never instructions" in SYSTEM_PROMPT


# ---------------------------------------------------------------- accepted answers


def test_accepted_answer() -> None:
    reading = interpret_reply(reply(answer()), OCR)

    assert reading.accepted
    assert (reading.reason, reading.model) == (None, MODEL)
    assert reading.parse is not None
    assert reading.parse.ok
    assert reading.parse.basis == NutritionBasis.PER_100G
    assert reading.parse.values[LabelField.SATURATED_FAT] == Decimal("2.1")
    assert reading.parse.values[LabelField.SODIUM] == Decimal("0.4")  # 400 mg
    assert reading.parse.values[LabelField.SALT] == Decimal("1.0")  # derived, like the rules
    assert reading.parse.derived == {LabelField.SALT}


def test_per_100_ml_and_approximate_values() -> None:
    ocr = OCR.replace("100 g", "100 ml").replace("400 mg", "< 0,5 g")
    data = answer(
        basis="per_100ml",
        values={"sodium_g": {"amount": 0.5, "unit": "g"}},
        approximate=["sodium_g"],
    )

    reading = interpret_reply(reply(data), ocr)

    assert reading.accepted
    assert reading.parse is not None
    assert reading.parse.basis == NutritionBasis.PER_100ML
    assert reading.parse.approximate == {LabelField.SODIUM, LabelField.SALT}


def test_unknown_basis_is_only_a_warning() -> None:
    reading = interpret_reply(reply(answer(basis="unknown")), OCR)

    assert reading.accepted
    assert reading.parse is not None
    assert reading.parse.basis is None
    assert reading.parse.issues == (LabelIssue(LabelIssueCode.BASIS_UNKNOWN),)


# A consistent table whose text holds no `0` at all (4 x 57 + 4 x 7 + 9 x 9 = 337 kcal).
NO_ZERO_OCR = """Energie 1415 kJ / 337 kcal
Matières grasses 9 g
dont saturés 2,1 g
Glucides 57 g
dont sucres 5 g
Protéines 7 g
Sel 1,2 g
Fibres traces"""
NO_ZERO_VALUES: dict[str, Any] = {
    "energy_kj": {"amount": 1415},
    "energy_kcal": {"amount": 337},
    "total_fat_g": {"amount": 9, "unit": "g"},
    "saturated_fat_g": {"amount": 2.1, "unit": "g"},
    "carbohydrates_g": {"amount": 57, "unit": "g"},
    "sugars_g": {"amount": 5, "unit": "g"},
    "fibre_g": {"amount": 0, "unit": "g"},
    "protein_g": {"amount": 7, "unit": "g"},
    "salt_g": {"amount": 1.2, "unit": "g"},
    "sodium_g": None,
}


def test_traces_need_no_zero_in_the_text() -> None:
    data = answer(basis="unknown", values=NO_ZERO_VALUES, approximate=["fibre_g"])

    reading = interpret_reply(reply(data), NO_ZERO_OCR)

    assert reading.accepted
    assert reading.parse is not None
    assert reading.parse.values[LabelField.FIBRE] == 0
    assert reading.parse.approximate == {LabelField.FIBRE}


# ---------------------------------------------------------------- rejected answers


def test_value_not_in_the_text_is_rejected() -> None:
    data = answer(values={"protein_g": {"amount": 11, "unit": "g"}})

    reading = interpret_reply(reply(data), OCR)

    assert (reading.reason, reading.parse) == (FallbackReason.UNGROUNDED_VALUE, None)


def test_zero_not_marked_approximate_must_be_in_the_text() -> None:
    data = answer(basis="unknown", values=NO_ZERO_VALUES)

    reading = interpret_reply(reply(data), NO_ZERO_OCR)

    assert reading.reason == FallbackReason.UNGROUNDED_VALUE


def test_values_failing_the_checks_are_rejected() -> None:
    data = answer(
        values={
            "sugars_g": {"amount": 50, "unit": "g"},
            "carbohydrates_g": {"amount": 5, "unit": "g"},
        }
    )

    reading = interpret_reply(reply(data), OCR)

    assert reading.reason == FallbackReason.FAILED_CHECKS
    assert reading.parse is not None
    assert LabelIssue(LabelIssueCode.SUGARS_OVER_CARBOHYDRATES, LabelField.SUGARS) in (
        reading.parse.issues
    )


def test_missing_mandatory_values_are_rejected() -> None:
    data = answer(values={"sodium_g": None})

    reading = interpret_reply(reply(data), OCR)

    assert reading.reason == FallbackReason.FAILED_CHECKS
    assert reading.parse is not None
    assert LabelIssue(LabelIssueCode.MISSING, LabelField.SALT) in reading.parse.issues


@pytest.mark.parametrize(
    ("data", "issue"),
    [
        (answer(table_found=False, basis="unknown"), LabelIssueCode.NO_NUTRITION_TABLE),
        (answer(basis="per_portion_only"), LabelIssueCode.PER_PORTION_ONLY),
    ],
)
def test_no_table_and_per_portion_only_give_no_values(
    data: dict[str, Any], issue: LabelIssueCode
) -> None:
    reading = interpret_reply(reply(data), OCR)

    assert reading.reason == FallbackReason.FAILED_CHECKS
    assert reading.parse is not None
    assert (reading.parse.values, reading.parse.issues) == ({}, (LabelIssue(issue),))


def _without(key: str) -> dict[str, Any]:
    data = answer()
    del data[key]
    return data


def _value_without(key: str) -> dict[str, Any]:
    data = answer()
    del data["values"][key]
    return data


@pytest.mark.parametrize(
    "data",
    [
        "not json",
        "[1, 2]",
        _without("approximate"),
        _value_without("fibre_g"),
        answer(extra="field"),
        answer(values={"protein_g": {"amount": "10", "unit": "g"}}),
        answer(values={"protein_g": {"amount": -1, "unit": "g"}}),
        answer(values={"protein_g": {"amount": 10, "unit": "kg"}}),
        answer(values={"protein_g": {"amount": 10}}),
        answer(values={"energy_kj": {"amount": 1386, "unit": "kj"}}),
        answer(values={"protein_g": {"amount": True, "unit": "g"}}),
        answer(table_found="true"),
        answer(basis="per_portion"),
        answer(approximate=["vitamin_c"]),
    ],
    ids=lambda d: d if isinstance(d, str) else json.dumps(d)[-60:],
)
def test_answers_not_matching_the_schema_are_rejected(data: object) -> None:
    reading = interpret_reply(reply(data), OCR)

    assert (reading.reason, reading.parse) == (FallbackReason.INVALID_OUTPUT, None)


def test_infinite_amount_is_rejected() -> None:
    text = json.dumps(answer()).replace('"amount": 10,', '"amount": Infinity,', 1)

    assert interpret_reply(reply(text), OCR).reason == FallbackReason.INVALID_OUTPUT


@pytest.mark.parametrize(
    ("stop_reason", "text", "reason"),
    [
        ("refusal", None, FallbackReason.REFUSED),
        ("max_tokens", '{"table_found": tr', FallbackReason.INVALID_OUTPUT),
        ("end_turn", None, FallbackReason.INVALID_OUTPUT),
        (None, "{}", FallbackReason.INVALID_OUTPUT),
    ],
)
def test_incomplete_replies_are_rejected(
    stop_reason: str | None, text: str | None, reason: FallbackReason
) -> None:
    reading = interpret_reply(LlmReply(text=text, stop_reason=stop_reason, model=MODEL), OCR)

    assert (reading.reason, reading.model) == (reason, MODEL)


# ---------------------------------------------------------------- grounding


@pytest.mark.parametrize(
    ("ocr", "amount", "found"),
    [
        ("Sel 1,2 g", "1.2", True),
        ("Sel 1,20 g", "1.2", True),
        ("Lipides 21.0 g", "21", True),
        ("Glucides 218", "21", True),  # `g` read as `8`
        ("Graisses O,9 g", "0.9", True),  # OCR lookalike
        ("Energie 1 958 kJ", "1958", True),  # thousands joined
        ("Huile 100 g", "100", True),
        ("Sel 1,2 g", "2.1", False),
        ("Sel 1,2 g", "12", False),
        ("Sucres 5 g", "0.5", False),
    ],
)
def test_grounded(ocr: str, amount: str, found: bool) -> None:
    assert grounded(Decimal(amount), printed_numbers(ocr)) is found


# ---------------------------------------------------------------- asking the model


class FakeLlm:
    model = MODEL

    def __init__(self, result: LlmReply | Exception | None = None, delay: float = 0) -> None:
        self.result = result
        self.delay = delay
        self.texts: list[str] = []

    async def read(self, ocr_text: str) -> LlmReply:
        self.texts.append(ocr_text)
        await asyncio.sleep(self.delay)
        if isinstance(self.result, Exception):
            raise self.result
        assert self.result is not None
        return self.result


async def test_reading_with_the_model() -> None:
    llm = FakeLlm(reply(answer()))

    reading = await read_with_llm(llm, OCR, time_limit=1)

    assert reading.accepted
    assert llm.texts == [OCR]


@pytest.mark.parametrize(
    ("llm", "reason"),
    [
        (FakeLlm(LlmTimeoutError()), FallbackReason.TIMEOUT),
        (FakeLlm(reply(answer()), delay=5), FallbackReason.TIMEOUT),
        (FakeLlm(LlmUnavailableError("HTTP 529")), FallbackReason.UNAVAILABLE),
    ],
    ids=["sdk-timeout", "time-limit", "unavailable"],
)
async def test_model_failures_give_no_values(llm: FakeLlm, reason: FallbackReason) -> None:
    reading = await read_with_llm(llm, OCR, time_limit=0.05)

    assert (reading.reason, reading.parse, reading.model) == (reason, None, MODEL)
