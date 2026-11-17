"""Command line for the admin panel: make the first moderator (the others are promoted in
the panel, Users > Edit > role).

uv run python -m app.admin make-admin someone@example.com
"""

import argparse
import asyncio
import sys
from collections.abc import Sequence

from sqlalchemy import select

from app.core.config import Settings, get_settings
from app.core.db import create_engine, create_session_factory
from app.modules.auth.models import User, UserRole
from app.modules.auth.passwords import normalize_email


def parser() -> argparse.ArgumentParser:
    cli = argparse.ArgumentParser(prog="python -m app.admin", description=__doc__.split("\n")[0])
    commands = cli.add_subparsers(dest="command", required=True)
    make = commands.add_parser("make-admin", help="give an existing account the moderator role")
    make.add_argument("email", help="the account's email (it signs up in the app first)")
    return cli


def main(argv: Sequence[str] | None = None) -> int:
    return asyncio.run(amain(argv))


async def amain(argv: Sequence[str] | None = None, *, settings: Settings | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        email = normalize_email(args.email)
    except ValueError:
        print(f"not an email address: {args.email}", file=sys.stderr)
        return 2
    engine = create_engine(settings or get_settings())
    try:
        async with create_session_factory(engine)() as session:
            user = await session.scalar(select(User).where(User.email == email))
            if user is None:
                print(
                    f"no account with the email {email}; sign up in the app first", file=sys.stderr
                )
                return 1
            user.role = UserRole.ADMIN
            user.is_active = True
            await session.commit()
    finally:
        await engine.dispose()
    print(f"{email} is now a moderator: sign in at /admin")
    return 0
