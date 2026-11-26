"""Nutrition5k (Google, CC BY 4.0): dishes with measured grams and nutrients per ingredient.

Used for grams (T50), not for segmentation: it has no masks. A fixed sample of dishes
with an overhead photo is pinned in `data/nutrition5k_sample.json` (dish ids and the
bucket's MD5 of every file), so every fetch gets exactly the same files.
"""

import base64
import csv
import io
import json
import random
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Literal

import httpx

from qout_ml.data.download import RemoteFile
from qout_ml.paths import ML_ROOT

Split = Literal["train", "test"]

BUCKET = "nutrition5k_dataset"
BASE_URL = f"https://storage.googleapis.com/{BUCKET}/nutrition5k_dataset"
LIST_URL = f"https://storage.googleapis.com/storage/v1/b/{BUCKET}/o"
OBJECT_PREFIX = "nutrition5k_dataset/"
OVERHEAD_DIR = "imagery/realsense_overhead"
DISH_METADATA = ("metadata/dish_metadata_cafe1.csv", "metadata/dish_metadata_cafe2.csv")
METADATA_FILES = (*DISH_METADATA, "metadata/ingredients_metadata.csv")
SPLIT_FILES: dict[Split, str] = {
    "train": "dish_ids/splits/rgb_train_ids.txt",
    "test": "dish_ids/splits/rgb_test_ids.txt",
}
MANIFEST_FILE = ML_ROOT / "data" / "nutrition5k_sample.json"
LOCAL_DIR = "nutrition5k"

_DISH_FIELDS = 6
_INGREDIENT_FIELDS = 7


@dataclass(frozen=True)
class Ingredient:
    ingredient_id: str
    name: str
    grams: float
    calories: float
    fat: float
    carb: float
    protein: float


@dataclass(frozen=True)
class Dish:
    dish_id: str
    calories: float
    mass: float
    fat: float
    carb: float
    protein: float
    ingredients: tuple[Ingredient, ...]


def parse_dish_metadata(text: str) -> list[Dish]:
    """Rows: dish id, kcal, grams, fat, carb, protein, then 7 fields per ingredient."""
    dishes = []
    for line_number, row in enumerate(csv.reader(io.StringIO(text)), start=1):
        if not row:
            continue
        extra = len(row) - _DISH_FIELDS
        if extra < 0 or extra % _INGREDIENT_FIELDS:
            msg = f"line {line_number} ({row[0]}): unexpected number of fields ({len(row)})"
            raise ValueError(msg)
        ingredients = tuple(
            Ingredient(
                ingredient_id=row[i],
                name=row[i + 1],
                grams=float(row[i + 2]),
                calories=float(row[i + 3]),
                fat=float(row[i + 4]),
                carb=float(row[i + 5]),
                protein=float(row[i + 6]),
            )
            for i in range(_DISH_FIELDS, len(row), _INGREDIENT_FIELDS)
        )
        calories, mass, fat, carb, protein = (float(value) for value in row[1:_DISH_FIELDS])
        dishes.append(Dish(row[0], calories, mass, fat, carb, protein, ingredients))
    return dishes


def load_dishes(data_dir: Path) -> dict[str, Dish]:
    """All dishes from the downloaded metadata files, by dish id."""
    dishes: dict[str, Dish] = {}
    for name in DISH_METADATA:
        text = (data_dir / LOCAL_DIR / name).read_text(encoding="utf-8")
        dishes.update((dish.dish_id, dish) for dish in parse_dish_metadata(text))
    return dishes


# ---------------------------------------------------------------- the pinned sample


@dataclass(frozen=True)
class SampleDish:
    dish_id: str
    split: Split
    md5: str


@dataclass(frozen=True)
class Manifest:
    seed: int
    metadata: dict[str, str]
    """Metadata file path (relative to the bucket's dataset folder) -> MD5 (hex)."""
    dishes: tuple[SampleDish, ...]


def manifest_to_json(manifest: Manifest) -> str:
    doc = {
        "source": BASE_URL,
        "licence": "CC BY 4.0",
        "seed": manifest.seed,
        "metadata": manifest.metadata,
        "dishes": [{"dish_id": d.dish_id, "split": d.split, "md5": d.md5} for d in manifest.dishes],
    }
    return json.dumps(doc, indent=2) + "\n"


def manifest_from_json(text: str) -> Manifest:
    doc = json.loads(text)
    return Manifest(
        seed=int(doc["seed"]),
        metadata={str(k): str(v) for k, v in doc["metadata"].items()},
        dishes=tuple(
            SampleDish(dish_id=d["dish_id"], split=d["split"], md5=d["md5"]) for d in doc["dishes"]
        ),
    )


def load_manifest(path: Path = MANIFEST_FILE) -> Manifest:
    return manifest_from_json(path.read_text(encoding="utf-8"))


def overhead_photo(dish_id: str) -> str:
    """Local path of a dish's overhead photo, relative to the data folder."""
    return f"{LOCAL_DIR}/dishes/{dish_id}/rgb.png"


def remote_files(manifest: Manifest) -> list[RemoteFile]:
    """Every file of the sample: the metadata, then one overhead photo per dish."""
    files = [
        RemoteFile(url=f"{BASE_URL}/{path}", name=f"{LOCAL_DIR}/{path}", md5=md5)
        for path, md5 in manifest.metadata.items()
    ]
    files += [
        RemoteFile(
            url=f"{BASE_URL}/{OVERHEAD_DIR}/{dish.dish_id}/rgb.png",
            name=overhead_photo(dish.dish_id),
            md5=dish.md5,
        )
        for dish in manifest.dishes
    ]
    return files


# ---------------------------------------------------------------- building the sample


def _md5_hex(gcs_md5: str) -> str:
    """The bucket lists MD5s in base64; files are checked against hex."""
    return base64.b64decode(gcs_md5).hex()


def list_objects(client: httpx.Client, prefix: str) -> Iterator[dict[str, Any]]:
    """Objects under `prefix` (relative to the dataset folder), following every page."""
    params = {
        "prefix": OBJECT_PREFIX + prefix,
        "fields": "nextPageToken,items(name,md5Hash)",
        "maxResults": "1000",
    }
    while True:
        response = client.get(LIST_URL, params=params)
        response.raise_for_status()
        page = response.json()
        yield from page.get("items", [])
        token = page.get("nextPageToken")
        if not token:
            return
        params["pageToken"] = token


def _text(client: httpx.Client, path: str) -> str:
    response = client.get(f"{BASE_URL}/{path}")
    response.raise_for_status()
    return response.text


def build_manifest(client: httpx.Client, count: int, seed: int) -> Manifest:
    """Pick `count` dishes at random (seeded) among those with an overhead photo, metadata
    with at least one ingredient and a positive mass, and an official RGB split."""
    split_of: dict[str, Split] = {}
    for split, path in SPLIT_FILES.items():
        for dish_id in _text(client, path).split():
            split_of[dish_id] = split

    usable = {
        dish.dish_id
        for path in DISH_METADATA
        for dish in parse_dish_metadata(_text(client, path))
        if dish.ingredients and dish.mass > 0
    }

    metadata_md5 = {
        item["name"].removeprefix(OBJECT_PREFIX): _md5_hex(item["md5Hash"])
        for item in list_objects(client, "metadata/")
    }
    missing = [path for path in METADATA_FILES if path not in metadata_md5]
    if missing:
        msg = f"not in the bucket listing: {', '.join(missing)}"
        raise ValueError(msg)

    photo_md5 = {}
    for item in list_objects(client, f"{OVERHEAD_DIR}/"):
        parts = item["name"].removeprefix(OBJECT_PREFIX).split("/")
        if len(parts) == 4 and parts[3] == "rgb.png":  # imagery/realsense_overhead/<dish>/rgb.png
            photo_md5[parts[2]] = _md5_hex(item["md5Hash"])

    candidates = sorted(usable & split_of.keys() & photo_md5.keys())
    if len(candidates) < count:
        msg = f"only {len(candidates)} usable dishes, {count} asked"
        raise ValueError(msg)
    # A seeded sample for reproducibility, not for security.
    chosen = sorted(random.Random(seed).sample(candidates, count))  # noqa: S311
    return Manifest(
        seed=seed,
        metadata={path: metadata_md5[path] for path in METADATA_FILES},
        dishes=tuple(SampleDish(d, split_of[d], photo_md5[d]) for d in chosen),
    )
