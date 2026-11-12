# Qout — project instructions for Claude Code

Qout (قوت, "nourishment") is a mobile app: scan a food barcode or photograph a nutrition
label and get an explainable nutrition score. Solo portfolio project by Dhafer Romdhani.

## Architecture (summary)

- `app/` — Flutter (Android first, iOS later). Riverpod, go_router, dio, drift,
  mobile_scanner, google_mlkit_text_recognition. Feature-first clean architecture.
- `backend/` — Python 3.12, FastAPI, SQLAlchemy 2 (async) + Alembic, Pydantic v2,
  arq worker on Redis, httpx. Modular monolith: `api/`, `modules/{products,scoring,
  ingestion,contributions,auth}`, `core/`, `worker/`.
- `scoring-spec/golden/*.json` — shared test cases. Python AND Dart engines must
  produce identical results for every file.
- Data: PostgreSQL, Redis (cache + job queue), S3-compatible object storage (RustFS locally, see ADR 0002).
- External: Open Food Facts (called from the backend only, never from the app), optional LLM API.
- Local dev: Docker Engine + Compose inside WSL 2 (no Docker Desktop) for Postgres/Redis/RustFS; backend in WSL 2; Flutter on Windows.

Lookup chain for a barcode: app local cache → `GET /v1/products/{ean}` → our DB →
Open Food Facts → 404 (unknown → contribution flow).

## Non-negotiable rules

1. **Git authorship: Dhafer is the only author.** Never add `Co-Authored-By`,
   `Generated with Claude Code`, or any AI/Claude mention to commit messages, PR titles,
   PR descriptions, code comments, or docs. Use the existing git user config; never
   change `user.name` / `user.email`.
2. **Never invent scoring thresholds or nutrition constants.** Scoring tables come only
   from the official specification files in `docs/specs/`. If a value is missing or
   ambiguous, stop and ask.
3. **No network in tests.** Mock HTTP with `respx` (Python) or `mocktail`/fake clients
   (Dart). Use recorded JSON fixtures in `tests/fixtures/`.
4. **Secrets never in the repo.** Use `.env` (git-ignored) and `.env.example` with dummy values.
5. One task from `TASKS.md` per session unless told otherwise. Do not start the next task.

## Workflow for each task

1. Read the task in `TASKS.md`. Read the relevant existing code.
2. Post a short plan (files to add/change, tests to write, open questions). **Wait for my OK.**
3. Work directly on `main` (solo project: no feature branches, no PRs).
4. Implement in small commits. Write tests alongside the code, not at the end.
5. Run all checks locally (see below). Everything must pass before pushing.
6. Tick the task's checkboxes in `TASKS.md`, add notes if something changed.
7. Push to `main` (`git push origin main`). Never force-push.
8. End with a summary: what was done, how to test it manually, any follow-ups.

## Commit messages

Conventional Commits, imperative, English: `feat(scoring): add Nutri-Score fat/oil table`.
Body explains why if not obvious. No trailers.

## Definition of done (every task)

- Unit tests for all new logic; integration tests where a task touches the DB, HTTP API,
  queue, or storage. Bug fixes come with a regression test.
- Backend: `ruff check`, `ruff format --check`, `mypy --strict app`, `pytest` all green.
  Coverage ≥ 85 % overall, ≥ 95 % for `modules/scoring`.
- App: `dart format --set-exit-if-changed .`, `flutter analyze` (very_good_analysis),
  `flutter test` all green.
- New env vars added to `.env.example`. New endpoints visible in the OpenAPI spec.
- No TODOs left without a matching item in `TASKS.md`.

## Commands

Backend (run from `backend/`, uses uv):
- `uv sync` · `uv run uvicorn app.main:app --reload`
- `uv run pytest` · `uv run ruff check . && uv run ruff format --check . && uv run mypy --strict app`
- `uv run alembic upgrade head` · `uv run alembic revision --autogenerate -m "..."`
- `uv run arq app.worker.main.WorkerSettings`

Infra (repo root): `docker compose up -d` · `docker compose down`

App (run from `app/`):
- `flutter pub get` · `dart run build_runner build --delete-conflicting-outputs --force-jit` (JIT: drift's sqlite3 has native build hooks, which AOT builder compilation rejects)
- `flutter analyze` · `flutter test` · `flutter test integration_test`

## Testing conventions

- Python: pytest + pytest-asyncio; `tests/unit/` (pure, fast) and `tests/integration/`
  (real Postgres/Redis from docker compose locally, service containers in CI).
  API tests use `httpx.AsyncClient` with the ASGI app. Each test gets a clean DB
  (transaction rollback or truncate fixture). Use factories, not raw SQL.
- Property-based tests (hypothesis) for the scoring engine (e.g. more sugar never
  improves the score; score is deterministic).
- Dart: unit tests for repositories/parsers/engine, widget tests for screens,
  `integration_test/` for the main flows with a fake API.
- Golden scoring cases: `scoring-spec/golden/*.json` are run by both test suites.

## Style

- Python: type hints everywhere, small pure functions, services don't import FastAPI,
  routers stay thin. Pydantic schemas separate from SQLAlchemy models.
- Dart: feature folders (`data/`, `domain/`, `presentation/`), immutable models
  (freezed), no business logic in widgets.
- Keep dependencies minimal; ask before adding a new package.
