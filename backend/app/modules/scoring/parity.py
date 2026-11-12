"""Parity check between the Python and Dart Nutri-Score engines.

    uv run python -m app.modules.scoring.parity generate          # rewrite inputs.json
    uv run python -m app.modules.scoring.parity run OUT.json      # Python results
    (cd app && dart run tool/scoring_parity.dart OUT.json)        # Dart results
    uv run python -m app.modules.scoring.parity compare A.json B.json

`scoring-spec/parity/inputs.json` is generated deterministically (fixed seed) and
committed: every golden case, values on/just around every threshold of every table, and
random products, including missing fields. Both engines must give identical results for
every case (CI job `scoring-parity`).
"""

import argparse
import json
import random
import sys
from collections.abc import Iterator, Mapping, Sequence
from decimal import Decimal
from pathlib import Path
from typing import Any

from app.core.config import REPO_ROOT
from app.modules.scoring import tables as t
from app.modules.scoring.engine import REQUIRED_FIELDS, score
from app.modules.scoring.models import Category
from app.modules.scoring.spec_json import expected_to_spec, nutrition_input_from_spec

PARITY_DIR = REPO_ROOT / "scoring-spec" / "parity"
INPUTS_PATH = PARITY_DIR / "inputs.json"
GOLDEN_DIR = REPO_ROOT / "scoring-spec" / "golden"

SEED = 20261112
RANDOM_CASES_PER_CATEGORY = 600
DELTA = Decimal("0.001")
FATS_TOTALS = (Decimal("0.3"), Decimal(10), Decimal("37.5"), Decimal(50), Decimal(100))

Case = dict[str, Any]

# (table, realistic upper bound for random values) per spec field and category.
_FOOD = {
    "energy_kj": (t.ENERGY_KJ, 4000),
    "sugars_g": (t.SUGARS_G, 60),
    "saturated_fat_g": (t.SATURATED_FAT_G, 15),
    "salt_g": (t.SALT_G, 5),
    "fibre_g": (t.FIBRE_G, 10),
    "protein_g": (t.PROTEIN_G, 25),
    "fvl_percent": (t.FVL_PERCENT, 100),
}
_FATS = {
    "sugars_g": (t.SUGARS_G, 60),
    "salt_g": (t.SALT_G, 5),
    "fibre_g": (t.FIBRE_G, 10),
    "protein_g": (t.PROTEIN_G, 25),
    "fvl_percent": (t.FVL_PERCENT, 100),
}
_BEVERAGE = {
    "energy_kj": (t.BEVERAGE_ENERGY_KJ, 450),
    "sugars_g": (t.BEVERAGE_SUGARS_G, 14),
    "saturated_fat_g": (t.BEVERAGE_SATURATED_FAT_G, 11),
    "salt_g": (t.SALT_G, 5),
    "fibre_g": (t.FIBRE_G, 9),
    "protein_g": (t.BEVERAGE_PROTEIN_G, 4),
    "fvl_percent": (t.BEVERAGE_FVL_PERCENT, 100),
}
_FIELDS: Mapping[Category, Mapping[str, tuple[t.PointTable, int]]] = {
    Category.GENERAL: _FOOD,
    Category.RED_MEAT: _FOOD,
    Category.CHEESE: _FOOD,
    Category.FATS_OILS_NUTS_SEEDS: _FATS,
    Category.BEVERAGE: _BEVERAGE,
}
_LIMITS = {"energy_kj": Decimal(4000)}  # every other field: 100 (g or %)


# ---------------------------------------------------------------- generation


def generate(seed: int = SEED) -> list[Case]:
    """All parity cases, in a stable order."""
    rng = random.Random(seed)  # noqa: S311 - test data, not security
    cases = list(_golden_cases())
    for category in _FIELDS:
        cases += _boundary_cases(category, rng)
        cases += _random_cases(category, rng)
    cases.append({"id": "water-000", "category": "water", "input": {}})
    return cases


def _golden_cases() -> Iterator[Case]:
    for path in sorted(GOLDEN_DIR.glob("*.json")):
        golden = json.loads(path.read_text(encoding="utf-8"))
        yield {
            "id": f"golden--{golden['id']}",
            "category": golden["category"],
            "input": golden["input"],
        }


def _boundary_cases(category: Category, rng: random.Random) -> list[Case]:
    """Each threshold of each table, and just below/above it; other fields random."""
    values: list[tuple[str, Decimal]] = []
    for field, (table, _) in _FIELDS[category].items():
        values += [(field, v) for v in _around(table.thresholds)]
    if category is Category.FATS_OILS_NUTS_SEEDS:
        # energy from saturates = saturates x 37: thresholds / 37 to 3 decimals.
        per_37 = [
            (th / t.KJ_PER_G_SATURATED_FAT).quantize(DELTA)
            for th in t.ENERGY_FROM_SATURATES_KJ.thresholds
        ]
        values += [("saturated_fat_g", v) for v in _around(per_37)]
    cases = []
    for n, (field, value) in enumerate(values):
        product = _random_product(category, rng)
        product[field] = value
        if category is Category.FATS_OILS_NUTS_SEEDS and field == "saturated_fat_g":
            product["total_fat_g"] = max(product["total_fat_g"], value)
        cases.append(_case(f"{category.value}-boundary-{n:04d}", category, product))
    if category is Category.FATS_OILS_NUTS_SEEDS:
        cases += _ratio_cases(rng)
    return cases


def _ratio_cases(rng: random.Random) -> list[Case]:
    """Saturates/fat ratio exactly on, and just around, each threshold (strict table)."""
    cases = []
    n = 0
    for total in FATS_TOTALS:
        for threshold in t.SATURATED_FAT_RATIO_PERCENT.thresholds:
            exact = threshold * total / 100
            for saturated in (exact - DELTA, exact, exact + DELTA):
                product = _random_product(Category.FATS_OILS_NUTS_SEEDS, rng)
                product.update(total_fat_g=total, saturated_fat_g=saturated)
                cases.append(
                    _case(
                        f"fats_oils_nuts_seeds-ratio-{n:04d}",
                        Category.FATS_OILS_NUTS_SEEDS,
                        product,
                    )
                )
                n += 1
    return cases


def _random_cases(category: Category, rng: random.Random) -> list[Case]:
    cases = []
    for n in range(RANDOM_CASES_PER_CATEGORY):
        product = _random_product(category, rng)
        roll = rng.random()
        if roll < 0.04:
            for field in rng.sample(REQUIRED_FIELDS[category], rng.randint(1, 2)):
                del product[field]
        elif roll < 0.05 and category is Category.FATS_OILS_NUTS_SEEDS:
            product["total_fat_g"] = Decimal(0)
        cases.append(_case(f"{category.value}-random-{n:04d}", category, product))
    return cases


def _random_product(category: Category, rng: random.Random) -> dict[str, Any]:
    product: dict[str, Any] = {
        field: _amount(rng, high) for field, (_, high) in _FIELDS[category].items()
    }
    if category is Category.FATS_OILS_NUTS_SEEDS:
        total = max(_amount(rng, 100), Decimal("0.1"))
        product["total_fat_g"] = total
        product["saturated_fat_g"] = min(_amount(rng, 100), total)
    if category is Category.BEVERAGE:
        product["non_nutritive_sweeteners"] = rng.random() < 0.3
    return product


def _amount(rng: random.Random, high: int) -> Decimal:
    """A value in [0, high] with 0 to 3 decimals."""
    places = rng.randint(0, 3)
    return Decimal(rng.randint(0, high * 10**places)).scaleb(-places)


def _around(thresholds: Sequence[Decimal]) -> Iterator[Decimal]:
    """Each threshold and DELTA either side (every threshold is well above DELTA)."""
    for threshold in thresholds:
        yield from (threshold - DELTA, threshold, threshold + DELTA)


def _case(case_id: str, category: Category, product: Mapping[str, Any]) -> Case:
    def number(field: str, value: Any) -> Any:
        if isinstance(value, Decimal):
            return float(min(value, _LIMITS.get(field, Decimal(100))))
        return value

    return {
        "id": case_id,
        "category": category.value,
        "input": {f: number(f, v) for f, v in product.items()},
    }


def render_inputs(cases: Sequence[Case]) -> str:
    """One case per line, so changes show up as readable diffs."""
    lines = ",\n".join(json.dumps(case, sort_keys=True) for case in cases)
    return f'{{"seed": {SEED}, "cases": [\n{lines}\n]}}\n'


# ---------------------------------------------------------------- running and comparing


def run(cases: Sequence[Case]) -> dict[str, Any]:
    """Python engine results for every case, in the golden `expected` format."""
    return {
        case["id"]: expected_to_spec(
            score(Category(case["category"]), nutrition_input_from_spec(case["input"]))
        )
        for case in cases
    }


def render_results(engine: str, results: Mapping[str, Any]) -> str:
    return json.dumps({"engine": engine, "results": results}, sort_keys=True, indent=0) + "\n"


def compare(first: Mapping[str, Any], second: Mapping[str, Any], limit: int = 20) -> list[str]:
    """Differences between two results files ({"engine", "results"}); empty if identical."""
    a, b = first["results"], second["results"]
    names = f"{first['engine']} vs {second['engine']}"
    problems = [f"only in {first['engine']}: {i}" for i in sorted(set(a) - set(b))]
    problems += [f"only in {second['engine']}: {i}" for i in sorted(set(b) - set(a))]
    problems += [
        f"{case_id} ({names}): {a[case_id]} != {b[case_id]}"
        for case_id in sorted(set(a) & set(b))
        if a[case_id] != b[case_id]
    ]
    if len(problems) > limit:
        problems = [*problems[:limit], f"... and {len(problems) - limit} more"]
    return problems


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.modules.scoring.parity")
    commands = parser.add_subparsers(dest="command", required=True)
    generate_cmd = commands.add_parser("generate", help="rewrite the parity inputs")
    generate_cmd.add_argument("--output", type=Path, default=INPUTS_PATH)
    run_cmd = commands.add_parser("run", help="score the inputs with the Python engine")
    run_cmd.add_argument("output", type=Path)
    run_cmd.add_argument("--inputs", type=Path, default=INPUTS_PATH)
    compare_cmd = commands.add_parser("compare", help="compare two results files")
    compare_cmd.add_argument("first", type=Path)
    compare_cmd.add_argument("second", type=Path)
    args = parser.parse_args(argv)

    if args.command == "generate":
        cases = generate()
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(render_inputs(cases), encoding="utf-8", newline="\n")
        sys.stdout.write(f"wrote {len(cases)} cases to {args.output}\n")
        return 0
    if args.command == "run":
        cases = json.loads(args.inputs.read_text(encoding="utf-8"))["cases"]
        args.output.write_text(render_results("python", run(cases)), encoding="utf-8")
        sys.stdout.write(f"scored {len(cases)} cases into {args.output}\n")
        return 0
    first = json.loads(args.first.read_text(encoding="utf-8"))
    second = json.loads(args.second.read_text(encoding="utf-8"))
    problems = compare(first, second)
    for problem in problems:
        sys.stdout.write(f"{problem}\n")
    if problems:
        return 1
    sys.stdout.write(f"identical: {len(first['results'])} cases\n")
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
