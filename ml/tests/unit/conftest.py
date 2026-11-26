import pytest
import torch


@pytest.fixture(autouse=True)
def _seeded() -> None:
    torch.manual_seed(0)
