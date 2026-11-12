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
- [x] uv project, FastAPI app factory, `core/config.py` (pydantic-settings), structured JSON logging, request-id middleware
- [x] `GET /health` (app) and `GET /health/ready` (checks DB + Redis)
- [x] ruff, mypy strict, pytest config, coverage config
- Tests: **U** config loading; **I** `/health` and `/health/ready` (ready returns 503 when DB is down — simulate).
- Done: 50 tests (unit + integration), coverage 100 %. Outages simulated for real: DB/Redis on a closed port (refused) and a silent TCP server (hung, hits the per-check timeout). Logging uses a stdlib JSON formatter (no structlog). App factory lives in `app/factory.py`; `app/main.py` only builds the app.

### T04 · Database layer
- [x] Async SQLAlchemy engine/session, Alembic configured for async, base model (id, created_at, updated_at)
- [x] Test fixtures: clean DB per test, factory helpers
- Tests: **I** migration up/down round-trip; session fixture isolation test.
- Done: 71 tests, coverage 100 %. UUID primary keys (`gen_random_uuid()`); `created_at`/`updated_at` set by Postgres (`now()` on insert, `clock_timestamp()` on update). Migrations tested by round-trip, per-revision stairway and a model drift check. Empty baseline revision; real tables start in T12. Hand-written async factories (`tests/factories.py`), no factory_boy. Test-only models live in a `testing` schema with their own metadata. New env vars: `DATABASE_POOL_SIZE`, `DATABASE_MAX_OVERFLOW`.

### T05 · Backend CI
- [x] `.github/workflows/backend-ci.yml`: on PR + push, path filter `backend/**`; Postgres + Redis service containers; uv cache; ruff, mypy, pytest with coverage gate
- Acceptance (adapted to direct pushes on `main`): a push touching `backend/` runs the job and passes; a push touching only `app/` or docs skips it.
- Done: green run in ~35 s (71 tests, coverage 100 %). Triggers: push to `main` + PRs (path filter `backend/**` and the workflow file) + manual `workflow_dispatch`. Service containers use the compose image versions; `qout_test` is the default DB there because service containers can't run the init script. uv 0.13.7 pinned, `UV_LOCKED=1`, coverage gate from `pyproject.toml`. The ≥ 95 % gate for `modules/scoring` is added in T09 when the module exists. CI badge in README.

### T06 · Flutter skeleton
- [x] Flutter app (package `tn.qout.app` — confirmed), Riverpod, go_router, very_good_analysis, freezed, flavors/env config (dev, staging, prod API URLs)
- [x] Folder structure per `CLAUDE.md`, theme (light/dark), placeholder home with "Scan" button
- Tests: **W** app boots and shows home; **U** env config resolves per flavor.
- Done: 26 tests, line coverage 100 % except one line in `app.dart`. Android only (iOS flavors need Xcode; separate task later). Flutter 3.38.9 / Dart 3.10.8. Riverpod **2.6.1**: Riverpod 3 conflicts with freezed over `analyzer` on this SDK. Android flavors `dev`/`staging`/`prod` with `.dev`/`.staging` ID suffixes; flavor is mandatory (app fails at startup without one); `--dart-define=API_BASE_URL` overrides the URL. Generated `*.freezed.dart` files are committed. `flutter build apk --debug --flavor dev` verified (`tn.qout.app.dev`, label "Qout Dev").

### T07 · App CI
- [x] `.github/workflows/app-ci.yml`: path filter `app/**`; pub cache; format check, analyze, test; build debug APK
- Acceptance: runs only for `app/**` changes and passes.
- Done: green run in ~6.5 min (most of it the Gradle build). Flutter pinned to 3.38.9 (bump together with the local SDK); Java 17 Temurin with Gradle cache; Flutter SDK + pub cache. `pub get --enforce-lockfile`; fails if committed generated code is stale (`build_runner` + `git status`). Coverage printed to the job summary, no gate (none required for the app). The `dev` debug APK is uploaded as artifact `qout-dev-debug-apk` (7 days). Verified: the workflow push ran App CI only; docs-only pushes run neither workflow. CI badge in README.

---

## Phase 1 — Scoring engine (the core)

### T08 · Scoring spec and golden format
- [x] `docs/specs/`: I add the official Nutri-Score specification (current revised algorithm). **Claude: if it is missing, stop and ask.**
- [x] `scoring-spec/schema.json`: JSON schema for a golden case (category, nutrients per 100 g/ml, expected points per component, expected total, expected grade)
- [x] 20+ golden cases covering every category (general, beverages, fats/oils/nuts/seeds, cheese, water) and boundary values
- Tests: **U** every golden file validates against the schema.
- Done: specs = Q&A V11, 2022 foods and 2023 beverages Scientific Committee reports, official calculator (2024-04-04); `docs/specs/README.md` lists sources, where each rule lives and 7 interpretation decisions. 57 golden cases: the calculator's 20 official examples (+ water) with official results, boundary cases for every table/grade edge/protein rule/red meat cap, and insufficient-data cases. Categories: `general`, `red_meat`, `cheese`, `fats_oils_nuts_seeds`, `beverage`, `water` (red meat added: it has its own rule). Expected values cross-checked with a throwaway reference that reproduces all official examples. Tests (`backend/tests/unit/test_golden_cases.py`, 130+ checks): schema validity, ids, category coverage, totals add up, schema rejects invalid cases. New dev dependency `jsonschema`. Backend CI also runs on `scoring-spec/**`.

### T09 · Nutri-Score engine (Python)
- [x] CI: add the ≥ 95 % coverage gate for `modules/scoring` (from T05)
- [x] `modules/scoring/`: pure functions; input dataclass (nutrients + category); output (grade, total, per-component points, engine_version)
- [x] Separate point tables per category, taken from `docs/specs/` only
- [x] Returns `InsufficientData` (listing missing fields) instead of guessing
- [x] Unit conversions in one place: kJ/kcal, sodium → salt
- Tests: **U** each component table at boundaries; all golden cases; **U (hypothesis)** monotonicity (more sugar/sat-fat/salt/energy never improves the score; more fibre/protein never worsens it, within the rules), determinism; missing-field cases. Coverage ≥ 95 %.
- Done: 646 backend tests (388 for the engine), scoring coverage 100 %. API: `score(category, NutritionInput)` → `NutriScore` (grade, `Breakdown` with points per component, N/P totals, `protein_counted`, score; `engine_version`) or `InsufficientData` (sorted missing fields); water → A with no breakdown. `ENGINE_VERSION = "nutriscore-2023.1"`. Thresholds compared as exact decimals (`Decimal(repr(x))`) so float noise never moves a value across a threshold (e.g. 0.58 g / 1 g fat = 58 %, not 57.99…). Impossible inputs (negative, NaN, > 100 g per 100 g, > 100 %) raise `ValueError`. kJ = ROUND(kcal × 4.2) half up like Excel. Tests: every table threshold transcribed separately from the calculator, all 57 golden cases, rule tests, hypothesis properties (monotonicity, determinism, every result is a valid golden case). New dev dependency `hypothesis`. CI: extra `coverage report` step with the 95 % gate.

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
- [ ] Replace the placeholder staging/prod API URLs (`*.qout.invalid`) in `app/lib/core/env/app_env.dart`
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
- 2026-11-11 (T03): backend runs in WSL with uv; virtualenv kept on the Linux side via `UV_PROJECT_ENVIRONMENT` (repo stays on `C:`). Integration tests fail fast with a clear message when the compose stack is down.
- 2026-11-11 (T04): the API does not run migrations on startup; `alembic upgrade head` is an explicit step (CD step in T32). Fixed: the integration conftest hook had marked unit tests as `integration` too.
- 2026-11-11 (T06): stayed on Flutter 3.38.9. Follow-up when Flutter is upgraded: move to Riverpod 3 (blocked by the freezed/analyzer constraint on Dart 3.10). Seed color `#2E7D32` is a placeholder until the visual identity exists.
- 2026-11-11 (T05): first push-triggered run was stuck in `queued` by a GitHub Actions outage; re-run via `workflow_dispatch` once it recovered.
- 2026-11-11 (T08): the official calculator holds only ~20 example products (the rest are empty template rows). Decisions recorded in `docs/specs/README.md`: exact-threshold values get the lower points (calculator `<=`), except the fats saturates/fat ratio (`<`); beverage salt 3.2 g → 15 points (calculator typo); total fat 0 in the fats category → insufficient data. For T09: kcal→kJ factor 4.2 (calculator), sugar alcohols are not non-nutritive sweeteners, alcoholic drinks > 1.2 % are out of scope.
- 2026-11-12 (T09): Dart port (T11) must also compare thresholds on exact decimals (e.g. integer scaling), not doubles, to keep parity. The calculator's general foods sheet rounds protein to 2 decimals; we don't (recorded in `docs/specs/README.md`, decision 7). Follow-up for T13: a missing fruit/vegetable/legume % gives `InsufficientData`, and OFF often lacks it; the normaliser must map OFF's estimate (e.g. `fruits-vegetables-legumes-estimate-from-ingredients`) or many products stay unscored.
