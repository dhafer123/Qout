import pytest
import torch

from qout_ml.metrics import ConfusionMeter, confusion_matrix, scores


def _t(rows: list[list[int]]) -> torch.Tensor:
    return torch.tensor(rows)


def test_confusion_counts_labels_by_prediction() -> None:
    target = _t([[0, 0, 1, 1]])
    pred = _t([[0, 1, 1, 1]])

    assert confusion_matrix(pred, target, num_classes=3).tolist() == [
        [1, 1, 0],
        [0, 2, 0],
        [0, 0, 0],
    ]


def test_ignored_pixels_are_skipped_whatever_the_prediction() -> None:
    target = _t([[255, 255, 1]])
    pred = _t([[0, 2, 1]])

    assert confusion_matrix(pred, target, num_classes=3).sum() == 1


def test_hand_made_iou() -> None:
    # class 0: 1 correct, union 2 -> 0.5; class 1: 2 correct, union 3 -> 2/3; class 2 absent.
    target = _t([[0, 0, 1, 1]])
    pred = _t([[0, 1, 1, 1]])

    result = scores(confusion_matrix(pred, target, num_classes=3))

    assert result.iou == (pytest.approx(0.5), pytest.approx(2 / 3), None)
    assert result.miou == pytest.approx((0.5 + 2 / 3) / 2)
    assert result.pixel_accuracy == pytest.approx(3 / 4)
    assert result.mean_accuracy == pytest.approx((1 / 2 + 2 / 2) / 2)


def test_class_predicted_but_never_labelled_scores_zero() -> None:
    target = _t([[0, 0]])
    pred = _t([[0, 2]])

    result = scores(confusion_matrix(pred, target, num_classes=3))

    assert result.iou == (pytest.approx(0.5), None, 0.0)
    assert result.miou == pytest.approx(0.25)


def test_perfect_and_all_wrong() -> None:
    target = _t([[0, 1], [1, 2]])

    assert scores(confusion_matrix(target, target, 3)).miou == 1.0
    wrong = scores(confusion_matrix((target + 1) % 3, target, 3))
    assert wrong.miou == 0.0
    assert wrong.pixel_accuracy == 0.0


def test_nothing_labelled_scores_zero() -> None:
    target = _t([[255, 255]])
    result = scores(confusion_matrix(_t([[0, 1]]), target, 2))

    assert result.iou == (None, None)
    assert (result.miou, result.pixel_accuracy, result.mean_accuracy) == (0.0, 0.0, 0.0)


def test_shapes_must_match() -> None:
    with pytest.raises(ValueError, match="differ"):
        confusion_matrix(_t([[0, 1]]), _t([[0], [1]]), 2)


@pytest.mark.parametrize(
    ("pred", "target", "what"),
    [
        ([[0, 5]], [[0, 1]], "prediction"),
        ([[0, 1]], [[0, 7]], "label"),
        ([[-1]], [[0]], "prediction"),
    ],
)
def test_class_ids_must_be_in_range(
    pred: list[list[int]], target: list[list[int]], what: str
) -> None:
    with pytest.raises(ValueError, match=what):
        confusion_matrix(_t(pred), _t(target), 3)


def test_meter_accumulates_over_images() -> None:
    meter = ConfusionMeter(num_classes=2)
    meter.update(_t([[0, 1]]), _t([[0, 0]]))
    meter.update(_t([[1, 1]]), _t([[1, 255]]))

    assert meter.confusion.tolist() == [[1, 1], [0, 1]]
    assert meter.compute().miou == pytest.approx((1 / 2 + 1 / 2) / 2)
