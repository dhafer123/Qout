# Qout meal model (`ml/`)

The food segmentation model behind "Photograph meal" in Quick add (TASKS.md, Phase 6):
datasets, training, evaluation and export to TFLite. It runs on the phone; nothing here is
deployed. Kept apart from `backend/` so PyTorch never ends up in the API image.

## Setup (WSL)

Like the backend, the virtualenv lives on the Linux side. `~/.profile` points
`UV_PROJECT_ENVIRONMENT` at the backend's venv, so set it for this project. Keep the
datasets on the Linux side too: training reads thousands of images, and reading them from
`/mnt/c` is much slower. Add this to `~/.profile` once:

```sh
export QOUT_ML_DATA_DIR="$HOME/qout-ml-data"
```

Then:

```sh
cd ml
export UV_PROJECT_ENVIRONMENT="$HOME/.venvs/qout-ml"
uv sync --extra cu132   # GPU (NVIDIA driver with CUDA 13.2 or newer); ~3.5 GB download
uv sync --extra cpu     # or: CPU only (CI, machines without a GPU)
uv run python -c "import torch; print(torch.cuda.is_available())"
```

Pick exactly one extra; they are two builds of the same PyTorch.

## Data

Everything goes to `QOUT_ML_DATA_DIR` (or `ml/var/`, git-ignored, if unset). Every file is
checked against a pinned checksum; files already there are not downloaded again.

```sh
uv run python -m qout_ml fetch foodseg103    # ~1.3 GB download -> var/foodseg103/{train,test}
uv run python -m qout_ml fetch nutrition5k   # ~200 MB -> var/nutrition5k/
```

| Dataset | Use | Source | Contents |
|---|---|---|---|
| **FoodSeg103** | Segmentation training and test | Hugging Face mirror `EduardoPacheco/FoodSeg103`, pinned revision (the official server was unreachable on 2026-11-26) | 4,983 train / 2,135 test photos with pixel masks; 104 classes (0 background, 1-103 foods), 255 = not labelled. Class names: [`classes/foodseg103.json`](classes/foodseg103.json) |
| **Nutrition5k** | Grams (T50) | Google's public bucket, CC BY 4.0 | A fixed sample of 500 dishes with an overhead photo and measured grams per ingredient, pinned in [`data/nutrition5k_sample.json`](data/nutrition5k_sample.json) |

The Nutrition5k sample was picked with `uv run python -m qout_ml nutrition5k-sample`
(seed 0, 500 dishes with an overhead photo, ingredients and a positive mass, from the official
RGB train and test splits). Run it again only to change the sample; commit the new file.

Dataset and model licences are to be checked before release (decided 2026-11-26).

## Checks

```sh
uv run ruff check . && uv run ruff format --check . && uv run mypy --strict qout_ml
uv run pytest    # unit tests, no network, no dataset needed; coverage >= 85 %
```

## Layout

```
qout_ml/data/download.py     pinned downloads (checksum, retries, no half-written files)
qout_ml/data/foodseg103.py   FoodSeg103 files, Parquet -> image/mask folders, dataset
qout_ml/data/nutrition5k.py  Nutrition5k metadata parser, pinned sample
qout_ml/data/transforms.py   training augmentation and evaluation resizing
qout_ml/metrics.py           confusion matrix, per-class IoU, mIoU
qout_ml/__main__.py          command line
```
