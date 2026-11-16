# Qout (قوت)

[![Backend CI](https://github.com/dhafer123/Qout/actions/workflows/backend-ci.yml/badge.svg?branch=main)](https://github.com/dhafer123/Qout/actions/workflows/backend-ci.yml)
[![App CI](https://github.com/dhafer123/Qout/actions/workflows/app-ci.yml/badge.svg?branch=main)](https://github.com/dhafer123/Qout/actions/workflows/app-ci.yml)
[![Scoring parity](https://github.com/dhafer123/Qout/actions/workflows/scoring-parity.yml/badge.svg?branch=main)](https://github.com/dhafer123/Qout/actions/workflows/scoring-parity.yml)

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
api/openapi.json      API contract: exported from the backend, the app's client is generated from it
scoring-spec/golden/  Shared golden test cases for the Python and Dart scoring engines
docs/specs/           Official scoring specifications (source of all thresholds)
docs/adr/             Architecture decision records
docs/reports/         Engine validation and label parser evaluation reports
eval/labels/          Label parser evaluation set (real labels: ML Kit text, photo, ground truth)
scripts/              Repo-wide scripts (gen_client.sh)
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
| `s3-init` | `amazon/aws-cli:2.40.0` | – | One-shot: creates `S3_BUCKET` (private) and `S3_PUBLIC_BUCKET` (anyone can read an object, nobody can list), then exits 0 |

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

#### Database migrations (Alembic)

Migrations live in `backend/migrations/versions/` and use `DATABASE_URL` from `.env`.
The API never migrates on startup; run it explicitly:

```sh
uv run alembic upgrade head                              # apply all migrations
uv run alembic revision --autogenerate -m "add products" # after changing models
uv run alembic downgrade -1                              # undo the last one
uv run alembic check                                     # models and migrations in sync?
```

Always review autogenerated files before committing. The test suite also fails if a
model changes without a matching migration.

#### Tests and the database

Integration tests migrate `qout_test` (never the dev DB) once per run. Each test gets a
`db_session` inside a transaction that is rolled back afterwards, so tests can `commit()`
freely and still start clean. Build test data with the factories in
`backend/tests/factories.py`, not raw SQL.

| Endpoint | Purpose |
|---|---|
| `GET /health` | Liveness: always 200 while the process runs |
| `GET /health/ready` | Readiness: 200 if Postgres and Redis respond, else 503 with the failing checks |

#### Object storage and photo uploads

Photos live in S3-compatible storage (RustFS locally, ADR 0002), in two buckets:
`S3_BUCKET` (private: contribution photos) and `S3_PUBLIC_BUCKET` (product photos, served
from `MEDIA_BASE_URL`). The app uploads contribution photos straight to storage:
`POST /v1/uploads` (signed in) returns a presigned URL for one `PUT` of exactly the
declared type (JPEG or PNG) and size (`UPLOAD_MAX_BYTES`), under
`contributions/{user}/{contribution}/{kind}-{random}.{ext}`.

On a real phone, storage must be reachable from the phone: set `S3_PUBLIC_ENDPOINT_URL`
(and `MEDIA_BASE_URL`) to the PC's LAN address, and bind RustFS's port to it in
`docker-compose.yml` (it listens on 127.0.0.1 only by default). Integration tests use their
own buckets (`qout-test-uploads`, `qout-test-public`), created on the first run.

Logs are JSON lines on stdout. Every request gets an `X-Request-ID` (reused from the
request if valid, otherwise generated) that appears in the response and in log lines.
Settings come from environment variables and `.env` (see `.env.example`).

#### Worker and bulk import (arq)

The worker imports Open Food Facts products sold in `IMPORT_COUNTRIES` (default
`en:tunisia`) from OFF's bulk files: the **full export** (~14 GB JSONL, for seeding) and the
**daily delta files** (imported every day at `IMPORT_DELTA_CRON_HOUR` UTC). Imports are
idempotent: unchanged products stay untouched, changed ones get a new nutrition version
and are rescored, and records older than the stored data are ignored. Products from
contributions are never overwritten. Every file's progress is kept in `import_runs`; an
interrupted import (worker stopped, crash, network) resumes from its last checkpoint.

From `backend/`:

```sh
uv run arq app.worker.main.WorkerSettings            # start the worker (cron + queued jobs)
uv run python -m app.worker enqueue deltas           # queue: new delta files
uv run python -m app.worker enqueue export           # queue: full export (seed; hours)
uv run python -m app.worker enqueue export --force   # re-import the same export version
uv run python -m app.worker run deltas               # run now, in this process (no worker)
uv run python -m app.worker run images               # copy product photos now
```

Only one import runs at a time (Postgres advisory lock); a queued job that finds another
import running retries 10 minutes later. Downloads go to `IMPORT_DOWNLOAD_DIR`
(`backend/var/imports`, git-ignored) and are deleted once imported.

Inspect runs:

```sql
SELECT kind, source, status, checkpoint_line, inserted, updated, unchanged, skipped,
       rejected, failed, error
FROM import_runs ORDER BY created_at DESC LIMIT 20;
```

#### Contributions, error reports and moderation

Unknown products are added by contributors (signed in): the app uploads the photos
(`POST /v1/uploads`), then submits the reviewed fields with the OCR text
(`POST /v1/contributions`, same `client_id`; a resend returns the stored one). Photo keys
must be the contributor's own uploads for that contribution. `POST /v1/labels/parse`
reads the values from the nutrition table's OCR text (rule-based parser: French, English,
Arabic; checks in `docs/specs/README.md`), and `POST /v1/score/preview` scores values
without saving. Anyone can report an error on a product
(`POST /v1/reports`, duplicate-safe on `client_id`, `REPORT_MAX_PER_IP` per hour).

The parser is measured on real labels in `eval/labels/` (photographed with the dev
build's "Label OCR" screen; format and capture steps in its README). From `backend/`,
`uv run python -m scripts.eval_parser` writes
`docs/reports/label-parser-eval-rules-<date>.md`: field accuracy, per-field and per-tag
breakdowns, and labels the parser calls ok but got wrong.

Moderators (role `admin`) use `/v1/admin/...`: the pending queue, approve (the product
becomes verified, source `contribution`, so OFF imports leave it alone; the nutrition is a
new scored version; the front photo becomes the product photo) or reject (product
unchanged), and open reports. Until the admin panel (T31), make an account a moderator
in SQL: `UPDATE users SET role = 'admin' WHERE email = '...';`

#### Product photos

The app never calls Open Food Facts, so product photos are served from our storage. The
importer and the lookup store OFF's front photo URL (`source_image_url`; bulk files only
list the selected photos, so the URL is built from them). The `copy_product_images` job
(every 15 minutes, `PRODUCT_IMAGES_CRON_ENABLED`) downloads new and changed photos (OFF's
User-Agent and rate limit, at most `PRODUCT_IMAGE_MAX_BYTES`, JPEG or PNG only) into
`S3_PUBLIC_BUCKET` as `products/{ean}/front-{hash}.jpg`, and the API returns
`MEDIA_BASE_URL` + that key as `image_url` (null until copied). Photos OFF no longer has
are deleted; unusable ones are not fetched again until OFF's URL changes.

#### Rescoring and engine validation

Scores belong to an engine version (`ENGINE_VERSION`). Each worker start queues
`rescore_products` once per engine version, so deploying a new engine rescores every
product whose latest nutrition has no score with it (old scores are kept). Run it by hand
with `uv run python -m app.worker run rescore`.

To check the engine against Open Food Facts' own grades (from `backend/`, on the data in
`DATABASE_URL`):

```sh
uv run python -m scripts.validate_engine     # writes docs/reports/engine-validation-<version>-<date>.md
```

The report shows agreement (exact and within one grade), a confusion matrix, agreement
by category and by whether OFF estimated inputs, the largest mismatches, and products OFF
grades but we can't (insufficient data).

### API contract and generated client

`api/openapi.json` is the contract between backend and app. The app's client
(`app/lib/core/api/qout_api.dart`: models plus a dio-based `QoutApi`) is generated from it by
`app/tool/api_generator.dart`; never edit it by hand. After changing the API:

```sh
scripts/gen_client.sh          # export the spec (uv) and regenerate the client (dart)
scripts/gen_client.sh spec     # only the spec   (on Windows: inside WSL)
scripts/gen_client.sh client   # only the client (on Windows: Git Bash)
```

Commit both files together. Backend CI fails if the spec doesn't match the code; app CI
fails if the client doesn't match the spec. The generator supports what FastAPI emits for
the app's GET endpoints and stops with an error on anything else (for example request
bodies), so it has to be extended deliberately when the API grows.

### Run locally (placeholders until the corresponding tasks land)

```sh
# Infrastructure: Postgres, Redis, RustFS
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
