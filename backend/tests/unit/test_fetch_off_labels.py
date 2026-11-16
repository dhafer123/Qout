"""Open Food Facts nutrition photos for the label evaluation set: photo choice, filters and
the download loop (respx, no network)."""

import json
from collections.abc import AsyncIterator, Iterator
from pathlib import Path
from typing import Any

import httpx
import pytest
import respx

from app.modules.ingestion.off_client import OffClient, RetryPolicy
from app.modules.ingestion.off_normaliser import OFF_IMAGES_URL
from scripts import fetch_off_labels as f

EAN = "6191509900701"
FOLDER = "619/150/990/0701"
JPEG = b"\xff\xd8\xff\xe0 photo"
OFF = "https://off.test"


def entry(rev: Any = "7", w: Any = 900, h: Any = 1360) -> dict[str, Any]:
    return {
        "imgid": "2",
        "rev": rev,
        "sizes": {"400": {"w": 265, "h": 400}, "full": {"w": w, "h": h}},
    }


def product(**overrides: Any) -> dict[str, Any]:
    base: dict[str, Any] = {
        "code": EAN,
        "product_name": "Olive oil",
        "product_name_fr": "Huile d'olive",
        "brands": "Terra Delyssa, CHO",
        "lang": "fr",
        "categories_tags": ["en:fats", "en:olive-oils"],
        "images": {"1": {}, "front_fr": entry(), "nutrition_fr": entry()},
        "nutriments": {"fat_100g": 100, "salt_100g": 0, "energy-kcal_100g": 824, "nova": 1},
    }
    return base | overrides


# ---------------------------------------------------------------- photo choice


def test_full_size_url() -> None:
    assert f.nutrition_photo(EAN, product()) == f.NutritionPhoto(
        lang="fr",
        url=f"{OFF_IMAGES_URL}/{FOLDER}/nutrition_fr.7.full.jpg",
        width=900,
        height=1360,
    )


@pytest.mark.parametrize(
    ("lang", "available", "chosen"),
    [
        ("en", ["fr", "en"], "en"),  # the product's language first
        ("de", ["en", "ar", "fr"], "fr"),  # then French, Arabic, English
        ("de", ["en", "ar"], "ar"),
        (None, ["it", "en"], "en"),
        (None, ["it", "es"], "es"),  # then any, alphabetically
    ],
)
def test_language_preference(lang: str | None, available: list[str], chosen: str) -> None:
    images = {f"nutrition_{code}": entry() for code in available}

    photo = f.nutrition_photo(EAN, product(lang=lang, images=images))

    assert photo is not None
    assert photo.lang == chosen


def test_small_photos_are_skipped_for_a_larger_one() -> None:
    images = {"nutrition_fr": entry(w=300, h=400), "nutrition_ar": entry(rev="3", w=800, h=600)}

    photo = f.nutrition_photo(EAN, product(images=images))

    assert photo is not None
    assert (photo.lang, photo.url.rsplit("/", 1)[1]) == ("ar", "nutrition_ar.3.full.jpg")


@pytest.mark.parametrize(
    "images",
    [
        None,
        [],
        {},
        {"front_fr": entry()},
        {"nutrition_fr": entry(w=799, h=500)},
        {"nutrition_fr": "x"},
        {"nutrition_fr": {"rev": "7"}},
        {"nutrition_fr": {"rev": "7", "sizes": {"full": "x"}}},
        {"nutrition_fr": entry(rev="7a")},
        {"nutrition_fr": entry(rev=None)},
        {"nutrition_fr": entry(w="900")},
    ],
)
def test_no_usable_photo(images: object) -> None:
    assert f.nutrition_photo(EAN, product(images=images)) is None


def test_numeric_rev_is_accepted() -> None:
    photo = f.nutrition_photo(EAN, product(images={"nutrition_fr": entry(rev=12)}))

    assert photo is not None
    assert photo.url.endswith("/nutrition_fr.12.full.jpg")


# ---------------------------------------------------------------- filters and metadata


@pytest.mark.parametrize(
    ("brands", "key"),
    [("Terra Delyssa, CHO", "terra delyssa"), (" Délice ", "délice"), (None, ""), ("", "")],
)
def test_brand(brands: str | None, key: str) -> None:
    assert f.brand(product(brands=brands)) == key


@pytest.mark.parametrize(
    ("tags", "skipped"),
    [(["en:beverages", "en:waters"], True), (["en:beverages"], False), (None, False)],
)
def test_waters_are_skipped(tags: list[str] | None, skipped: bool) -> None:
    assert f.skipped_category(product(categories_tags=tags)) is skipped


@pytest.mark.parametrize(
    ("names", "expected"),
    [
        ({"product_name_fr": " Huile ", "product_name": "Oil"}, "Huile"),
        ({"product_name_fr": "", "product_name": "Oil"}, "Oil"),
        ({"product_name_fr": None, "product_name": None}, None),
    ],
)
def test_name(names: dict[str, Any], expected: str | None) -> None:
    assert f.name(product(**names)) == expected


def test_template_and_manifest_entry() -> None:
    p = product()
    photo = f.nutrition_photo(EAN, p)
    assert photo is not None

    assert f.template(EAN, p, photo) == {
        "product": "Huile d'olive",
        "brand": "Terra Delyssa",
        "ean": EAN,
        "source": "open-food-facts",
        "photo_url": photo.url,
    }
    assert f.manifest_entry(EAN, p, photo) == f.template(EAN, p, photo) | {
        "product_url": f"https://world.openfoodfacts.org/product/{EAN}",
        "photo_size": [900, 1360],
        "off_values": {"energy-kcal_100g": 824, "fat_100g": 100, "salt_100g": 0},
    }
    assert f.template(EAN, product(brands=None), photo)["brand"] is None
    assert f.manifest_entry(EAN, product(nutriments=None), photo)["off_values"] == {}


def test_known_eans(tmp_path: Path) -> None:
    (tmp_path / "tn-001.json").write_text(json.dumps({"ean": "111"}), encoding="utf-8")
    (tmp_path / "tn-002.json").write_text(json.dumps({"ean": None}), encoding="utf-8")

    assert f.known_eans(tmp_path, [{"ean": "222"}]) == {"111", "222"}


def test_search_hits() -> None:
    body = {"hits": [{"code": "619"}, {"x": 1}, "y"], "page_count": 3}

    assert f.search_hits(body) == (["619"], 3)
    assert f.search_hits({"hits": []}) == ([], 0)
    with pytest.raises(ValueError, match="unexpected search response"):
        f.search_hits({"error": "x"})


# ---------------------------------------------------------------- download loop


@pytest.fixture
def mock() -> Iterator[respx.MockRouter]:
    with respx.mock(assert_all_called=False) as router:
        yield router


@pytest.fixture
async def sources() -> AsyncIterator[f.Sources]:
    async def no_sleep(_: float) -> None:
        return None

    retry = RetryPolicy(max_retries=1, sleep=no_sleep)
    async with (
        OffClient(httpx.AsyncClient(base_url=OFF), retry=retry) as off,
        httpx.AsyncClient() as http,
    ):
        yield f.Sources(off=off, http=http, retry=retry)


def serve(mock: respx.MockRouter, products: dict[str, dict[str, Any] | None]) -> respx.Route:
    """Search lists `products` (one page); the API returns each (None: unknown); every
    nutrition photo is a JPEG."""
    search = mock.get(f.SEARCH_URL).respond(
        200, json={"hits": [{"code": code} for code in products], "page_count": 1}
    )
    for code, body in products.items():
        url = f"{OFF}/api/v2/product/{code}.json"
        if body is None:
            mock.get(url).respond(404)
        else:
            mock.get(url).respond(200, json={"status": 1, "product": body})
    mock.get(url__startswith=OFF_IMAGES_URL).respond(200, content=JPEG)
    return search


def ean(n: int) -> str:
    return f"619000000000{n}"


async def test_fetch_downloads_and_filters(
    tmp_path: Path, mock: respx.MockRouter, sources: f.Sources
) -> None:
    labels = tmp_path / "labels"
    labels.mkdir()
    (labels / "tn-001.json").write_text(json.dumps({"ean": ean(1)}), encoding="utf-8")
    search = serve(
        mock,
        {
            ean(1): product(),  # already in the evaluation set
            ean(2): product(brands="Délice"),
            ean(3): None,  # unknown to the API
            ean(4): product(categories_tags=["en:waters"]),
            ean(5): product(images={}),  # no nutrition photo
            ean(6): product(brands="Délice, X"),
            ean(7): product(brands="délice"),  # third of the brand
            ean(8): product(brands="Vitalait"),
        },
    )
    out = tmp_path / "out"

    added = await f.fetch(10, out, labels, sources)

    assert added == 3
    params = search.calls.last.request.url.params
    assert params["q"] == f.SEARCH_QUERY
    assert (params["sort_by"], params["page"], params["page_size"]) == (
        "-unique_scans_n",
        "1",
        "100",
    )
    inbox = out / "inbox"
    assert sorted(p.name for p in inbox.iterdir()) == [
        f"{ean(n)}.{ext}" for n in (2, 6, 8) for ext in ("jpg", "json")
    ]
    assert (inbox / f"{ean(2)}.jpg").read_bytes() == JPEG
    sidecar = json.loads((inbox / f"{ean(2)}.json").read_text(encoding="utf-8"))
    assert sidecar["ean"] == ean(2)
    assert sidecar["source"] == "open-food-facts"
    manifest = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    assert [m["ean"] for m in manifest] == [ean(2), ean(6), ean(8)]


async def test_fetch_stops_at_count_and_resumes(
    tmp_path: Path, mock: respx.MockRouter, sources: f.Sources
) -> None:
    serve(mock, {ean(n): product(brands=f"brand {n}") for n in range(1, 5)})
    out = tmp_path / "out"

    assert await f.fetch(2, out, tmp_path, sources) == 2
    assert await f.fetch(5, out, tmp_path, sources) == 2  # the two left

    manifest = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    assert [m["ean"] for m in manifest] == [ean(n) for n in range(1, 5)]


async def test_fetch_skips_failed_downloads(
    tmp_path: Path, mock: respx.MockRouter, sources: f.Sources
) -> None:
    mock.get(f.SEARCH_URL).respond(200, json={"hits": [{"code": EAN}], "page_count": 1})
    mock.get(f"{OFF}/api/v2/product/{EAN}.json").respond(
        200, json={"status": 1, "product": product()}
    )
    mock.get(url__startswith=OFF_IMAGES_URL).respond(200, content=b"<html>")  # not an image

    assert await f.fetch(1, tmp_path / "out", tmp_path, sources) == 0
    assert list((tmp_path / "out" / "inbox").iterdir()) == []


async def test_fetch_pages_through_the_search(
    tmp_path: Path, mock: respx.MockRouter, sources: f.Sources
) -> None:
    pages = [
        {"hits": [{"code": ean(1)}], "page_count": 2},
        {"hits": [{"code": ean(2)}], "page_count": 2},
    ]
    search = mock.get(f.SEARCH_URL).mock(
        side_effect=[httpx.Response(200, json=page) for page in pages]
    )
    for n in (1, 2):
        mock.get(f"{OFF}/api/v2/product/{ean(n)}.json").respond(
            200, json={"status": 1, "product": product(brands=f"b{n}")}
        )
    mock.get(url__startswith=OFF_IMAGES_URL).respond(200, content=JPEG)

    assert await f.fetch(5, tmp_path / "out", tmp_path, sources) == 2
    assert [c.request.url.params["page"] for c in search.calls] == ["1", "2"]
