# Qout (قوت)

**Qout** ("nourishment" in Arabic) is a mobile app that tells you what's really in your food.
Scan a barcode or photograph a nutrition label and get an **explainable nutrition score**:
a Nutri-Score grade with a breakdown of why it got that grade, NOVA processing level, and
additives. When a product is unknown, users can contribute it from photos of the label, so
coverage grows for local (Tunisian) products that global databases miss.

> Status: early development. See [`TASKS.md`](TASKS.md) for the roadmap.

## Stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter (Android first, iOS later), Riverpod, go_router, dio, drift, mobile_scanner, ML Kit text recognition |
| Backend | Python 3.12, FastAPI, SQLAlchemy 2 (async) + Alembic, Pydantic v2, arq worker |
| Data | PostgreSQL, Redis (cache + job queue), S3-compatible object storage (MinIO locally) |
| External | Open Food Facts (backend only), optional LLM API for label parsing |
| CI/CD | GitHub Actions |

Architecture decisions are recorded in [`docs/adr/`](docs/adr/), starting with
[ADR 0001](docs/adr/0001-architecture.md).

## Repository layout

```
backend/              FastAPI modular monolith (api, modules, core, worker)
app/                  Flutter app (feature-first clean architecture)
scoring-spec/golden/  Shared golden test cases for the Python and Dart scoring engines
docs/specs/           Official scoring specifications (source of all thresholds)
docs/adr/             Architecture decision records
.github/workflows/    CI pipelines
.githooks/            Shared git hooks
```

## Getting started

### Prerequisites

- Git, Docker Desktop (with WSL 2 on Windows)
- [uv](https://docs.astral.sh/uv/) and Python 3.12 (backend)
- Flutter SDK (app)

### One-time setup after cloning

```sh
# Enable the shared git hooks (commit-msg hook keeps commit messages clean)
git config core.hooksPath .githooks

# Create your local environment file and fill in real values
cp .env.example .env
```

### Run locally (placeholders until the corresponding tasks land)

```sh
# Infrastructure: Postgres, Redis, MinIO
docker compose up -d

# Backend (from backend/)
uv sync
uv run alembic upgrade head
uv run uvicorn app.main:app --reload

# App (from app/)
flutter pub get
flutter run
```

### Checks

```sh
# Backend (from backend/)
uv run ruff check . && uv run ruff format --check . && uv run mypy --strict app && uv run pytest

# App (from app/)
dart format --set-exit-if-changed . && flutter analyze && flutter test
```

## Author

Dhafer Romdhani. Solo portfolio project.
