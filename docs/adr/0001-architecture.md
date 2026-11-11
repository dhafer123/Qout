# ADR 0001 — Overall architecture

- **Status:** Accepted
- **Date:** 2026-11-11

## Context

Qout is a mobile app that scores food products (barcode scan or label photo) with an
explainable nutrition score. It is built and run by a single developer, so operational
simplicity matters more than independent scaling of components. Requirements that shape
the architecture:

- Fast barcode lookups, also when the phone is offline for previously seen products.
- A scoring engine whose results are reproducible and auditable against an official
  specification.
- A contribution flow for unknown products (photos, OCR, parsing, moderation), which
  needs background jobs and object storage.
- Product data seeded from an existing open database rather than collected from scratch.

## Decision

### Backend: modular monolith (Python, FastAPI)

One deployable FastAPI service, split into modules with clear boundaries:
`products`, `scoring`, `ingestion`, `contributions`, `auth`, plus shared `core/` and a
separate `worker/` process (arq on Redis) for slow or batch work. Modules talk through
service interfaces, not each other's tables. Services do not import FastAPI; routers
stay thin.

Storage: PostgreSQL (source of truth), Redis (cache + job queue), S3-compatible object
storage for photos (MinIO locally).

### Mobile app: Flutter

Flutter with a feature-first clean architecture (`data/`, `domain/`, `presentation/`),
Riverpod for state, go_router, dio, and drift as a local cache / outbox. Android first,
iOS later from the same codebase. Barcode scanning and OCR run on the device
(mobile_scanner, ML Kit); only extracted text is sent to the backend.

### Data source: Open Food Facts

Open Food Facts (OFF) is the initial product data source, via its API and bulk exports.
OFF is called **only from the backend**, never from the app, so that we control
caching, rate limits, the required User-Agent, normalisation and scoring in one place.
Lookup chain: app local cache → `GET /v1/products/{ean}` → our DB → OFF → 404 (then the
contribution flow).

### Scoring engine in two languages

The engine is implemented in Python (authoritative, server side) and Dart (provisional
scores offline and in the contribution review screen). Both are pure functions and must
produce identical results for every golden case in `scoring-spec/golden/`; CI checks
this. All thresholds come from the official specification in `docs/specs/`.

## Alternatives considered

- **Microservices:** independent scaling and deploys, but too much operational overhead
  (service discovery, distributed tracing, many pipelines) for one developer and
  modest traffic. Module boundaries keep a later split possible.
- **Native Android (Kotlin) / React Native:** Kotlin would delay iOS; React Native is
  viable, but Flutter gives consistent rendering and good camera/ML Kit plugins.
- **Calling OFF directly from the app:** fewer moving parts, but no shared cache, no
  control over normalisation or scoring versions, and every client would hit OFF's
  rate limits.
- **Scoring only on the server:** a single implementation, but no score offline or for
  unsubmitted contributions. Golden cases keep the cost of two engines manageable.

## Consequences

- One service plus one worker to deploy, monitor and back up.
- Module boundaries must be kept by discipline (code review, import rules) because the
  runtime doesn't enforce them.
- Two scoring implementations must stay in parity; the golden-case parity job is
  mandatory in CI.
- Dependency on OFF data quality and availability: the backend caches and stores
  products, flags data quality, and falls back gracefully when OFF is down.
