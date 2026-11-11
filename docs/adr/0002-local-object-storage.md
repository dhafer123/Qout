# ADR 0002 — Local object storage: RustFS instead of MinIO

- **Status:** Accepted
- **Date:** 2026-11-11

## Context

The original plan used MinIO as the local S3-compatible store for contribution photos.
When setting up local infrastructure (T02) we found that the MinIO GitHub repository is
archived and its container images are no longer published (Docker Hub returns
"not found", quay.io lists no tags). Unpinned or third-party rebuilds would not be
reproducible.

Local development also runs on Docker Engine inside WSL 2, without Docker Desktop.

## Decision

Use **RustFS** (`rustfs/rustfs`, Apache-2.0, pinned tag) as the local S3-compatible
store. It is designed as a MinIO replacement: same ports (9000 API, 9001 console), root
credentials via environment variables, a `/health` endpoint for healthchecks.

The bucket is created by a one-shot `s3-init` service using the official AWS CLI image,
so the init step does not depend on a vendor-specific client.

The backend talks to storage only through the generic S3 API (endpoint URL, access key,
secret key, bucket, region from settings), with path-style addressing. Nothing in the
application code may depend on RustFS specifics.

## Alternatives considered

- **SeaweedFS:** mature and Apache-2.0, but S3 credentials need a separate JSON config
  and there is no bucket console; more setup for no gain here.
- **Garage:** lightweight, but AGPL-3.0 and needs a cluster-layout step before first use.
- **Older pinned MinIO images from mirrors:** unmaintained, no security fixes.

## Consequences

- Production can use any S3 provider; only the endpoint and credentials change.
- RustFS is younger than MinIO. If it causes problems, switching to another S3-compatible
  server only touches `docker-compose.yml` and `.env.example`.
- The integration tests for uploads (T24) run against RustFS locally and in CI.
