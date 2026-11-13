"""Password rules and Argon2id hashing.

Rules follow NIST SP 800-63B: a minimum length, a generous maximum, no composition rules.
Hashing is CPU-heavy by design (~50 ms), so async callers run it in a thread.
"""

import asyncio
import re

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError

MIN_PASSWORD_LENGTH = 10
MAX_PASSWORD_LENGTH = 128
MAX_EMAIL_LENGTH = 254  # RFC 5321 path limit

_EMAIL = re.compile(r"[^@\s]+@[^@\s]+\.[^@\s]+")
_hasher = PasswordHasher()  # argon2-cffi defaults: Argon2id, RFC 9106 low-memory profile

# Verified against when the email is unknown, so a login takes the same time either way
# and response times don't reveal which emails have accounts.
_DUMMY_HASH = _hasher.hash("not-a-real-password-only-for-timing")


def normalize_email(email: str) -> str:
    """Trimmed and lower-cased; raises ValueError if it can't be an email address."""
    cleaned = email.strip().lower()
    if len(cleaned) > MAX_EMAIL_LENGTH or not _EMAIL.fullmatch(cleaned):
        raise ValueError("not a valid email address")
    return cleaned


def check_password(password: str) -> str:
    """The password if acceptable; raises ValueError otherwise."""
    if len(password) < MIN_PASSWORD_LENGTH:
        msg = f"password must have at least {MIN_PASSWORD_LENGTH} characters"
        raise ValueError(msg)
    if len(password) > MAX_PASSWORD_LENGTH:
        msg = f"password must have at most {MAX_PASSWORD_LENGTH} characters"
        raise ValueError(msg)
    return password


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password_hash: str | None, password: str) -> bool:
    """True if `password` matches; with no hash (unknown account) the dummy hash is
    checked anyway and False returned."""
    try:
        matches = _hasher.verify(password_hash or _DUMMY_HASH, password)
    except (VerificationError, InvalidHashError):
        return False
    return matches and password_hash is not None


def needs_rehash(password_hash: str) -> bool:
    """True when the hash uses older parameters than the current ones."""
    return _hasher.check_needs_rehash(password_hash)


async def hash_password_async(password: str) -> str:
    return await asyncio.to_thread(hash_password, password)


async def verify_password_async(password_hash: str | None, password: str) -> bool:
    return await asyncio.to_thread(verify_password, password_hash, password)
