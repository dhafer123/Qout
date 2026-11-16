"""Download Open Food Facts nutrition-table photos of Tunisian products for the label
evaluation set (`eval/labels/README.md`).

    uv run python -m scripts.fetch_off_labels                   # from backend/
    uv run python -m scripts.fetch_off_labels --count 20 --out var/off-labels

Lists products made in Tunisia (barcode prefix 619) that OFF sells in Tunisia with a
selected nutrition photo, most scanned first (OFF's search service), then reads each
product (API) and downloads its nutrition photo full size. Waters are skipped (mineral
tables), so are photos smaller than `MIN_SIDE` pixels, products already in the evaluation
set or already downloaded, and more than `PER_BRAND` products of one brand.

Writes into `--out` (default `backend/var/off-labels/`, git-ignored):

- `inbox/<ean>.jpg`: the photo, to push to the phone's Label OCR inbox;
- `inbox/<ean>.json`: what the app puts into the label's ground truth template;
- `manifest.json`: every label with OFF's own values per 100 g, to cross-check the
  ground truth (OFF's values are typed by contributors: the photo is the truth).

Photos are © Open Food Facts contributors, CC BY-SA 3.0; they stay out of git, and each
label records its product page and photo URL.
"""

import argparse
import asyncio
import json
import logging
from collections import Counter
from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import httpx

from app.core.config import BACKEND_DIR, REPO_ROOT, get_settings
from app.modules.ingestion.off_client import OffClient, OffError, RateLimiter, RetryPolicy
from app.modules.ingestion.off_normaliser import OFF_IMAGES_URL, product_folder
from app.modules.products.images import ImageFetchError, UnusableImageError, fetch_image

logger = logging.getLogger("fetch_off_labels")

SEARCH_URL = "https://search.openfoodfacts.org/search"
SEARCH_QUERY = (
    'countries_tags:"en:tunisia" AND states_tags:"en:nutrition-photo-selected" AND code:619*'
)
PRODUCT_URL = "https://world.openfoodfacts.org/product"
OUT_DIR = BACKEND_DIR / "var" / "off-labels"
LABELS_DIR = REPO_ROOT / "eval" / "labels"
FIELDS = (
    "code",
    "product_name",
    "product_name_fr",
    "brands",
    "lang",
    "categories_tags",
    "images",
    "nutriments",
)
NUTRIMENTS = (
    "energy-kj_100g",
    "energy-kcal_100g",
    "fat_100g",
    "saturated-fat_100g",
    "carbohydrates_100g",
    "sugars_100g",
    "fiber_100g",
    "proteins_100g",
    "salt_100g",
    "sodium_100g",
)
MIN_SIDE = 800
"""Smaller photos are below what the app sends (camera photos reduced to 1600 px)."""
MAX_BYTES = 10 * 1024 * 1024
PER_BRAND = 2
PAGE_SIZE = 100
_PREFERRED_LANGS = ("fr", "ar", "en")
_SKIPPED_CATEGORIES = frozenset({"en:waters"})


@dataclass(frozen=True)
class NutritionPhoto:
    lang: str
    url: str
    width: int
    height: int


def nutrition_photo(ean: str, product: Mapping[str, Any]) -> NutritionPhoto | None:
    """The product's selected nutrition photo, full size: in the product's language
    first, then French, Arabic, English, any other. None if there is none at least
    `MIN_SIDE` pixels on its longest side."""
    images = product.get("images")
    if not isinstance(images, Mapping):
        return None
    langs = {key.removeprefix("nutrition_") for key in images if key.startswith("nutrition_")}
    lang = product.get("lang")
    order = [lang] if isinstance(lang, str) else []
    order += [*_PREFERRED_LANGS, *sorted(langs)]
    for candidate in dict.fromkeys(order):
        if candidate not in langs:
            continue
        photo = _photo(ean, candidate, images[f"nutrition_{candidate}"])
        if photo is not None and max(photo.width, photo.height) >= MIN_SIDE:
            return photo
    return None


def _photo(ean: str, lang: str, entry: object) -> NutritionPhoto | None:
    if not isinstance(entry, Mapping):
        return None
    rev, sizes = entry.get("rev"), entry.get("sizes")
    full = sizes.get("full") if isinstance(sizes, Mapping) else None
    if not isinstance(full, Mapping):
        return None
    width, height = full.get("w"), full.get("h")
    if not (str(rev).isdigit() and isinstance(width, int) and isinstance(height, int)):
        return None
    url = f"{OFF_IMAGES_URL}/{product_folder(ean)}/nutrition_{lang}.{rev}.full.jpg"
    return NutritionPhoto(lang=lang, url=url, width=width, height=height)


def brand(product: Mapping[str, Any]) -> str:
    """The first brand, lower case ("" when none), for the per-brand limit."""
    brands = product.get("brands")
    first = brands.split(",")[0] if isinstance(brands, str) else ""
    return first.strip().lower()


def skipped_category(product: Mapping[str, Any]) -> bool:
    tags = product.get("categories_tags")
    return isinstance(tags, list) and not _SKIPPED_CATEGORIES.isdisjoint(tags)


def name(product: Mapping[str, Any]) -> str | None:
    for key in ("product_name_fr", "product_name"):
        value = product.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def template(ean: str, product: Mapping[str, Any], photo: NutritionPhoto) -> dict[str, Any]:
    """Ground truth keys the app fills in for this photo (`inbox/<ean>.json`)."""
    brands = product.get("brands")
    first_brand = brands.split(",")[0].strip() if isinstance(brands, str) else ""
    return {
        "product": name(product),
        "brand": first_brand or None,
        "ean": ean,
        "source": "open-food-facts",
        "photo_url": photo.url,
    }


def manifest_entry(ean: str, product: Mapping[str, Any], photo: NutritionPhoto) -> dict[str, Any]:
    nutriments = product.get("nutriments")
    values = nutriments if isinstance(nutriments, Mapping) else {}
    return {
        **template(ean, product, photo),
        "product_url": f"{PRODUCT_URL}/{ean}",
        "photo_size": [photo.width, photo.height],
        "off_values": {key: values[key] for key in NUTRIMENTS if key in values},
    }


def known_eans(labels_dir: Path, manifest: Iterable[Mapping[str, Any]]) -> set[str]:
    """Products already in the evaluation set or already downloaded."""
    eans = {str(entry["ean"]) for entry in manifest}
    for path in labels_dir.glob("*.json"):
        ean = json.loads(path.read_text(encoding="utf-8")).get("ean")
        if isinstance(ean, str):
            eans.add(ean)
    return eans


def search_hits(body: object) -> tuple[list[str], int]:
    """(barcodes, page count) from a search response."""
    if not isinstance(body, Mapping) or not isinstance(body.get("hits"), list):
        raise ValueError("unexpected search response")
    codes = [str(hit["code"]) for hit in body["hits"] if isinstance(hit, Mapping) and "code" in hit]
    pages = body.get("page_count")
    return codes, pages if isinstance(pages, int) else 0


async def search(http: httpx.AsyncClient, page: int) -> tuple[list[str], int]:
    response = await http.get(
        SEARCH_URL,
        params={
            "q": SEARCH_QUERY,
            "fields": "code",
            "sort_by": "-unique_scans_n",
            "page": str(page),
            "page_size": str(PAGE_SIZE),
        },
    )
    response.raise_for_status()
    return search_hits(response.json())


@dataclass(frozen=True)
class Sources:
    off: OffClient
    http: httpx.AsyncClient
    """Search service and photo downloads (OFF's User-Agent)."""
    retry: RetryPolicy
    limiter: RateLimiter | None = None


async def fetch(count: int, out: Path, labels_dir: Path, sources: Sources) -> int:
    """Download up to `count` new photos into `out`; the number downloaded."""
    inbox = out / "inbox"
    inbox.mkdir(parents=True, exist_ok=True)
    manifest_path = out / "manifest.json"
    manifest: list[dict[str, Any]] = (
        json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else []
    )
    known = known_eans(labels_dir, manifest)
    brands = Counter(str(entry.get("brand") or "").lower() for entry in manifest)
    added = 0
    page, pages = 1, 1
    while added < count and page <= pages:
        codes, pages = await search(sources.http, page)
        page += 1
        for ean in codes:
            if added >= count:
                break
            if ean in known:
                continue
            known.add(ean)
            try:
                product = await sources.off.get_product(ean, fields=FIELDS)
                if product is None or skipped_category(product):
                    continue
                photo = nutrition_photo(ean, product)
                if photo is None or brands[brand(product)] >= PER_BRAND:
                    continue
                image = await fetch_image(
                    sources.http,
                    photo.url,
                    retry=sources.retry,
                    max_bytes=MAX_BYTES,
                    limiter=sources.limiter,
                )
            except (OffError, UnusableImageError, ImageFetchError) as error:
                logger.warning("%s skipped: %s", ean, error)
                continue
            (inbox / f"{ean}.{image.extension}").write_bytes(image.data)
            _write_json(inbox / f"{ean}.json", template(ean, product, photo))
            manifest.append(manifest_entry(ean, product, photo))
            _write_json(manifest_path, manifest)
            brands[brand(product)] += 1
            added += 1
            print(f"{added:3}/{count} {ean} {name(product)} ({photo.width}x{photo.height})")
    print(f"{out}: {added} new photos, {len(manifest)} in the manifest")
    return added


def _write_json(path: Path, data: object) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


async def main(count: int, out: Path) -> int:
    settings = get_settings()
    headers = {"User-Agent": settings.off_user_agent}
    async with (
        OffClient.from_settings(settings) as off,
        httpx.AsyncClient(headers=headers, timeout=30) as http,
    ):
        sources = Sources(
            off=off,
            http=http,
            retry=RetryPolicy(max_retries=settings.off_max_retries),
            limiter=RateLimiter(settings.off_rate_limit_per_minute),
        )
        return await fetch(count, out, LABELS_DIR, sources)


if __name__ == "__main__":
    logging.basicConfig(level=logging.WARNING, format="%(message)s")
    cli = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    cli.add_argument("--count", type=int, default=60, help="new photos to download (60)")
    cli.add_argument("--out", type=Path, default=OUT_DIR, help="output folder")
    args = cli.parse_args()
    asyncio.run(main(args.count, args.out))
