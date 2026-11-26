import hashlib
from collections.abc import Iterator
from pathlib import Path

import httpx
import pytest
import respx

from qout_ml import __main__ as cli
from qout_ml.data import foodseg103, nutrition5k
from qout_ml.data.download import RemoteFile
from qout_ml.data.nutrition5k import Manifest, SampleDish
from qout_ml.paths import ML_ROOT, data_dir
from tests.helpers import jpeg_bytes, mask, png_bytes, rgb, write_parquet


@pytest.fixture
def data_root(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    root = tmp_path / "var"
    monkeypatch.setenv("QOUT_ML_DATA_DIR", str(root))
    return root


def _parquet_remote(tmp_path: Path, name: str, ids: list[int]) -> tuple[RemoteFile, bytes]:
    rows = [(i, jpeg_bytes(rgb(4, 4)), png_bytes(mask(4, 4, i))) for i in ids]
    data = write_parquet(tmp_path / name, rows).read_bytes()
    remote = RemoteFile(
        url=f"https://hf.example/{name}",
        name=f"foodseg103/{name}",
        sha256=hashlib.sha256(data).hexdigest(),
    )
    return remote, data


@pytest.fixture
def tiny_foodseg(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Iterator[respx.MockRouter]:
    train, train_data = _parquet_remote(tmp_path, "train.parquet", [1, 2])
    test, test_data = _parquet_remote(tmp_path, "test.parquet", [3])
    monkeypatch.setattr(foodseg103, "PARQUET_FILES", {"train": (train,), "test": (test,)})
    monkeypatch.setattr(foodseg103, "SPLIT_SIZES", {"train": 2, "test": 1})
    with respx.mock as router:
        router.get(train.url).respond(200, content=train_data)
        router.get(test.url).respond(200, content=test_data)
        yield router


def test_fetch_foodseg103_converts_and_removes_parquet(
    tiny_foodseg: respx.MockRouter, data_root: Path
) -> None:
    assert cli.main(["fetch", "foodseg103"]) == 0

    assert len(foodseg103.FoodSeg103(data_root / "foodseg103" / "train")) == 2
    assert len(foodseg103.FoodSeg103(data_root / "foodseg103" / "test")) == 1
    assert list((data_root / "downloads").rglob("*.parquet")) == []


def test_fetch_foodseg103_twice_downloads_once(
    tiny_foodseg: respx.MockRouter, data_root: Path
) -> None:
    cli.main(["fetch", "foodseg103", "--keep-parquet"])
    calls = tiny_foodseg.calls.call_count

    cli.main(["fetch", "foodseg103"])

    assert tiny_foodseg.calls.call_count == calls == 2
    assert len(list((data_root / "downloads").rglob("*.parquet"))) == 2


@respx.mock
def test_fetch_nutrition5k_downloads_the_manifest(
    data_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    csv = b"dish_1,1,2,3,4,5\n"
    photo = b"png"
    manifest = Manifest(
        seed=0,
        metadata={
            "metadata/dish_metadata_cafe1.csv": hashlib.md5(csv, usedforsecurity=False).hexdigest()
        },
        dishes=(
            SampleDish("dish_1", "train", hashlib.md5(photo, usedforsecurity=False).hexdigest()),
        ),
    )
    monkeypatch.setattr(nutrition5k, "load_manifest", lambda: manifest)
    base = nutrition5k.BASE_URL
    respx.get(f"{base}/metadata/dish_metadata_cafe1.csv").respond(200, content=csv)
    respx.get(f"{base}/imagery/realsense_overhead/dish_1/rgb.png").respond(200, content=photo)

    assert cli.main(["fetch", "nutrition5k"]) == 0

    assert (data_root / "nutrition5k/metadata/dish_metadata_cafe1.csv").read_bytes() == csv
    assert (data_root / "nutrition5k/dishes/dish_1/rgb.png").read_bytes() == photo


def test_nutrition5k_sample_writes_the_manifest(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    manifest = Manifest(seed=4, metadata={}, dishes=())
    seen: dict[str, int] = {}

    def fake_build(client: httpx.Client, count: int, seed: int) -> Manifest:
        seen.update(count=count, seed=seed)
        return manifest

    target = tmp_path / "sample.json"
    monkeypatch.setattr(nutrition5k, "build_manifest", fake_build)
    monkeypatch.setattr(nutrition5k, "MANIFEST_FILE", target)

    assert cli.main(["nutrition5k-sample", "--count", "12", "--seed", "4"]) == 0

    assert seen == {"count": 12, "seed": 4}
    assert nutrition5k.manifest_from_json(target.read_text(encoding="utf-8")) == manifest


def test_unknown_dataset_is_rejected() -> None:
    with pytest.raises(SystemExit):
        cli.main(["fetch", "imagenet"])


def test_data_dir_defaults_to_ml_var(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("QOUT_ML_DATA_DIR", raising=False)
    assert data_dir() == ML_ROOT / "var"
