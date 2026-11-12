#!/usr/bin/env bash
# Regenerate the API contract and the app's API client from it.
#
#   scripts/gen_client.sh          # both steps (needs uv and dart on PATH)
#   scripts/gen_client.sh spec     # backend code     -> api/openapi.json      (uv)
#   scripts/gen_client.sh client   # api/openapi.json -> app/lib/core/api/qout_api.dart (dart)
#
# With the backend in WSL and Flutter on Windows, run `spec` in WSL and `client` in
# Git Bash. Commit api/openapi.json and the generated client together: backend CI fails
# if the spec is stale, app CI fails if the client doesn't match the spec.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
spec_file="$root/api/openapi.json"
client_file="lib/core/api/qout_api.dart"

spec() {
  # Write to a temporary file first so a failed export never truncates the spec.
  (cd "$root/backend" && uv run python -m app.openapi > "$spec_file.tmp")
  mv "$spec_file.tmp" "$spec_file"
  echo "wrote api/openapi.json"
}

client() {
  cd "$root/app"
  dart run tool/gen_api.dart ../api/openapi.json "$client_file"
  dart format "$client_file"
}

case "${1:-all}" in
  spec) spec ;;
  client) client ;;
  all) spec && client ;;
  *)
    echo "usage: scripts/gen_client.sh [spec|client|all]" >&2
    exit 64
    ;;
esac
