import pytest
import torch
from torchvision.transforms import v2

from qout_ml.data.foodseg103 import IGNORE_INDEX
from qout_ml.data.transforms import (
    IMAGENET_MEAN,
    IMAGENET_STD,
    EvalTransform,
    PairTransform,
    geometric,
    padded_crop,
    photometric,
    train_transform,
)


def _blocks(height: int, width: int, block: int = 16) -> tuple[torch.Tensor, torch.Tensor]:
    """A mask of square blocks with classes 1..k and an image whose red channel is 10x the
    class, so after any geometric transform each pixel's colour tells its true class."""
    rows = torch.arange(height) // block
    cols = torch.arange(width) // block
    labels = (rows[:, None] * (width // block + 1) + cols[None, :]) % 20 + 1
    image = torch.zeros(3, height, width, dtype=torch.uint8)
    image[0] = (labels * 10).to(torch.uint8)
    return image, labels.to(torch.uint8)


def test_train_transform_shapes_and_types() -> None:
    image, labels = _blocks(300, 400)

    out_image, out_labels = train_transform(crop=128)(image, labels)

    assert out_image.shape == (3, 128, 128)
    assert out_image.dtype == torch.float32
    assert out_labels.shape == (128, 128)
    assert out_labels.dtype == torch.int64


@pytest.mark.parametrize("seed", range(10))
def test_geometric_transforms_keep_image_and_mask_aligned(seed: int) -> None:
    torch.manual_seed(seed)
    image, labels = _blocks(160, 240)

    out_image, out_labels = PairTransform(geometric(crop=96))(image, labels)

    # Bilinear resizing blends colours along block edges, so compare each class's
    # median colour: a shifted or flipped mask would pair classes with the wrong blocks.
    red = out_image[0].long()
    classes = [c for c in out_labels.unique().tolist() if c != IGNORE_INDEX]
    assert classes
    for label in classes:
        assert red[out_labels == label].median().item() == label * 10


def test_flip_moves_image_and_mask_together_exactly() -> None:
    image, labels = _blocks(32, 48, block=8)

    out_image, out_labels = PairTransform(v2.RandomHorizontalFlip(p=1.0))(image, labels)

    assert torch.equal(out_labels, labels.flip(-1).long())
    assert torch.equal(out_image[0].long(), out_labels * 10)


def test_resizing_never_blends_class_ids() -> None:
    image, labels = _blocks(100, 100, block=7)

    _, out_labels = PairTransform(geometric(crop=64))(image, labels)

    assert set(out_labels.unique().tolist()) <= {*labels.unique().tolist(), IGNORE_INDEX}


def test_small_images_are_padded_with_ignored_pixels() -> None:
    image, labels = _blocks(20, 30)

    out_image, out_labels = PairTransform(padded_crop(64))(image, labels)

    padded = out_labels == IGNORE_INDEX
    assert out_labels.shape == (64, 64)
    assert padded.sum() == 64 * 64 - 20 * 30
    assert out_image[:, padded].eq(0).all()


def test_colour_changes_leave_the_mask_alone() -> None:
    image, labels = _blocks(64, 64)

    _, out_labels = PairTransform(photometric())(image, labels)

    assert torch.equal(out_labels, labels.long())


def test_eval_transform_resizes_the_image_only() -> None:
    image = torch.full((3, 300, 600), 255, dtype=torch.uint8)
    labels = torch.ones(300, 600, dtype=torch.uint8)

    out_image, out_labels = EvalTransform(short_side=150)(image, labels)

    assert out_image.shape == (3, 150, 300)
    assert out_labels.shape == (300, 600)
    assert out_labels.dtype == torch.int64
    for channel, (mean, std) in enumerate(zip(IMAGENET_MEAN, IMAGENET_STD, strict=True)):
        assert out_image[channel].mean().item() == pytest.approx((1.0 - mean) / std, abs=1e-4)
