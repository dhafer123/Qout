#!/bin/sh
# Creates the test database next to the main one. Runs once, on first start with an
# empty data volume (docker-entrypoint-initdb.d). Idempotent if run by hand.
set -eu

: "${POSTGRES_TEST_DB:=qout_test}"

psql -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --set test_db="$POSTGRES_TEST_DB" \
  --set owner="$POSTGRES_USER" <<'EOSQL'
SELECT format('CREATE DATABASE %I OWNER %I', :'test_db', :'owner')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'test_db')
\gexec
EOSQL
