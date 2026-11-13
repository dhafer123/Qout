"""Auth building blocks: password rules and hashing, access and refresh tokens, settings."""

import uuid
from datetime import UTC, datetime, timedelta

import jwt
import pytest
from pydantic import ValidationError

from app.core.config import DEV_JWT_SECRET, Settings
from app.modules.auth.models import UserRole
from app.modules.auth.passwords import (
    check_password,
    hash_password,
    needs_rehash,
    normalize_email,
    verify_password,
)
from app.modules.auth.tokens import (
    AUDIENCE,
    ISSUER,
    InvalidAccessTokenError,
    create_access_token,
    decode_access_token,
    hash_refresh_token,
    new_refresh_token,
)

SECRET = "unit-test-secret-at-least-32-characters-long"
NOW = datetime(2026, 11, 13, 10, 0, tzinfo=UTC)
USER = uuid.UUID("11111111-2222-3333-4444-555555555555")


# ---------------------------------------------------------------- emails and passwords


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("dhafer@example.tn", "dhafer@example.tn"),
        ("  Someone.Else@Example.COM \n", "someone.else@example.com"),
        ("a+tag@sub.domain.org", "a+tag@sub.domain.org"),
    ],
)
def test_emails_are_trimmed_and_lowercased(raw: str, expected: str) -> None:
    assert normalize_email(raw) == expected


@pytest.mark.parametrize(
    "raw",
    ["", "plain", "no-at.example.com", "a@b", "a@ b.com", "two@@example.com", "@example.com"],
)
def test_invalid_emails(raw: str) -> None:
    with pytest.raises(ValueError, match="email"):
        normalize_email(raw)


def test_email_length_limit() -> None:
    local = "a" * 64
    domain = "b" * (254 - 64 - 1 - 4) + ".com"
    assert normalize_email(f"{local}@{domain}")
    with pytest.raises(ValueError, match="email"):
        normalize_email(f"{local}a@{domain}")


def test_password_length_rules() -> None:
    assert check_password("x" * 10) == "x" * 10
    assert check_password("x" * 128)
    with pytest.raises(ValueError, match="at least 10"):
        check_password("x" * 9)
    with pytest.raises(ValueError, match="at most 128"):
        check_password("x" * 129)


def test_hash_and_verify() -> None:
    hashed = hash_password("correct horse battery")
    assert hashed.startswith("$argon2id$")
    assert "correct horse" not in hashed
    assert verify_password(hashed, "correct horse battery")
    assert not verify_password(hashed, "correct horse battery!")
    assert hash_password("correct horse battery") != hashed  # salted
    assert not needs_rehash(hashed)


def test_unknown_account_and_broken_hash_never_verify() -> None:
    assert not verify_password(None, "not-a-real-password-only-for-timing")
    assert not verify_password("not a hash", "anything at all")


def test_older_parameters_need_a_rehash() -> None:
    weak = "$argon2id$v=19$m=8,t=1,p=1$c29tZXNhbHQ$9sTbSlTio3Biev89thdrlKKiCaYsjjYVJxGAL3swxpQ"
    assert needs_rehash(weak)


# ---------------------------------------------------------------- access tokens


def token(**overrides: object) -> str:
    claims: dict[str, object] = {
        "sub": str(USER),
        "role": "contributor",
        "type": "access",
        "iss": ISSUER,
        "aud": AUDIENCE,
        "iat": NOW,
        "exp": NOW + timedelta(minutes=15),
    }
    claims.update(overrides)
    return jwt.encode({k: v for k, v in claims.items() if v is not None}, SECRET, "HS256")


def decode(value: str, now: datetime = NOW) -> object:
    return decode_access_token(value, secret=SECRET, now=now)


def test_access_token_round_trip() -> None:
    value = create_access_token(
        USER, UserRole.ADMIN, secret=SECRET, now=NOW, ttl=timedelta(minutes=15)
    )
    claims = decode_access_token(value, secret=SECRET, now=NOW + timedelta(minutes=14))
    assert (claims.user_id, claims.role) == (USER, UserRole.ADMIN)
    assert claims.expires_at == NOW + timedelta(minutes=15)


def test_access_token_expires() -> None:
    value = create_access_token(
        USER, UserRole.CONTRIBUTOR, secret=SECRET, now=NOW, ttl=timedelta(minutes=15)
    )
    with pytest.raises(InvalidAccessTokenError, match="expired"):
        decode(value, now=NOW + timedelta(minutes=15))


@pytest.mark.parametrize(
    "bad",
    [
        pytest.param(token(type="refresh"), id="not an access token"),
        pytest.param(token(aud="someone-else"), id="audience"),
        pytest.param(token(iss="someone-else"), id="issuer"),
        pytest.param(token(sub="not-a-uuid"), id="subject"),
        pytest.param(token(role="superuser"), id="role"),
        pytest.param(token(role=None), id="no role"),
        pytest.param(token(exp=None), id="no expiry"),
        pytest.param(
            jwt.encode({"sub": str(USER)}, "another-secret-of-at-least-32-chars!!", "HS256"),
            id="other key",
        ),
        pytest.param(token().rsplit(".", 1)[0] + ".forged", id="signature"),
        pytest.param("not.a.jwt", id="garbage"),
        pytest.param("", id="empty"),
    ],
)
def test_invalid_access_tokens(bad: str) -> None:
    with pytest.raises(InvalidAccessTokenError):
        decode(bad)


def test_unsigned_tokens_are_refused() -> None:
    unsigned = jwt.encode(
        {"sub": str(USER), "role": "admin", "type": "access", "iss": ISSUER, "aud": AUDIENCE,
         "iat": NOW, "exp": NOW + timedelta(minutes=5)},
        key=None,
        algorithm="none",
    )  # fmt: skip
    with pytest.raises(InvalidAccessTokenError):
        decode(unsigned)


# ---------------------------------------------------------------- refresh tokens


def test_refresh_tokens_are_random_and_hashed() -> None:
    tokens = {new_refresh_token() for _ in range(100)}
    assert len(tokens) == 100
    sample = next(iter(tokens))
    assert len(sample) >= 43  # 32 bytes, URL-safe base64
    digest = hash_refresh_token(sample)
    assert len(digest) == 64
    assert digest == hash_refresh_token(sample)
    assert sample not in digest


# ---------------------------------------------------------------- settings


def settings(**values: object) -> Settings:
    base: dict[str, object] = {
        "database_url": "postgresql+asyncpg://u:p@localhost/db",
        "redis_url": "redis://localhost:6379/0",
    }
    return Settings(_env_file=None, **(base | values))  # type: ignore[arg-type]


def test_dev_and_test_run_with_the_built_in_key(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("JWT_SECRET", raising=False)
    for env in ("dev", "test"):
        assert settings(app_env=env).jwt_secret.get_secret_value() == DEV_JWT_SECRET


@pytest.mark.parametrize("env", ["staging", "prod"])
@pytest.mark.parametrize("secret", [DEV_JWT_SECRET, "change-me-to-a-long-random-string"])
def test_deployed_environments_refuse_placeholder_keys(
    monkeypatch: pytest.MonkeyPatch, env: str, secret: str
) -> None:
    monkeypatch.delenv("JWT_SECRET", raising=False)
    with pytest.raises(ValidationError, match="real random secret"):
        settings(app_env=env, jwt_secret=secret)
    assert settings(app_env=env, jwt_secret="x" * 40).app_env == env


def test_short_keys_are_refused() -> None:
    with pytest.raises(ValidationError, match="at least 32"):
        settings(jwt_secret="x" * 31)


def test_the_key_is_not_printed() -> None:
    assert DEV_JWT_SECRET not in repr(settings())
