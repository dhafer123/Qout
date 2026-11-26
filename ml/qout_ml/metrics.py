"""Segmentation scores: confusion matrix, per-class IoU, mIoU, pixel and mean accuracy.

Same definitions as the FoodSeg103 benchmark (mmsegmentation): pixels marked
`ignore_index` are skipped; a class absent from both the labels and the predictions has
no IoU and is left out of the mean.
"""

from dataclasses import dataclass

import torch


def confusion_matrix(
    pred: torch.Tensor, target: torch.Tensor, num_classes: int, ignore_index: int = 255
) -> torch.Tensor:
    """(num_classes, num_classes) int64 counts; rows are labels, columns predictions."""
    if pred.shape != target.shape:
        msg = f"prediction {tuple(pred.shape)} and label {tuple(target.shape)} differ"
        raise ValueError(msg)
    valid = target != ignore_index
    labels = target[valid].long()
    preds = pred[valid].long()
    for name, values in (("label", labels), ("prediction", preds)):
        if values.numel() and (values.min() < 0 or values.max() >= num_classes):
            msg = f"{name} class ids must be in 0..{num_classes - 1}"
            raise ValueError(msg)
    counts = torch.bincount(labels * num_classes + preds, minlength=num_classes * num_classes)
    return counts.reshape(num_classes, num_classes)


@dataclass(frozen=True)
class Scores:
    iou: tuple[float | None, ...]
    """Per class; None when the class is in neither the labels nor the predictions."""
    miou: float
    pixel_accuracy: float
    mean_accuracy: float


def scores(confusion: torch.Tensor) -> Scores:
    confusion = confusion.double()
    correct = confusion.diag()
    labelled = confusion.sum(dim=1)
    predicted = confusion.sum(dim=0)
    union = labelled + predicted - correct

    iou = tuple(float(c / u) if u > 0 else None for c, u in zip(correct, union, strict=True))
    present = [value for value in iou if value is not None]
    class_accuracy = [float(c / n) for c, n in zip(correct, labelled, strict=True) if n > 0]
    total = float(labelled.sum())
    return Scores(
        iou=iou,
        miou=sum(present) / len(present) if present else 0.0,
        pixel_accuracy=float(correct.sum()) / total if total else 0.0,
        mean_accuracy=sum(class_accuracy) / len(class_accuracy) if class_accuracy else 0.0,
    )


class ConfusionMeter:
    """Accumulates a confusion matrix over many images."""

    def __init__(self, num_classes: int, ignore_index: int = 255) -> None:
        self.num_classes = num_classes
        self.ignore_index = ignore_index
        self.confusion = torch.zeros(num_classes, num_classes, dtype=torch.int64)

    def update(self, pred: torch.Tensor, target: torch.Tensor) -> None:
        self.confusion += confusion_matrix(
            pred.cpu(), target.cpu(), self.num_classes, self.ignore_index
        )

    def compute(self) -> Scores:
        return scores(self.confusion)
