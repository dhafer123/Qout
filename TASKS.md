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
- [x] NOVA group (taken from OFF data, not computed), additives list with a simple risk flag from a documented source file in `docs/specs/`
- Tests: **U** mapping functions, unknown values handled.
- Done: 713 backend tests (455 in `tests/unit/scoring`), scoring coverage 100 %. `nova_group_from_off(value)` → `NovaGroup` 1–4 or None (accepts 4, "4", 4.0; anything else unknown). `additives_from_off(additives_tags)` → `Additive` (code, English name, `OverexposureRisk` high/moderate/none/unknown, `risk_from`, EFSA link, `in_taxonomy`), order kept, duplicates and malformed tags dropped, codes missing from the taxonomy kept as unknown. Source: Open Food Facts additives taxonomy pinned at `openfoodfacts-server` `7fbee09` (`docs/specs/off-additives-taxonomy-7fbee09.txt`); 726 additives, 65 with their own EFSA flag, 37 inheriting their parent group's, 624 unknown. `data/additives.json` is generated by `uv run python -m app.modules.scoring.taxonomy` (the image won't ship `docs/`) and a test fails if it is stale.

### T11 · Dart engine port and parity check
- [x] `app/lib/scoring/`: same API as Python, same golden cases
- [x] CI job `scoring-parity`: runs golden cases in both languages; fails on any mismatch
- Tests: **U** all golden cases in Dart; parity job green.
- Done: Dart engine in `app/lib/scoring/` (Nutri-Score only; NOVA and additives come from the API): `score(category, NutritionInput)` → sealed `ScoreResult` (`NutriScore` with `Breakdown`, or `InsufficientData`), `kjFromKcal`, `saltFromSodium`, same spec names and `engineVersion`. Exact arithmetic via a small `ExactDecimal` (BigInt, no new package): doubles are read as their shortest decimal like Python's `repr`, and the fats ratio is compared by cross-multiplying. 419 Dart scoring tests (445 app tests), all 57 golden cases pass. Parity: `scoring-spec/parity/inputs.json` (4213 deterministic cases: golden inputs, every threshold exactly and ±0.001, 600 random products per category with missing fields), scored by `python -m app.modules.scoring.parity run` and `dart run tool/scoring_parity.dart`, compared by `parity compare`: identical. Verified the check by injecting a Dart bug (52 mismatches). CI job `scoring-parity` (new workflow + README badge). Backend: 728 tests, coverage 100 %.

---

## Phase 2 — Product data

### T12 · Product data model
- [x] Tables: `products` (ean, name, brand, category, image_url, source, status, quality_flag), `nutrition_facts` (per 100 g/ml, versioned), `scores` (engine_version, grade, total, breakdown JSONB, off_grade), `scan_events`
- [x] Alembic migration, repositories, Pydantic schemas
- Tests: **I** repository CRUD, unique EAN constraint, latest-score query.
- Done: `modules/products/` (models, repositories, schemas, engine mapping) + one migration. 859 backend tests, coverage 100 %. Constraints enforced by Postgres: EAN 8–14 digits and unique, enum CHECKs (VARCHAR, no native PG enums), amounts ≥ 0 and ≤ 100 (energy unbounded), nutrition versions unique per product, "a total needs a grade" (water: grade A, no total; insufficient data: neither). Products also hold `nova_group` and `additives` (T10 codes). Nutrients are exact `NUMERIC`; `nutrition_input()` / `score_row()` map rows to the engine and back (all golden cases round-trip). `scores.breakdown` is the golden `expected` block. Repositories flush, never commit; duplicate EAN → `DuplicateEanError` (savepoint, session stays usable); `NutritionFactsRepository.add_version` numbers versions, `ConcurrentVersionError` on a race; `ScoreRepository.latest(product_id, engine_version=None)`. Scan events: EAN, optional product, outcome; no user/device id; kept (unlinked) when a product is deleted. `app/models.py` registers every model for Alembic and the drift test.

### T13 · Open Food Facts client and normaliser
- [x] httpx client with required custom User-Agent, timeouts, retries with backoff, rate limiting
- [x] Normaliser: OFF JSON → our schema; per-serving → per-100 g refusal or conversion, kJ/kcal, sodium → salt, OFF categories → our scoring categories, quality flag
- [x] EAN utils: checksum validation, UPC-A → EAN-13
- Tests: **U** normaliser on 15+ recorded OFF fixtures (complete, partial, beverage, cheese, oil, missing category, garbage values); EAN utils; **U** client retry/timeout via respx.
- Done: 1023 backend tests, coverage 100 %. `products/ean.py`: GTIN check digits (EAN-8, UPC-A, EAN-13, GTIN-14), `normalize_ean` (UPC-A stored as EAN-13). `ingestion/off_client.py`: API v2 with a `fields` list, User-Agent `Qout/0.1 (https://github.com/dhafer123/Qout)` (placeholder rejected at startup), 3 s connect / 10 s read, retries (3) on timeouts, connection errors, 429, 5xx with exponential backoff + jitter, `Retry-After` honoured (capped 30 s), even-spacing rate limiter (100/min); not-found as 404 or `status: 0`. `ingestion/off_normaliser.py` → `ProductCreate` + `NutritionFactsCreate` + OFF 2023 grade + issues. Fixtures: 18 recorded (`scripts/record_off_fixtures.py`) + 6 hand-edited. Every complete recorded product gets OFF's own grade from our engine. httpx is now a runtime dependency; new dev dependency respx. New env vars: OFF_TIMEOUT_SECONDS, OFF_MAX_RETRIES, OFF_RATE_LIMIT_PER_MINUTE.

### T13b · Undeclared fibre (decision 8)
- [x] Spec: decision 8 in `docs/specs/README.md` (undeclared fibre = 0 points, reported as `assumed_zero`); golden schema + 3 new cases, `general--missing-fibre` now graded
- [x] Python and Dart engines: fibre out of the required fields, `assumed_zero` in the breakdown, engine version `nutriscore-2023.2`
- Tests: **U** every category with fibre undeclared, fibre missing with other fields, hypothesis (undeclared = fibre 0; declaring fibre never worsens), Dart mirror tests, parity regenerated.
- Done: 1046 backend tests (coverage 100 %), 451 app tests, parity identical on 4216 cases. The OFF normaliser follows automatically: the recorded cheese (D), cheese spread (D) and beef patty (B) are now complete and get exactly OFF's grade (12 of 12 complete fixtures agree). The planned separate ingestion-test commit was folded into the Python commit so every commit keeps the suite green.

### T14 · Product lookup endpoint
- [x] Service: DB → OFF → save + score → return; 404 for unknown; invalid EAN → 422
- [x] Redis cache for hot products (TTL, invalidated on update)
- [x] `GET /v1/products/{ean}` returns product, nutrients, score + breakdown, source, updated_at
- Tests: **I** DB hit, OFF hit (respx) saved and scored, OFF miss → 404, OFF down → graceful 503/fallback, cache hit avoids DB, invalid EAN.
- Done: 1081 backend tests, coverage 100 %. `products/lookup.py` (`ProductLookup`): cache → DB → OFF; OFF imports are normalised, stored (product, nutrition v1, score with OFF's grade) and committed. A stored product without a score for its latest nutrition and the current engine version is scored on read (OFF grade carried over); concurrent first lookups and concurrent rescoring are safe (unique constraints, the loser reads the winner's row). Unknown category → stored, `score: null`; no nutrition → insufficient data. Hidden products → 404. OFF down/rejecting → 503 + `Retry-After: 30` only when the product is not stored. `products/cache.py`: whole response JSON in Redis, key `qout:product:v{format}:{engine_version}:{ean}`, TTL 24 h; unknown barcodes remembered 10 min; `invalidate(ean)` for later writers (T15, T25, T31); any Redis error or 0.5 s timeout is logged and treated as a miss. Response: `ProductDetail` (additives with name and EFSA risk, nutrition with basis and version, score with breakdown, `updated_at` = latest of product/nutrition/score). New env vars: PRODUCT_CACHE_TTL_SECONDS, PRODUCT_NOT_FOUND_TTL_SECONDS. Also: `ProductFactory` EANs now have valid check digits; coverage measures greenlets (SQLAlchemy async), which had hidden covered lines. Scan events are not recorded yet: a DB write per lookup would defeat the cache; to be done through the worker queue (see follow-up below).
- Follow-up: record `scan_events` asynchronously (arq job from the lookup) — fits T15's worker setup or a later analytics task.

### T15 · Worker and bulk import
- [x] arq worker setup; job: import OFF products for Tunisia (and configurable country list) from OFF export/delta files
- [x] Idempotent upsert, progress logging, resumable
- Tests: **U** parsing a small fixture export; **I** import job twice → no duplicates, updated rows rescored.
- Done: 1213 backend tests, coverage 100 %. `app/worker/`: arq `WorkerSettings` (`uv run arq app.worker.main.WorkerSettings`), jobs `import_off_export` and `import_off_deltas` (daily cron, `IMPORT_DELTA_CRON_HOUR` UTC), CLI `python -m app.worker {enqueue,run} {export,deltas} [--force]`; one import at a time (Postgres advisory lock, busy → arq retry in 10 min). Sources: the JSONL full export (~14 GB, identified by its ETag, downloaded resumably with Range/If-Range, deleted after import) and every delta file in `delta/index.txt` not imported yet; the CSV export is not used (no Nutri-Score 2023 classification). Lines are filtered by `countries_tags` before JSON parsing. `products/upsert.py` (`ProductUpserter`, now also used by the lookup): insert; update only OFF products (contributions/manual untouched, moderation status kept); new nutrition version only when values or category change, then rescored; OFF grade updated in place; records older than the stored `source_modified_at` (new column, OFF `last_modified_t`) ignored, so file order doesn't matter. `import_runs` table: checkpoint line committed with each batch (`IMPORT_BATCH_SIZE`), cumulative counters, status/error; an interrupted or failed run resumes from its checkpoint; one bad product is rolled back alone and counted. Changed products are dropped from the lookup cache after commit. New env vars: IMPORT_COUNTRIES, IMPORT_BATCH_SIZE, IMPORT_DOWNLOAD_DIR, OFF_EXPORT_URL, OFF_DELTA_URL, IMPORT_DELTA_CRON_ENABLED, IMPORT_DELTA_CRON_HOUR.
- Changed on the way: **arq pins `redis<6`** in every release (0.28.0 latest); it works with redis-py 8 (smoke-tested, covered by a real worker test), so `[tool.uv] override-dependencies = ["redis>=8.1.0"]` keeps redis-py 8, and pytest filters arq's two redis-py deprecation warnings. Drop the override when arq relaxes the pin. **OFF bulk files use product schema 1004**: `nutriments` is empty and values are in `nutrition.aggregated_set`; the API v2 still serves the old shape. The normaliser now reads it like the API's own down-conversion (as sold, per 100 g/mL, ingredient-based estimates only for fruits/vegetables/legumes). Two recorded schema-1004 fixtures in `tests/fixtures/off_export/`.
- Acceptance (2026-11-12, real OFF delta files, dev DB): `enqueue deltas` + `arq … --burst`: 13 delta files, 92 044 lines, 100 Tunisian records (90 products) in ~2 min, 0 failed, 1 rejected line (bad check digit); downloads deleted; a second run imported nothing. Where both OFF and we give a grade, they agree on 38 of 38 products; 39 are insufficient data (values not declared on OFF).
- Follow-ups: record `scan_events` through the worker (from T14, still open). T16: OFF's 2023 block has an `estimated` flag (grade computed from ingredient-based estimates); 5 products OFF grades from estimates are "insufficient data" here, so the validation report should compare only OFF grades not estimated (store the flag with `off_grade`).

### T16 · Rescoring and validation report
- [x] Job: rescore all products when `ENGINE_VERSION` changes
- [x] Script `scripts/validate_engine.py`: compares our grade with OFF grade, outputs agreement %, confusion matrix, top mismatches (markdown report in `docs/reports/`)
- Tests: **I** rescoring updates only outdated scores; **U** report metrics on a fixture.
- Done: 1236 backend tests, coverage 100 %. `products/rescoring.py`: `ensure_current_score` (one product; the lookup's on-read scoring now uses it) and `Rescorer` (batches of outdated products: latest nutrition without a score for the current engine; keyset by id; one failure is rolled back alone; up-to-date scores never touched; OFF's grade carried over to a new score of the same nutrition). Worker job `rescore_products`, queued at every worker start under job id `rescore:<ENGINE_VERSION>`, so it runs once per engine version; `python -m app.worker run rescore`. New column `scores.off_grade_estimated` (OFF's `nutriscore["2023"]["estimated"]`: some inputs, usually the fruit/vegetable share, estimated from the ingredients), set by the normaliser and upsert (from T15's follow-up). `products/validation.py` (metrics and Markdown, pure) + `scripts/validate_engine.py` (run as `uv run python -m scripts.validate_engine`): exact and within-one agreement, confusion matrix with an insufficient-data row, agreement per category and per OFF estimation, top mismatches, products OFF grades but we can't. Reports with fewer than 300 products graded by both say they are a small sample.
- Report: `docs/reports/engine-validation-nutriscore-2023.2-2026-11-12.md`, from the dev database (90 products from the T15 delta import), a small sample by choice: 38 of 38 products graded by both agree; 5 graded by OFF are insufficient data here.
- Note: arq job keys are global to the Redis database, which tests share with dev; the worker tests delete the rescoring job's keys before and after, otherwise a test run would stop a real worker from queuing it for a day.
- Follow-ups: regenerate the report after the full Tunisia export import (`python -m app.worker run export`, then the script). Decide how to handle an undeclared fruit/vegetable/legume share: 2 products OFF grades without estimates lack only `fvl_percent` here (OFF seems to count it as 0, like decision 8 does for fibre); a spec decision, not changed. `scripts/record_off_fixtures.py` documents `uv run python scripts/...`, which can't import `app`; use `uv run python -m scripts.record_off_fixtures`.

---

## Phase 3 — App core

### T17 · Generated API client
- [x] Export OpenAPI from backend; generate Dart client (openapi-generator or a small hand-written dio layer — propose one); script `scripts/gen_client.sh`
- [x] CI check: committed client matches the current spec
- Tests: **U** client deserialises a recorded product response.
- Done: backend 1242 tests (coverage 100 %), app 494 tests. Chosen: a small generator in the repo (`app/tool/api_generator.dart`), not openapi-generator (Java/Docker, extra packages, and its Dart generators turn OpenAPI 3.1 `anyOf [X, null]` into wrapper types) nor a hand-written layer (not checkable against the spec). Contract: `api/openapi.json`, exported by `python -m app.openapi` with fixed dummy settings; operation ids are the route names (`getProduct`); a backend test fails when the committed spec no longer matches the code. Client: `app/lib/core/api/qout_api.dart` (committed, analyzed like hand-written code): immutable models with fromJson/toJson, value equality and read-only collections; enums with an `unrecognized` member for values a newer backend adds; `QoutApi` on dio with typed errors `ApiNotFound` (404), `ApiInvalidRequest` (422), `ApiUnavailable` (503, `retryAfter`), `ApiConnectionError`, `ApiBadResponse` (other statuses, or a body that doesn't match). Only `/v1/` GET operations; anything the generator doesn't support (request bodies, other methods, `oneOf`, non-string enums, ...) stops it with an error naming the place. `scripts/gen_client.sh [spec|client|all]`; app CI regenerates the client and fails on a diff (and runs on `api/**` changes). Recorded responses from our own API in `app/test/fixtures/api/` (graded general food and beverage, water, insufficient data, unknown category, invalid barcode). New app dependency: dio 5.11.
- Follow-ups: extend the generator for request bodies (POST) when the contribution and auth endpoints arrive (T23+). Providing `QoutApi`/`Dio` to the app (base URL from `AppEnv`, timeouts) comes with the repository in T18.

### T18 · Local database and repository
- [x] drift DB: cached products, scan history, contribution outbox
- [x] `ProductRepository.get(ean)`: cache → API → cache write; stale-while-revalidate
- Tests: **U** repository with fake API and in-memory drift: cache hit, miss, offline, API 404.
- Done: 517 app tests. `core/database/database.dart` (drift, schema version 1): `cached_products` (EAN → `ProductDetail` JSON + `fetched_at`), `scan_history`, `contribution_outbox` (kind, JSON payload, attempts, last error), with DAOs. Times stored as ISO-8601 text (`build.yaml`), scan times in UTC. `features/product/`: `ProductRepository.get(ean)` is a stream: cached and younger than 6 h → served, no request; older → served at once (`refreshing`) then refreshed (`fresh`), or kept as `refreshFailed` when offline/server down, or removed on 404; not cached → fetched and cached under the scanned code and the API's EAN (UPC-A). Results: sealed `ProductResult` (found / notFound / invalidBarcode / unavailable with offline flag and Retry-After). Unreadable cached JSON (after an app update) is dropped and refetched. The generated `ProductDetail` is the app's product type (no separate domain model). Providers: `dioProvider` (base URL from `AppEnv`, 5 s connect, 15 s receive: a first lookup may wait for OFF), `qoutApiProvider`, `appDatabaseProvider` (overridden in tests), `productRepositoryProvider`. Debug APK verified: SQLite bundled for arm64, armv7 and x86_64. New dependencies: drift, drift_flutter, drift_dev (dev).
- Changed on the way: `build_runner` must run with `--force-jit` (drift_dev depends on sqlite3, whose native build hooks the default AOT builder compilation rejects; a build_runner that falls back on its own needs a newer analyzer than freezed allows). Updated in CLAUDE.md, the app README and app CI.
- Follow-ups: dump the drift schema (`drift_dev schema dump`) before the first schema change; with drift 2.34.4 the drift_dev 2.34.0 CLI doesn't compile (codegen works), so this waits for the analyzer constraint to allow a newer drift_dev. The product cache has no size limit yet (~3 KB per product). Nothing visible yet: the screens come in T19–T21.

### T19 · Scan feature
- [x] mobile_scanner limited to EAN-13/EAN-8/UPC-A/UPC-E; accept a code after N identical consecutive reads; checksum validation; haptic feedback; torch toggle; permission handling
- Tests: **U** debounce/validation logic (extract it from the widget); **W** permission-denied state.
- Done: 571 app tests. `features/scan/domain/`: `barcode.dart` (GTIN check digit as in the backend, GS1 UPC-E → UPC-A expansion, `normalizeScannedBarcode`: EAN-13/EAN-8 as read, UPC-A and UPC-E as EAN-13, null for a wrong length or check digit) and `scan_acceptor.dart` (`ScanAcceptor`, N = 3 by default: per camera frame; frames without a valid code neither count nor break the streak; another valid code restarts it; silent after acceptance until `reset()`). Both are free of the camera plugin. `ScanScreen` (`/scan`): reads every ~100 ms, medium haptic and camera stop on acceptance, torch button only when the camera has a torch; permission denied → explanation with "Try again" (no deep link to system settings, which would need another package); no camera / other errors have their own states; the camera stops when the app goes inactive and restarts on resume, except without permission (the permission dialog itself makes the app inactive, so restarting there would ask in a loop). An accepted code replaces the scanner with `/product/:ean`, a placeholder showing the barcode, so back returns home. Scans are not written to `scan_history` yet (T21). Widget tests drive the real `MobileScanner` widget on a fake `MobileScannerPlatform` (`test/helpers/fake_scanner_platform.dart`). The CAMERA permission comes from the plugin's manifest (camera feature not required). New dependency: mobile_scanner 7.5.
- Follow-ups: T20 replaces the `/product/:ean` placeholder with the result screen. T21 records accepted scans in `scan_history`. Not yet tried on a real phone.

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
- 2026-11-12 (T10): taxonomy licence (AGPL repo vs ODbL data) to confirm before the public release (T37); attribution is in `docs/specs/README.md`. App wording (T20): `unknown` risk means "not evaluated", not "safe"; most additives (624/726) are unknown. Follow-up for T13: the taxonomy marks non-nutritive sweeteners (`non_nutritive_sweetener:en: yes`); could feed the beverage sweetener input after cross-checking with Nutri-Score Q&A Appendix 3 (sugar alcohols excluded).
- 2026-11-12 (T11): `NutritionInput` (Dart) is a plain immutable class, not freezed: freezed can't validate in the constructor of a release build (`@Assert` is debug-only). Result types use freezed. No property-based tests in Dart (no new package); the parity input set covers the same ground against the Python engine, which has the hypothesis tests. Golden-format conversion now lives in `app.modules.scoring.spec_json` (Python) and `lib/scoring/spec_json.dart`.
- 2026-11-12 (T12): `scores.created_at` uses `clock_timestamp()` instead of the mixin's `now()` so the latest-score query orders correctly when several scores are written in one transaction (T16 rescoring). Decided with the plan: status unverified/verified/hidden, quality flag complete/incomplete/suspect, source open_food_facts/contribution/manual.
- 2026-11-12 (T13): category from OFF's Nutri-Score 2023 classification only (`category_available` + `is_*` flags; flags are 1 or true); fruit/vegetable % and the beverage sweetener count from OFF's 2023 score components (they apply the olive-oil rule for fats), so the planned taxonomy-based sweetener fallback was dropped: a beverage without that component lacks the input (insufficient data). Basis = unit declared on the pack (`nutrition_data_per`; Q&A p. 12), category default only if undeclared. Quality heuristics (not scoring constants): kJ/kcal ratio 3.9–4.35 ± 20 kJ (EU 1169/2011 Annex XIV factors 4.0–4.25), salt vs sodium ± max(0.01 g, 5 %), sat fat ≤ fat, sugars ≤ carbohydrates. Local `.env` OFF_USER_AGENT placeholder replaced with the repo URL.
- RESOLVED (T13b, decision 8: undeclared fibre counts as 0 points). Was: fibre is often not declared (it is optional on EU labels): 3 of the recorded products that OFF grades (cheese D, beef B, energy drink E) are incomplete for us only because fibre is missing, so the engine returns insufficient data (decision 5). The Q&A does not cover undeclared fibre; OFF estimates it from ingredients. Options: keep strict; treat undeclared fibre as 0 points; or use OFF's estimate. Decide before the lookup endpoint stores scores.
