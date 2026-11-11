# Qout — task list

Work top to bottom. One task per session. Each task lists its tests; the global
Definition of Done in `CLAUDE.md` always applies. Tick boxes when done.

Legend: **U** = unit tests, **I** = integration tests, **W** = widget tests, **E2E** = end-to-end.

---

## Phase 0 — Foundations

### T01 · Repo skeleton and tooling
- [x] Monorepo folders: `backend/`, `app/`, `scoring-spec/golden/`, `docs/specs/`, `docs/adr/`, `.github/workflows/`
- [x] `.gitignore` (Python, Flutter, env files, IDE), `.editorconfig`, `.env.example`
- [x] `README.md` (one-paragraph pitch, stack, how to run — placeholders OK)
- [x] `docs/adr/0001-architecture.md`: modular monolith, Flutter + FastAPI, OFF as data source
- [x] Verify `.claude/settings.json` and `.githooks/commit-msg` are present; document `git config core.hooksPath .githooks` in README
- Tests: none (tooling only). Acceptance: a test commit shows no AI trailer.
- Done: hook verified with a throwaway commit containing `Co-Authored-By: Claude` and `Generated with Claude Code` lines; both were stripped.

### T02 · Local infrastructure
- [x] `docker-compose.yml`: Postgres 16, Redis 7, RustFS (+ bucket init), named volumes, healthchecks (MinIO replaced, see ADR 0002)
- [x] Separate test database (`qout_test`) created on startup
- Acceptance: `docker compose up -d` → all services healthy.
- [x] Acceptance run (2026-11-11, Docker Engine 29.9.3 / Compose v5.7.0 in WSL 2 Ubuntu 24.04): postgres, redis, rustfs healthy; s3-init exited 0 and created `qout-uploads`; `qout` and `qout_test` exist (owner `qout`); after `down` + `up` data persisted (Redis key, test DB) and bucket init reported "already exists".

### T03 · Backend skeleton
- [ ] uv project, FastAPI app factory, `core/config.py` (pydantic-settings), structured JSON logging, request-id middleware
- [ ] `GET /health` (app) and `GET /health/ready` (checks DB + Redis)
- [ ] ruff, mypy strict, pytest config, coverage config
- Tests: **U** config loading; **I** `/health` and `/health/ready` (ready returns 503 when DB is down — simulate).

### T04 · Database layer
- [ ] Async SQLAlchemy engine/session, Alembic configured for async, base model (id, created_at, updated_at)
- [ ] Test fixtures: clean DB per test, factory helpers
- Tests: **I** migration up/down round-trip; session fixture isolation test.

### T05 · Backend CI
- [ ] `.github/workflows/backend-ci.yml`: on PR + push, path filter `backend/**`; Postgres + Redis service containers; uv cache; ruff, mypy, pytest with coverage gate
- Acceptance: a PR touching `backend/` runs the job and passes; a PR touching only `app/` skips it.

### T06 · Flutter skeleton
- [ ] Flutter app (package `tn.qout.app` — confirm with me), Riverpod, go_router, very_good_analysis, freezed, flavors/env config (dev, staging, prod API URLs)
- [ ] Folder structure per `CLAUDE.md`, theme (light/dark), placeholder home with "Scan" button
- Tests: **W** app boots and shows home; **U** env config resolves per flavor.

### T07 · App CI
- [ ] `.github/workflows/app-ci.yml`: path filter `app/**`; pub cache; format check, analyze, test; build debug APK
- Acceptance: runs only for `app/**` changes and passes.

---

## Phase 1 — Scoring engine (the core)

### T08 · Scoring spec and golden format
- [ ] `docs/specs/`: I add the official Nutri-Score specification (current revised algorithm). **Claude: if it is missing, stop and ask.**
- [ ] `scoring-spec/schema.json`: JSON schema for a golden case (category, nutrients per 100 g/ml, expected points per component, expected total, expected grade)
- [ ] 20+ golden cases covering every category (general, beverages, fats/oils/nuts/seeds, cheese, water) and boundary values
- Tests: **U** every golden file validates against the schema.

### T09 · Nutri-Score engine (Python)
- [ ] `modules/scoring/`: pure functions; input dataclass (nutrients + category); output (grade, total, per-component points, engine_version)
- [ ] Separate point tables per category, taken from `docs/specs/` only
- [ ] Returns `InsufficientData` (listing missing fields) instead of guessing
- [ ] Unit conversions in one place: kJ/kcal, sodium → salt
- Tests: **U** each component table at boundaries; all golden cases; **U (hypothesis)** monotonicity (more sugar/sat-fat/salt/energy never improves the score; more fibre/protein never worsens it, within the rules), determinism; missing-field cases. Coverage ≥ 95 %.

### T10 · Extra signals
- [ ] NOVA group (taken from OFF data, not computed), additives list with a simple risk flag from a documented source file in `docs/specs/`
- Tests: **U** mapping functions, unknown values handled.

### T11 · Dart engine port and parity check
- [ ] `app/lib/scoring/`: same API as Python, same golden cases
- [ ] CI job `scoring-parity`: runs golden cases in both languages; fails on any mismatch
- Tests: **U** all golden cases in Dart; parity job green.

---

## Phase 2 — Product data

### T12 · Product data model
- [ ] Tables: `products` (ean, name, brand, category, image_url, source, status, quality_flag), `nutrition_facts` (per 100 g/ml, versioned), `scores` (engine_version, grade, total, breakdown JSONB, off_grade), `scan_events`
- [ ] Alembic migration, repositories, Pydantic schemas
- Tests: **I** repository CRUD, unique EAN constraint, latest-score query.

### T13 · Open Food Facts client and normaliser
- [ ] httpx client with required custom User-Agent, timeouts, retries with backoff, rate limiting
- [ ] Normaliser: OFF JSON → our schema; per-serving → per-100 g refusal or conversion, kJ/kcal, sodium → salt, OFF categories → our scoring categories, quality flag
- [ ] EAN utils: checksum validation, UPC-A → EAN-13
- Tests: **U** normaliser on 15+ recorded OFF fixtures (complete, partial, beverage, cheese, oil, missing category, garbage values); EAN utils; **U** client retry/timeout via respx.

### T14 · Product lookup endpoint
- [ ] Service: DB → OFF → save + score → return; 404 for unknown; invalid EAN → 422
- [ ] Redis cache for hot products (TTL, invalidated on update)
- [ ] `GET /v1/products/{ean}` returns product, nutrients, score + breakdown, source, updated_at
- Tests: **I** DB hit, OFF hit (respx) saved and scored, OFF miss → 404, OFF down → graceful 503/fallback, cache hit avoids DB, invalid EAN.

### T15 · Worker and bulk import
- [ ] arq worker setup; job: import OFF products for Tunisia (and configurable country list) from OFF export/delta files
- [ ] Idempotent upsert, progress logging, resumable
- Tests: **U** parsing a small fixture export; **I** import job twice → no duplicates, updated rows rescored.

### T16 · Rescoring and validation report
- [ ] Job: rescore all products when `ENGINE_VERSION` changes
- [ ] Script `scripts/validate_engine.py`: compares our grade with OFF grade, outputs agreement %, confusion matrix, top mismatches (markdown report in `docs/reports/`)
- Tests: **I** rescoring updates only outdated scores; **U** report metrics on a fixture.

---

## Phase 3 — App core

### T17 · Generated API client
- [ ] Export OpenAPI from backend; generate Dart client (openapi-generator or a small hand-written dio layer — propose one); script `scripts/gen_client.sh`
- [ ] CI check: committed client matches the current spec
- Tests: **U** client deserialises a recorded product response.

### T18 · Local database and repository
- [ ] drift DB: cached products, scan history, contribution outbox
- [ ] `ProductRepository.get(ean)`: cache → API → cache write; stale-while-revalidate
- Tests: **U** repository with fake API and in-memory drift: cache hit, miss, offline, API 404.

### T19 · Scan feature
- [ ] mobile_scanner limited to EAN-13/EAN-8/UPC-A/UPC-E; accept a code after N identical consecutive reads; checksum validation; haptic feedback; torch toggle; permission handling
- Tests: **U** debounce/validation logic (extract it from the widget); **W** permission-denied state.

### T20 · Product result screen
- [ ] Grade badge, "why this score" breakdown, nutrients per 100 g, NOVA, additives, source + date, "report an error", insufficient-data state, unknown-product state → "Add this product"
- Tests: **W** each state (full, insufficient data, unknown, offline cached).

### T21 · Scan history
- [ ] List of past scans (offline), delete, tap to reopen
- Tests: **U** history repository; **W** list and empty state.

### T22 · Better alternatives
- [ ] Backend: `GET /v1/products/{ean}/alternatives` — same category, better grade, nutrient similarity ranking
- [ ] App: alternatives row on the result screen
- Tests: **U** ranking function; **I** endpoint; **W** alternatives row.

---

## Phase 4 — Contributions (unknown products)

### T23 · Authentication
- [ ] Register/login, JWT access (15 min) + rotating refresh tokens, rate-limited login; only contributors need an account
- [ ] App: auth screens, secure token storage, refresh interceptor
- Tests: **U** token service; **I** register, login, refresh rotation, reuse detection, rate limit; **W** login form validation.

### T24 · Photo uploads
- [ ] Presigned upload URLs (S3/RustFS), size/type limits, key naming per contribution
- Tests: **I** presign against RustFS; rejects wrong content type.

### T25 · Contributions API and moderation states
- [ ] `contributions` table (photos, OCR text, parsed fields, parser_used, status: pending/approved/rejected)
- [ ] `POST /v1/contributions`; `POST /v1/score/preview`; approval creates/updates the product as verified and scores it
- Tests: **I** submit → pending; preview scores without saving; approve → product verified; reject keeps product unchanged; auth required.

### T26 · Rule-based label parser
- [ ] Parse OCR text (French, plus Arabic labels where possible) into nutrient fields per 100 g; handle OCR noise (O/0, comma decimals), per-100 g vs per-portion columns
- [ ] Sanity checks: macros ≤ 100 g, sugars ≤ carbs, sat-fat ≤ fat, energy ≈ 4/4/9 rule within tolerance
- Tests: **U** 20+ OCR text fixtures; each sanity rule.

### T27 · Label evaluation set
- [ ] I photograph ~50 real Tunisian labels; `eval/labels/` with OCR text + ground truth JSON
- [ ] `scripts/eval_parser.py`: field-level accuracy, per-field breakdown, markdown report
- Tests: **U** metric computation.

### T28 · LLM fallback parser (behind a feature flag)
- [ ] Called only when rules fail or sanity checks fail; strict JSON schema output; same sanity checks; timeout + fallback to "needs manual entry"; only OCR text is sent
- [ ] Runs in the worker; result stored with `parser_used = llm`
- [ ] Re-run eval: report rules-only vs rules+LLM
- Tests: **U** schema validation, invalid/hallucinated output rejected (mocked LLM); **I** job flow with mocked LLM.

### T29 · App contribution flow
- [ ] Capture 3 photos (front, nutrition table, ingredients); ML Kit OCR on device; send OCR text; show parsed fields in an editable review form; provisional score (Dart engine) marked "unverified"; upload photos; submit
- Tests: **U** form validation and state notifier; **W** review form; **E2E** happy path with fake API.

### T30 · Offline outbox
- [ ] Contributions queued in drift when offline; background sync with retry/backoff; status shown in UI
- Tests: **U** outbox sync (success, failure, retry, duplicate-safe via client-generated id).

### T31 · Admin panel
- [ ] SQLAdmin for products/scores/users (admin role only)
- [ ] Custom moderation page: photos next to parsed fields, edit, approve/reject
- Tests: **I** admin routes require admin role; approve/reject via moderation endpoints.

---

## Phase 5 — Delivery

### T32 · CD to staging
- [ ] Backend Dockerfile (multi-stage, non-root); build + push to GHCR on merge to `main`
- [ ] Deploy to staging host, run migrations, smoke test (`/health/ready` + sample EAN lookup)
- Acceptance: merge to `main` → staging updated automatically.

### T33 · Android release pipeline
- [ ] Release signing via GitHub Secrets; fastlane lane uploading AAB to Play internal testing on merge to `main`; build number from CI run
- Acceptance: merge → new internal test build. (I create the Play Console account and keystore.)

### T34 · Production release
- [ ] On tag `v*`: promote the staging image to prod (manual approval via GitHub Environments), backup DB before migrate, promote Android build track, generate changelog from commits
- Acceptance: tagging releases to prod; rollback procedure documented.

### T35 · Observability and hardening
- [ ] Sentry (backend + app), structured logs, rate limiting on public endpoints, CORS for admin only, security headers, dependency scanning (Dependabot), nightly DB backup + restore test doc
- Tests: **I** rate limit returns 429.

### T36 · End-to-end pass
- [ ] Flutter `integration_test` suite: scan (mocked scanner) → result; unknown → contribute → pending; offline history
- [ ] Backend contract tests: app fixtures match current OpenAPI schemas
- Acceptance: E2E job in CI green.

### T37 · Portfolio polish
- [ ] README: screenshots/GIF, architecture diagram, metrics (OFF agreement %, parser accuracy, test counts, latency), how to run, Play Store link
- [ ] `docs/` cleanup; license file; privacy policy page (required for Play Store)

---

## Notes / decisions log
- (add decisions here as tasks are done)
- 2026-11-11 (T01): added `.gitattributes` forcing LF line endings (Windows + WSL + shell hooks). Solo workflow: work is pushed directly to `main` (no PRs) unless decided otherwise. Shared `.claude/settings.json` is tracked; `.claude/settings.local.json` is ignored.
- 2026-11-11 (T02): MinIO replaced by RustFS 1.0.5 (MinIO archived, images unpublished), see ADR 0002. Bucket created by a one-shot `amazon/aws-cli` container. Containers run on Docker Engine inside WSL 2, not Docker Desktop. Workflow changed to direct commits on `main` (CLAUDE.md updated).
