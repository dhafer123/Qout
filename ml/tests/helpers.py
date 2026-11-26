"""Builders for tiny images and Parquet files used by the tests."""

import io
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq
import torch
from PIL import Image

_IMAGE_STRUCT = pa.struct([("bytes", pa.binary()), ("path", pa.string())])


def _encode(tensor: torch.Tensor, image_format: str) -> bytes:
    array = tensor.permute(1, 2, 0).numpy()
    image = Image.fromarray(array[:, :, 0] if array.shape[2] == 1 else array)
    buffer = io.BytesIO()
    image.save(buffer, format=image_format)
    return buffer.getvalue()


def png_bytes(tensor: torch.Tensor) -> bytes:
    """(C, H, W) uint8 -> PNG; one channel gives a grey (L) PNG."""
    return _encode(tensor, "PNG")


def jpeg_bytes(tensor: torch.Tensor) -> bytes:
    return _encode(tensor, "JPEG")


def palette_png_bytes(labels: torch.Tensor) -> bytes:
    """(H, W) class ids -> palette (P) PNG whose colours differ from the ids."""
    image = Image.fromarray(labels.numpy(), mode="P")
    image.putpalette([255 - (i % 256) for i in range(768)])
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def rgb(height: int, width: int, value: int = 128) -> torch.Tensor:
    return torch.full((3, height, width), value, dtype=torch.uint8)


def mask(height: int, width: int, value: int = 1) -> torch.Tensor:
    return torch.full((1, height, width), value, dtype=torch.uint8)


def write_parquet(path: Path, rows: list[tuple[int, bytes, bytes]]) -> Path:
    """Rows of (id, image bytes, label bytes), in the mirror's layout."""
    table = pa.table(
        {
            "image": pa.array([{"bytes": img, "path": None} for _, img, _ in rows], _IMAGE_STRUCT),
            "label": pa.array([{"bytes": lbl, "path": None} for _, _, lbl in rows], _IMAGE_STRUCT),
            "classes_on_image": pa.array([[0, 1] for _ in rows], pa.list_(pa.int64())),
            "id": pa.array([sample_id for sample_id, _, _ in rows], pa.int64()),
        }
    )
    pq.write_table(table, path)
    return path
