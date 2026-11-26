"""Where the ML project keeps its downloads and generated data."""

import os
from pathlib import Path

ML_ROOT = Path(__file__).resolve().parent.parent


def data_dir() -> Path:
    """Git-ignored folder for datasets: `QOUT_ML_DATA_DIR`, or `ml/var`."""
    override = os.environ.get("QOUT_ML_DATA_DIR")
    return Path(override) if override else ML_ROOT / "var"
