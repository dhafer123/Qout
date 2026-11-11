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
| Data | PostgreSQL, Redis (cache + job queue), S3-compatible object storage (RustFS locally) |
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

- Git
- Docker Engine + Compose plugin. On Windows: run it inside WSL 2 (e.g. Ubuntu 24.04 with
  `docker-ce` and `docker-compose-plugin`); Docker Desktop is not required.
- [uv](https://docs.astral.sh/uv/) and Python 3.12 (backend)
- Flutter SDK (app)

### One-time setup after cloning

```sh
# Enable the shared git hooks (commit-msg hook keeps commit messages clean)
git config core.hooksPath .githooks

# Create your local environment file and fill in real values
cp .env.example .env
```

### Local infrastructure

`docker-compose.yml` runs everything the backend needs:

| Service | Image | Address (localhost only) | Notes |
|---|---|---|---|
| `postgres` | `postgres:16.15-alpine` | `localhost:5432` | Databases `qout` and `qout_test` |
| `redis` | `redis:7.4.12-alpine` | `localhost:6379` | AOF persistence |
| `rustfs` | `rustfs/rustfs:1.0.5` | API `localhost:9000`, console http://localhost:9001 | S3-compatible; log in with `S3_ACCESS_KEY` / `S3_SECRET_KEY` |
| `s3-init` | `amazon/aws-cli:2.40.0` | – | One-shot: creates `S3_BUCKET`, then exits 0 |

```sh
docker compose up -d        # start (data kept in named volumes)
docker compose ps           # postgres, redis, rustfs should be "healthy"
docker compose down         # stop, keep data
docker compose down -v      # stop and delete all data (fresh start)
```

The test database is created by `infra/postgres/init/` only when the Postgres volume is
empty. If you change `POSTGRES_TEST_DB` later, run `docker compose down -v` and start again.

### Backend

Runs inside WSL (Ubuntu) with [uv](https://docs.astral.sh/uv/)
(`curl -LsSf https://astral.sh/uv/install.sh | sh`). If the repo lives on the Windows
drive (`/mnt/c/...`), keep the virtualenv on the Linux side. It's faster and avoids
clashes with Windows. Add this to `~/.profile` once:

```sh
export UV_PROJECT_ENVIRONMENT="$HOME/.venvs/qout-backend"
export UV_LINK_MODE=copy
```

From `backend/`:

```sh
uv sync                                  # install dependencies
uv run uvicorn app.main:app --reload     # http://localhost:8000/docs
uv run pytest                            # unit + integration (needs docker compose up -d)
uv run pytest tests/unit                 # unit tests only, no services needed
```

| Endpoint | Purpose |
|---|---|
| `GET /health` | Liveness: always 200 while the process runs |
| `GET /health/ready` | Readiness: 200 if Postgres and Redis respond, else 503 with the failing checks |

Logs are JSON lines on stdout. Every request gets an `X-Request-ID` (reused from the
request if valid, otherwise generated) that appears in the response and in log lines.
Settings come from environment variables and `.env` (see `.env.example`).

### Run locally (placeholders until the corresponding tasks land)

```sh
# Infrastructure: Postgres, Redis, RustFS
docker compose up -d

# Backend (from backend/)
uv sync
uv run alembic upgrade head   # from T04
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
