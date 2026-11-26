"""FoodSeg103: pinned source files, conversion to image/mask folders, and the dataset.

The official download (research.larc.smu.edu.sg) was unreachable on 2026-11-26, so the
files come from the Hugging Face mirror, pinned to one revision with each file's SHA-256.
The mirror keeps the official split: its `validation` split is the official test split.
Labels are the raw class ids: 0 background, 1-103 foods (104 classes, as in the
official benchmark); 255 marks pixels that are not labelled.
"""

import json
import logging
from collections.abc import Callable, Iterator, Sequence
from pathlib import Path
from typing import Any, Literal

import pyarrow.parquet as pq
import torch
from PIL import Image
from torch.utils.data import Dataset
from torchvision.transforms.v2.functional import pil_to_tensor

from qout_ml.data.download import RemoteFile
from qout_ml.paths import ML_ROOT

logger = logging.getLogger(__name__)

Split = Literal["train", "test"]
PairTransform = Callable[[torch.Tensor, torch.Tensor], tuple[torch.Tensor, torch.Tensor]]

NUM_CLASSES = 104
IGNORE_INDEX = 255
SPLIT_SIZES: dict[Split, int] = {"train": 4983, "test": 2135}
CLASSES_FILE = ML_ROOT / "classes" / "foodseg103.json"

HF_REPO = "EduardoPacheco/FoodSeg103"
HF_REVISION = "34e1208e14bc3595d544fc8c3f3c6673253fd9ef"


def _hf_file(path: str, sha256: str, size: int) -> RemoteFile:
    return RemoteFile(
        url=f"https://huggingface.co/datasets/{HF_REPO}/resolve/{HF_REVISION}/{path}",
        name=f"foodseg103/{Path(path).name}",
        sha256=sha256,
        size=size,
    )


PARQUET_FILES: dict[Split, tuple[RemoteFile, ...]] = {
    "train": (
        _hf_file(
            "data/train-00000-of-00003.parquet",
            "7288a62861c06f1c0f677674fd9564aae277a727a146bf31688cf86befa452b7",
            351240914,
        ),
        _hf_file(
            "data/train-00001-of-00003.parquet",
            "814ef4e25036a9073a4017e8d05bad80b213df74cc9cd60e972136b5ae2e0ab9",
            356813558,
        ),
        _hf_file(
            "data/train-00002-of-00003.parquet",
            "7b16b566c273e049a10d651caf6d28951f6cdf730fba6596e832b451230d6ac1",
            431463278,
        ),
    ),
    "test": (
        _hf_file(
            "data/validation-00000-of-00001.parquet",
            "73d4d49abc2ef135dfccbce86f395d8e39215cf656d2954b516a88572f24b0e6",
            115186173,
        ),
    ),
}

_JPEG_MAGIC = b"\xff\xd8\xff"
_PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
_COMPLETE_MARKER = ".complete"


class ConversionError(Exception):
    """The Parquet files did not hold the expected samples."""


def load_class_names(path: Path = CLASSES_FILE) -> tuple[str, ...]:
    """Class names by id, checked to be exactly ids 0..NUM_CLASSES-1."""
    doc = json.loads(path.read_text(encoding="utf-8"))
    classes = doc["classes"]
    ids = [entry["id"] for entry in classes]
    if ids != list(range(NUM_CLASSES)):
        msg = f"{path}: class ids must be 0..{NUM_CLASSES - 1} in order"
        raise ValueError(msg)
    return tuple(str(entry["name"]) for entry in classes)


def _image_extension(data: bytes) -> str:
    if data.startswith(_JPEG_MAGIC):
        return "jpg"
    if data.startswith(_PNG_MAGIC):
        return "png"
    msg = "image bytes are neither JPEG nor PNG"
    raise ConversionError(msg)


def _rows(parquet_files: Sequence[Path]) -> Iterator[dict[str, Any]]:
    for path in parquet_files:
        parquet = pq.ParquetFile(path)
        for batch in parquet.iter_batches(batch_size=64, columns=["image", "label", "id"]):
            yield from batch.to_pylist()


def is_converted(split_dir: Path, expected: int) -> bool:
    marker = split_dir / _COMPLETE_MARKER
    return marker.is_file() and marker.read_text(encoding="utf-8").strip() == str(expected)


def convert_parquet(parquet_files: Sequence[Path], split_dir: Path, expected: int) -> int:
    """Write each sample as `images/<id>.jpg|png` and `masks/<id>.png`; return the count.

    Bytes are copied as they are (no re-encoding). A finished split is marked and skipped
    the next time; an interrupted one is written again over its old files.
    """
    if is_converted(split_dir, expected):
        logger.info("%s: already converted", split_dir)
        return expected
    images_dir = split_dir / "images"
    masks_dir = split_dir / "masks"
    images_dir.mkdir(parents=True, exist_ok=True)
    masks_dir.mkdir(parents=True, exist_ok=True)

    seen: set[int] = set()
    for row in _rows(parquet_files):
        sample_id = int(row["id"])
        if sample_id in seen:
            msg = f"sample id {sample_id} appears twice"
            raise ConversionError(msg)
        seen.add(sample_id)
        image: bytes = row["image"]["bytes"]
        label: bytes = row["label"]["bytes"]
        if _image_extension(label) != "png":
            msg = f"sample {sample_id}: the mask is not a PNG"
            raise ConversionError(msg)
        stem = f"{sample_id:05d}"
        (images_dir / f"{stem}.{_image_extension(image)}").write_bytes(image)
        (masks_dir / f"{stem}.png").write_bytes(label)

    if len(seen) != expected:
        msg = f"{split_dir.name}: expected {expected} samples, found {len(seen)}"
        raise ConversionError(msg)
    (split_dir / _COMPLETE_MARKER).write_text(str(expected), encoding="utf-8")
    return expected


def read_image(path: Path) -> torch.Tensor:
    """The photo as a uint8 RGB tensor of shape (3, H, W)."""
    with Image.open(path) as image:
        rgb: torch.Tensor = pil_to_tensor(image.convert("RGB"))
    return rgb


def read_mask(path: Path) -> torch.Tensor:
    """The mask's class ids as a uint8 tensor of shape (H, W).

    Grey (L) and palette (P) PNGs both hold the class id in each pixel; Pillow keeps
    palette indices as they are (no colour lookup).
    """
    with Image.open(path) as image:
        if image.mode not in {"L", "P"}:
            msg = f"{path}: a mask must have one channel (L or P), found {image.mode}"
            raise ValueError(msg)
        labels: torch.Tensor = pil_to_tensor(image)[0]
    return labels


class FoodSeg103(Dataset[tuple[torch.Tensor, torch.Tensor]]):
    """Image (uint8, 3xHxW) and mask (HxW class ids) pairs from a converted split."""

    def __init__(self, split_dir: Path, transform: PairTransform | None = None) -> None:
        images_dir = split_dir / "images"
        if not images_dir.is_dir():
            msg = f"{split_dir}: not found; run `python -m qout_ml fetch foodseg103` first"
            raise FileNotFoundError(msg)
        self._images = sorted(
            path for path in images_dir.iterdir() if path.suffix in {".jpg", ".png"}
        )
        if not self._images:
            msg = f"{images_dir}: no images"
            raise FileNotFoundError(msg)
        self._masks = [split_dir / "masks" / f"{path.stem}.png" for path in self._images]
        missing = [path.name for path in self._masks if not path.is_file()]
        if missing:
            msg = f"{split_dir}: {len(missing)} masks missing, e.g. {missing[0]}"
            raise FileNotFoundError(msg)
        self._transform = transform

    def __len__(self) -> int:
        return len(self._images)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, torch.Tensor]:
        image = read_image(self._images[index])
        mask = read_mask(self._masks[index])
        if image.shape[1:] != mask.shape:
            msg = f"{self._images[index].name}: image and mask sizes differ"
            raise ValueError(msg)
        if self._transform is not None:
            return self._transform(image, mask)
        return image, mask
