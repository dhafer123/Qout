"""The OpenAPI document: the contract the app's API client is generated from.

    uv run python -m app.openapi > ../api/openapi.json   # export (scripts/gen_client.sh)
    uv run python -m app.openapi --check ../api/openapi.json

The document only depends on the code: settings are fixed dummies, never the environment's
connection strings. `--check` fails if the committed file is out of date (backend CI).
"""

import argparse
import json
import sys
from collections.abc import Sequence
from pathlib import Path
from typing import Any

from app.core.config import Settings
from app.factory import create_app

_SETTINGS = {
    "app_env": "test",
    "database_url": "postgresql+asyncpg://openapi@localhost/openapi",
    "redis_url": "redis://localhost:6379/0",
    "jwt_secret": "openapi-export-only-not-a-real-secret-0000",
}


def openapi_document() -> dict[str, Any]:
    settings = Settings(_env_file=None, **_SETTINGS)  # type: ignore[arg-type]
    return create_app(settings).openapi()


def render() -> str:
    return json.dumps(openapi_document(), indent=2, ensure_ascii=False) + "\n"


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.openapi", description=__doc__)
    parser.add_argument("--check", type=Path, metavar="FILE", help="compare with FILE")
    args = parser.parse_args(argv)
    document = render()
    if args.check is None:
        sys.stdout.write(document)
        return 0
    committed = args.check.read_text(encoding="utf-8") if args.check.exists() else ""
    if committed != document:
        print(
            f"{args.check} is out of date with the API: run scripts/gen_client.sh and commit "
            "the spec and the regenerated app client.",
            file=sys.stderr,
        )
        return 1
    print(f"{args.check} is up to date.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
