"""Record Open Food Facts responses as test fixtures (the only network access in T13).

    uv run python scripts/record_off_fixtures.py            # all fixtures
    uv run python scripts/record_off_fixtures.py NAME ...   # only some

Each fixture is `tests/fixtures/off/<name>.json`: {"ean", "recorded_at", "product"}, where
`product` is what `OffClient.get_product` returned (None for an unknown product). Uses the
real client, so the configured User-Agent and rate limit apply. Tests never call OFF.
"""

import asyncio
import json
import sys
from datetime import UTC, datetime

from app.core.config import BACKEND_DIR, get_settings
from app.modules.ingestion.off_client import OffClient

FIXTURES_DIR = BACKEND_DIR / "tests" / "fixtures" / "off"

# name -> EAN. Names say what the fixture is for, not what the product is.
PRODUCTS = {
    "general-complete-spread": "3017620422003",
    "general-per-serving-biscuits": "8410376009392",
    "general-stock-concentrate": "7613039829264",
    "general-no-category": "6111018501480",
    "general-infant-formula": "7613037792935",
    "beverage-sugary-cola": "5449000054227",
    "beverage-sweetened-cola-zero": "5449000133328",
    "beverage-orange-soda": "5449000052926",
    "beverage-energy-drink": "90162602",
    "water-tunisian-safia": "6194001800111",
    "water-tunisian-hayet": "6194039501011",
    "cheese-tunisian-processed": "6191513502014",
    "cheese-tunisian-spread": "6191513502052",
    "cheese-tunisian-ricotta": "6191585700226",
    "fats-tunisian-olive-oil": "6191509900855",
    "fats-tunisian-olive-oil-2": "6191509900671",
    "red-meat-beef-patty": "3181232220286",
    "not-found": "6190000000019",
}


async def record(names: list[str]) -> None:
    FIXTURES_DIR.mkdir(parents=True, exist_ok=True)
    async with OffClient.from_settings(get_settings()) as client:
        for name in names:
            ean = PRODUCTS[name]
            product = await client.get_product(ean)
            fixture = {
                "ean": ean,
                "recorded_at": datetime.now(UTC).date().isoformat(),
                "product": product,
            }
            path = FIXTURES_DIR / f"{name}.json"
            path.write_text(
                json.dumps(fixture, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
                encoding="utf-8",
                newline="\n",
            )
            status = "not found" if product is None else product.get("product_name", "?")
            sys.stdout.write(f"{name}: {ean} -> {status}\n")


if __name__ == "__main__":
    selected = sys.argv[1:] or list(PRODUCTS)
    unknown = sorted(set(selected) - set(PRODUCTS))
    if unknown:
        sys.exit(f"unknown fixtures: {', '.join(unknown)}")
    asyncio.run(record(selected))
