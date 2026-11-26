import base64
import hashlib
from pathlib import Path

import httpx
import pytest
import respx

from qout_ml.data import nutrition5k
from qout_ml.data.nutrition5k import (
    BASE_URL,
    LIST_URL,
    Manifest,
    SampleDish,
    build_manifest,
    load_dishes,
    manifest_from_json,
    manifest_to_json,
    parse_dish_metadata,
    remote_files,
)

ROW_TWO_INGREDIENTS = (
    "dish_1,300.5,193.0,12.3,28.2,18.6,"
    "ingr_0000000508,soy sauce,3.4,1.8,0.02,0.17,0.28,"
    "ingr_0000000026,white rice,8.5,11.0,0.03,2.38,0.23"
)


def _gcs_md5(data: bytes) -> str:
    return base64.b64encode(hashlib.md5(data, usedforsecurity=False).digest()).decode()


# ---------------------------------------------------------------- metadata


def test_parses_a_dish_and_its_ingredients() -> None:
    (dish,) = parse_dish_metadata(ROW_TWO_INGREDIENTS + "\n")

    assert dish.dish_id == "dish_1"
    assert (dish.calories, dish.mass, dish.fat, dish.carb, dish.protein) == (
        300.5,
        193.0,
        12.3,
        28.2,
        18.6,
    )
    assert [i.name for i in dish.ingredients] == ["soy sauce", "white rice"]
    rice = dish.ingredients[1]
    assert (rice.ingredient_id, rice.grams, rice.calories) == ("ingr_0000000026", 8.5, 11.0)


def test_dish_without_ingredients_and_blank_lines() -> None:
    dishes = parse_dish_metadata("dish_2,0,0,0,0,0\n\n")

    assert [(d.dish_id, d.ingredients) for d in dishes] == [("dish_2", ())]


@pytest.mark.parametrize("row", ["dish_3,1,2,3", "dish_4,1,2,3,4,5,ingr_1,salt,1"])
def test_wrong_field_count_is_an_error(row: str) -> None:
    with pytest.raises(ValueError, match="unexpected number of fields"):
        parse_dish_metadata(row)


def test_load_dishes_from_both_cafes(tmp_path: Path) -> None:
    folder = tmp_path / "nutrition5k" / "metadata"
    folder.mkdir(parents=True)
    (folder / "dish_metadata_cafe1.csv").write_text(ROW_TWO_INGREDIENTS + "\n", encoding="utf-8")
    (folder / "dish_metadata_cafe2.csv").write_text("dish_9,1,2,3,4,5\n", encoding="utf-8")

    assert sorted(load_dishes(tmp_path)) == ["dish_1", "dish_9"]


# ---------------------------------------------------------------- manifest


MANIFEST = Manifest(
    seed=3,
    metadata={"metadata/dish_metadata_cafe1.csv": "aa" * 16},
    dishes=(SampleDish("dish_1", "train", "bb" * 16), SampleDish("dish_2", "test", "cc" * 16)),
)


def test_manifest_round_trip() -> None:
    text = manifest_to_json(MANIFEST)

    assert manifest_from_json(text) == MANIFEST
    assert '"licence": "CC BY 4.0"' in text


def test_remote_files_cover_metadata_then_photos() -> None:
    files = remote_files(MANIFEST)

    assert [(f.name, f.md5) for f in files] == [
        ("nutrition5k/metadata/dish_metadata_cafe1.csv", "aa" * 16),
        ("nutrition5k/dishes/dish_1/rgb.png", "bb" * 16),
        ("nutrition5k/dishes/dish_2/rgb.png", "cc" * 16),
    ]
    assert files[1].url == f"{BASE_URL}/imagery/realsense_overhead/dish_1/rgb.png"


def test_committed_manifest_is_the_planned_sample() -> None:
    manifest = nutrition5k.load_manifest()

    assert len(manifest.dishes) == 500
    assert len({d.dish_id for d in manifest.dishes}) == 500
    assert {d.split for d in manifest.dishes} == {"train", "test"}
    assert set(manifest.metadata) == set(nutrition5k.METADATA_FILES)
    assert all(len(d.md5) == 32 for d in manifest.dishes)


# ---------------------------------------------------------------- building the sample


def _mock_bucket(dish_count: int = 6, *, metadata_listed: bool = True) -> None:
    """dish_0..dish_{n-1}: all in a split, metadata and photo; plus dishes missing one."""
    ids = [f"dish_{i}" for i in range(dish_count)]
    respx.get(f"{BASE_URL}/dish_ids/splits/rgb_train_ids.txt").respond(
        200, text="\n".join([*ids[: dish_count // 2], "no_photo"]) + "\n"
    )
    respx.get(f"{BASE_URL}/dish_ids/splits/rgb_test_ids.txt").respond(
        200, text="\n".join([*ids[dish_count // 2 :], "no_metadata", "zero_mass"]) + "\n"
    )
    cafe1 = "\n".join(f"{d},100,50,1,2,3,ingr_1,rice,50,100,1,2,3" for d in ids)
    respx.get(f"{BASE_URL}/metadata/dish_metadata_cafe1.csv").respond(
        200, text=cafe1 + "\nno_photo,1,1,1,1,1,ingr_1,rice,1,1,1,1,1\n"
    )
    respx.get(f"{BASE_URL}/metadata/dish_metadata_cafe2.csv").respond(
        200, text="zero_mass,0,0,0,0,0,ingr_1,rice,0,0,0,0,0\nnot_in_split,1,1,1,1,1\n"
    )

    prefix = nutrition5k.OBJECT_PREFIX

    def listing(request: httpx.Request) -> httpx.Response:
        wanted = request.url.params["prefix"]
        if wanted == prefix + "metadata/":
            if not metadata_listed:
                return httpx.Response(200, json={"items": []})
            items = [
                {"name": prefix + path, "md5Hash": _gcs_md5(path.encode())}
                for path in nutrition5k.METADATA_FILES
            ]
            return httpx.Response(200, json={"items": items})
        photos = [*ids, "no_metadata", "zero_mass"]
        items = [
            {"name": f"{prefix}imagery/realsense_overhead/{d}/{f}", "md5Hash": _gcs_md5(d.encode())}
            for d in photos
            for f in ("depth_raw.png", "rgb.png")
        ]
        # Two pages, to follow nextPageToken.
        if request.url.params.get("pageToken") == "p2":
            return httpx.Response(200, json={"items": items[len(items) // 2 :]})
        return httpx.Response(200, json={"items": items[: len(items) // 2], "nextPageToken": "p2"})

    respx.get(LIST_URL).mock(side_effect=listing)


@respx.mock
def test_build_manifest_picks_only_usable_dishes() -> None:
    _mock_bucket(6)

    with httpx.Client() as client:
        manifest = build_manifest(client, count=6, seed=1)

    assert [d.dish_id for d in manifest.dishes] == [f"dish_{i}" for i in range(6)]
    assert [d.split for d in manifest.dishes] == ["train"] * 3 + ["test"] * 3
    assert manifest.dishes[2].md5 == hashlib.md5(b"dish_2", usedforsecurity=False).hexdigest()
    assert (
        manifest.metadata["metadata/ingredients_metadata.csv"]
        == hashlib.md5(b"metadata/ingredients_metadata.csv", usedforsecurity=False).hexdigest()
    )


@respx.mock
def test_build_manifest_sample_is_seeded() -> None:
    _mock_bucket(10)

    with httpx.Client() as client:
        first = build_manifest(client, count=4, seed=7)
        again = build_manifest(client, count=4, seed=7)
        other = build_manifest(client, count=4, seed=8)

    assert first == again
    assert [d.dish_id for d in first.dishes] == sorted(d.dish_id for d in first.dishes)
    assert first.dishes != other.dishes


@respx.mock
def test_build_manifest_needs_enough_dishes() -> None:
    _mock_bucket(3)

    with httpx.Client() as client, pytest.raises(ValueError, match="only 3 usable dishes"):
        build_manifest(client, count=4, seed=0)


@respx.mock
def test_build_manifest_needs_every_metadata_file() -> None:
    _mock_bucket(3, metadata_listed=False)

    with httpx.Client() as client, pytest.raises(ValueError, match="not in the bucket listing"):
        build_manifest(client, count=1, seed=0)
