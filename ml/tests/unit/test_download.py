import hashlib
from pathlib import Path

import httpx
import pytest
import respx

from qout_ml.data.download import DownloadError, RemoteFile, download, download_all, matches

URL = "https://files.example/data/a.bin"
BODY = b"pinned bytes" * 100


def _remote(**overrides: object) -> RemoteFile:
    fields: dict[str, object] = {
        "url": URL,
        "name": "sub/a.bin",
        "sha256": hashlib.sha256(BODY).hexdigest(),
        "size": len(BODY),
    }
    fields.update(overrides)
    return RemoteFile(**fields)  # type: ignore[arg-type]


@pytest.fixture
def client() -> httpx.Client:
    return httpx.Client()


class _Sleeps:
    def __init__(self) -> None:
        self.calls: list[float] = []

    def __call__(self, seconds: float) -> None:
        self.calls.append(seconds)


def test_remote_file_needs_a_checksum() -> None:
    with pytest.raises(ValueError, match="checksum"):
        RemoteFile(url=URL, name="a.bin")


@pytest.mark.parametrize("name", ["/abs/a.bin", "../a.bin", "sub/../../a.bin"])
def test_remote_file_stays_inside_the_destination(name: str) -> None:
    with pytest.raises(ValueError, match="relative path"):
        _remote(name=name)


@respx.mock
def test_downloads_and_verifies(client: httpx.Client, tmp_path: Path) -> None:
    respx.get(URL).respond(200, content=BODY)

    path = download(client, _remote(), tmp_path)

    assert path == tmp_path / "sub" / "a.bin"
    assert path.read_bytes() == BODY
    assert not (tmp_path / "sub" / "a.bin.part").exists()


@respx.mock
def test_md5_pin_is_enough(client: httpx.Client, tmp_path: Path) -> None:
    respx.get(URL).respond(200, content=BODY)
    remote = _remote(
        sha256=None, size=None, md5=hashlib.md5(BODY, usedforsecurity=False).hexdigest()
    )

    assert download(client, remote, tmp_path).read_bytes() == BODY


@respx.mock(assert_all_called=False)
def test_existing_matching_file_is_not_downloaded_again(
    client: httpx.Client, tmp_path: Path
) -> None:
    route = respx.get(URL).respond(200, content=BODY)
    target = tmp_path / "sub" / "a.bin"
    target.parent.mkdir()
    target.write_bytes(BODY)

    download(client, _remote(), tmp_path)

    assert not route.called


@respx.mock
def test_existing_wrong_file_is_replaced(client: httpx.Client, tmp_path: Path) -> None:
    respx.get(URL).respond(200, content=BODY)
    target = tmp_path / "sub" / "a.bin"
    target.parent.mkdir()
    target.write_bytes(b"old")

    download(client, _remote(), tmp_path)

    assert target.read_bytes() == BODY


@respx.mock
def test_checksum_mismatch_rejects_the_file_without_retrying(
    client: httpx.Client, tmp_path: Path
) -> None:
    route = respx.get(URL).respond(200, content=b"x" * len(BODY))
    sleeps = _Sleeps()

    with pytest.raises(DownloadError, match="checksum"):
        download(client, _remote(), tmp_path, sleep=sleeps)

    assert route.call_count == 1
    assert sleeps.calls == []
    assert list(tmp_path.rglob("*.bin*")) == []


@respx.mock
def test_size_mismatch_rejects_the_file(client: httpx.Client, tmp_path: Path) -> None:
    respx.get(URL).respond(200, content=BODY)

    with pytest.raises(DownloadError):
        download(client, _remote(size=len(BODY) + 1), tmp_path)


@respx.mock
def test_broken_download_is_retried(client: httpx.Client, tmp_path: Path) -> None:
    respx.get(URL).mock(
        side_effect=[
            httpx.ConnectError("down"),
            httpx.Response(503),
            httpx.Response(200, content=BODY),
        ]
    )
    sleeps = _Sleeps()

    path = download(client, _remote(), tmp_path, sleep=sleeps)

    assert path.read_bytes() == BODY
    assert sleeps.calls == [1.0, 2.0]


@respx.mock
def test_gives_up_after_the_last_attempt(client: httpx.Client, tmp_path: Path) -> None:
    route = respx.get(URL).respond(503)

    with pytest.raises(DownloadError, match="download failed"):
        download(client, _remote(), tmp_path, attempts=3, sleep=_Sleeps())

    assert route.call_count == 3
    assert list(tmp_path.rglob("*.part")) == []


@respx.mock
def test_not_found_is_not_retried(client: httpx.Client, tmp_path: Path) -> None:
    route = respx.get(URL).respond(404)

    with pytest.raises(DownloadError):
        download(client, _remote(), tmp_path, sleep=_Sleeps())

    assert route.call_count == 1


@respx.mock
def test_download_all_in_order(client: httpx.Client, tmp_path: Path) -> None:
    other = b"second"
    respx.get(URL).respond(200, content=BODY)
    respx.get("https://files.example/b").respond(200, content=other)
    second = RemoteFile(
        url="https://files.example/b", name="b.bin", sha256=hashlib.sha256(other).hexdigest()
    )

    paths = download_all(client, [_remote(), second], tmp_path)

    assert [p.name for p in paths] == ["a.bin", "b.bin"]


def test_matches_false_for_missing_file(tmp_path: Path) -> None:
    assert not matches(tmp_path / "nope", _remote())
