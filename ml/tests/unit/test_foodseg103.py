import json
from pathlib import Path

import pytest
import torch

from qout_ml.data import foodseg103
from qout_ml.data.foodseg103 import (
    ConversionError,
    FoodSeg103,
    convert_parquet,
    is_converted,
    load_class_names,
    read_mask,
)
from tests.helpers import jpeg_bytes, mask, palette_png_bytes, png_bytes, rgb, write_parquet


def _sample(sample_id: int, height: int = 6, width: int = 8) -> tuple[int, bytes, bytes]:
    return sample_id, jpeg_bytes(rgb(height, width)), png_bytes(mask(height, width, sample_id))


# ---------------------------------------------------------------- pinned files and classes


def test_parquet_files_are_pinned_to_one_revision() -> None:
    files = [f for split in foodseg103.PARQUET_FILES.values() for f in split]
    assert len(files) == 4
    assert all(f"/resolve/{foodseg103.HF_REVISION}/" in f.url for f in files)
    assert all(f.sha256 and len(f.sha256) == 64 and f.size for f in files)
    assert len({f.name for f in files}) == len(files)


def test_class_names_from_the_committed_list() -> None:
    names = load_class_names()
    assert len(names) == foodseg103.NUM_CLASSES
    assert names[0] == "background"
    assert names[66] == "rice"
    assert names[103] == "other ingredients"


def test_class_list_must_be_complete_and_in_order(tmp_path: Path) -> None:
    path = tmp_path / "classes.json"
    path.write_text(json.dumps({"classes": [{"id": 1, "name": "candy"}]}), encoding="utf-8")
    with pytest.raises(ValueError, match="class ids"):
        load_class_names(path)


# ---------------------------------------------------------------- conversion


def test_convert_writes_images_and_masks(tmp_path: Path) -> None:
    first = write_parquet(tmp_path / "a.parquet", [_sample(3), _sample(7)])
    second = write_parquet(
        tmp_path / "b.parquet", [(12, png_bytes(rgb(6, 8)), png_bytes(mask(6, 8, 12)))]
    )
    out = tmp_path / "train"

    assert convert_parquet([first, second], out, expected=3) == 3

    assert sorted(p.name for p in (out / "images").iterdir()) == [
        "00003.jpg",
        "00007.jpg",
        "00012.png",
    ]
    assert sorted(p.name for p in (out / "masks").iterdir()) == [
        "00003.png",
        "00007.png",
        "00012.png",
    ]
    assert (out / "masks" / "00007.png").read_bytes() == png_bytes(mask(6, 8, 7))
    assert is_converted(out, 3)


def test_converted_split_is_skipped(tmp_path: Path) -> None:
    parquet = write_parquet(tmp_path / "a.parquet", [_sample(1)])
    out = tmp_path / "test"
    convert_parquet([parquet], out, expected=1)
    parquet.unlink()

    assert convert_parquet([parquet], out, expected=1) == 1


def test_wrong_count_is_an_error_and_leaves_no_marker(tmp_path: Path) -> None:
    parquet = write_parquet(tmp_path / "a.parquet", [_sample(1)])
    out = tmp_path / "train"

    with pytest.raises(ConversionError, match="expected 2 samples, found 1"):
        convert_parquet([parquet], out, expected=2)
    assert not is_converted(out, 2)
    assert not is_converted(out, 1)


def test_duplicate_ids_are_an_error(tmp_path: Path) -> None:
    parquet = write_parquet(tmp_path / "a.parquet", [_sample(1), _sample(1)])
    with pytest.raises(ConversionError, match="twice"):
        convert_parquet([parquet], tmp_path / "out", expected=2)


def test_unknown_image_format_is_an_error(tmp_path: Path) -> None:
    parquet = write_parquet(tmp_path / "a.parquet", [(1, b"GIF89a...", png_bytes(mask(2, 2)))])
    with pytest.raises(ConversionError, match="neither JPEG nor PNG"):
        convert_parquet([parquet], tmp_path / "out", expected=1)


def test_mask_must_be_png(tmp_path: Path) -> None:
    parquet = write_parquet(
        tmp_path / "a.parquet", [(1, jpeg_bytes(rgb(4, 4)), jpeg_bytes(rgb(4, 4)))]
    )
    with pytest.raises(ConversionError, match="not a PNG"):
        convert_parquet([parquet], tmp_path / "out", expected=1)


# ---------------------------------------------------------------- dataset


@pytest.fixture
def split_dir(tmp_path: Path) -> Path:
    parquet = write_parquet(tmp_path / "a.parquet", [_sample(2, 6, 8), _sample(5, 4, 4)])
    out = tmp_path / "train"
    convert_parquet([parquet], out, expected=2)
    return out


def test_dataset_reads_pairs(split_dir: Path) -> None:
    dataset = FoodSeg103(split_dir)

    assert len(dataset) == 2
    image, labels = dataset[0]
    assert image.shape == (3, 6, 8)
    assert image.dtype == torch.uint8
    assert labels.shape == (6, 8)
    assert labels.unique().tolist() == [2]
    assert dataset[1][1].unique().tolist() == [5]


def test_dataset_applies_the_transform(split_dir: Path) -> None:
    def transform(image: torch.Tensor, labels: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        return image.float() / 255, labels.long() + 1

    image, labels = FoodSeg103(split_dir, transform)[0]

    assert image.dtype == torch.float32
    assert labels.unique().tolist() == [3]


def test_dataset_needs_a_converted_split(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError, match="fetch foodseg103"):
        FoodSeg103(tmp_path / "missing")


def test_dataset_needs_images(tmp_path: Path) -> None:
    (tmp_path / "images").mkdir()
    with pytest.raises(FileNotFoundError, match="no images"):
        FoodSeg103(tmp_path)


def test_dataset_needs_every_mask(split_dir: Path) -> None:
    (split_dir / "masks" / "00005.png").unlink()
    with pytest.raises(FileNotFoundError, match="1 masks missing"):
        FoodSeg103(split_dir)


def test_image_and_mask_sizes_must_match(split_dir: Path) -> None:
    (split_dir / "masks" / "00002.png").write_bytes(png_bytes(mask(3, 3)))
    with pytest.raises(ValueError, match="sizes differ"):
        FoodSeg103(split_dir)[0]


def test_palette_masks_keep_their_class_ids(tmp_path: Path) -> None:
    path = tmp_path / "m.png"
    labels = torch.tensor([[0, 7], [103, 255]], dtype=torch.uint8)
    path.write_bytes(palette_png_bytes(labels))

    assert torch.equal(read_mask(path), labels)


def test_mask_must_have_one_channel(tmp_path: Path) -> None:
    path = tmp_path / "m.png"
    path.write_bytes(png_bytes(rgb(2, 2)))
    with pytest.raises(ValueError, match="one channel"):
        read_mask(path)
