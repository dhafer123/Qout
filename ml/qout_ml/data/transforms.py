"""Image and mask transforms for training and evaluation.

Geometric transforms move the image and its mask together (masks are resized with
nearest-neighbour, so class ids never blend); colour changes and normalisation touch
the image only.
"""

import torch
from torchvision import tv_tensors
from torchvision.transforms import v2
from torchvision.transforms.v2 import functional

from qout_ml.data.foodseg103 import IGNORE_INDEX

# ImageNet statistics: the input normalisation the pretrained backbones were trained with.
IMAGENET_MEAN = (0.485, 0.456, 0.406)
IMAGENET_STD = (0.229, 0.224, 0.225)


class PairTransform:
    """Applies a torchvision v2 transform to an (image, mask) pair of plain tensors.

    Returns the image as float32 (3xHxW) and the mask as int64 (HxW).
    """

    def __init__(self, transform: v2.Transform) -> None:
        self._transform = transform

    def __call__(
        self, image: torch.Tensor, mask: torch.Tensor
    ) -> tuple[torch.Tensor, torch.Tensor]:
        out_image, out_mask = self._transform(tv_tensors.Image(image), tv_tensors.Mask(mask))
        return out_image.as_subclass(torch.Tensor), out_mask.as_subclass(torch.Tensor).long()


def padded_crop(crop: int) -> v2.RandomCrop:
    """Random crop; a smaller image is padded with black and the mask with ignored pixels."""
    return v2.RandomCrop(
        crop, pad_if_needed=True, fill={tv_tensors.Image: 0, tv_tensors.Mask: IGNORE_INDEX}
    )


def geometric(crop: int) -> v2.Compose:
    """Shorter side scaled to crop/2..2*crop, random crop (padded if smaller), random flip."""
    return v2.Compose(
        [
            v2.RandomResize(crop // 2, crop * 2),
            padded_crop(crop),
            v2.RandomHorizontalFlip(),
        ]
    )


def photometric() -> v2.Compose:
    """Colour changes (image only)."""
    return v2.Compose([v2.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.3, hue=0.05)])


def to_model_input() -> v2.Compose:
    """uint8 image to normalised float32; the mask is left as it is."""
    return v2.Compose(
        [
            v2.ToDtype({tv_tensors.Image: torch.float32, "others": None}, scale=True),
            v2.Normalize(IMAGENET_MEAN, IMAGENET_STD),
        ]
    )


def train_transform(crop: int = 512) -> PairTransform:
    return PairTransform(v2.Compose([geometric(crop), photometric(), to_model_input()]))


class EvalTransform:
    """Image resized so its shorter side is `short_side`; the mask keeps its full size.

    Scores are computed at the mask's original resolution (as in the published results),
    so predictions are upsampled to the mask, not the mask downsampled. Use batch size 1.
    """

    def __init__(self, short_side: int = 512) -> None:
        self._short_side = short_side
        self._to_input = to_model_input()

    def __call__(
        self, image: torch.Tensor, mask: torch.Tensor
    ) -> tuple[torch.Tensor, torch.Tensor]:
        resized = functional.resize(tv_tensors.Image(image), [self._short_side])
        model_input = self._to_input(resized)
        return model_input.as_subclass(torch.Tensor), mask.long()
