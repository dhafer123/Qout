"""Front photo URL from Open Food Facts records, and what the copy job accepts as a photo."""

from typing import Any

import pytest

from app.modules.ingestion.off_normaliser import front_image_url, normalize, product_folder
from app.modules.products.images import Image, image_key, sniff

EAN = "6191507220214"
BASE = "https://images.openfoodfacts.org/images/products"
JPEG = b"\xff\xd8\xff\xe0" + b"jpeg body"
PNG = b"\x89PNG\r\n\x1a\n" + b"png body"


def selected_front(**langs: object) -> dict[str, Any]:
    """The shape of OFF bulk records (schema 1004), as in a real delta file."""
    return {
        "images": {
            "selected": {
                "front": {
                    lang: {"rev": rev, "imgid": "1", "sizes": {"400": {"w": 190, "h": 400}}}
                    for lang, rev in langs.items()
                },
                "nutrition": {"fr": {"rev": "12", "imgid": "3"}},
            },
            "uploaded": {"1": {"uploader": "someone", "uploaded_t": 1558353265}},
        }
    }


@pytest.mark.parametrize(
    ("code", "folder"),
    [
        ("6191507220214", "619/150/722/0214"),
        ("90162602", "000/009/016/2602"),  # EAN-8, padded like OFF does
        ("12345678901234", "123/456/789/01234"),  # GTIN-14
    ],
)
def test_product_folder(code: str, folder: str) -> None:
    assert product_folder(code) == folder


def test_api_url_is_kept() -> None:
    url = f"{BASE}/619/150/722/0214/front_fr.90.400.jpg"

    assert front_image_url({"image_front_url": url, **selected_front(fr="1")}, EAN) == url


@pytest.mark.parametrize(
    "url",
    [
        "http://images.openfoodfacts.org/images/products/1/front_fr.1.400.jpg",
        "https://images.example.com/front.jpg",
        "https://openfoodfacts.org.evil.example/front.jpg",
        "https://localhost/front.jpg",
        "file:///etc/passwd",
        "not a url",
    ],
)
def test_api_urls_outside_off_https_are_refused(url: str) -> None:
    assert front_image_url({"image_front_url": url}, EAN) is None


def test_static_off_host_is_accepted() -> None:
    url = "https://static.openfoodfacts.org/images/products/619/150/722/0214/front_fr.9.400.jpg"

    assert front_image_url({"image_front_url": url}, EAN) == url


def test_built_from_bulk_record_in_the_product_language() -> None:
    record = {"lang": "fr", **selected_front(ar="4", fr="7")}

    assert front_image_url(record, EAN) == f"{BASE}/619/150/722/0214/front_fr.7.400.jpg"


def test_other_language_when_the_product_language_has_no_front() -> None:
    record = {"lang": "en", **selected_front(fr="7", ar="4")}

    assert front_image_url(record, EAN) == f"{BASE}/619/150/722/0214/front_ar.4.400.jpg"


def test_integer_revision() -> None:
    record = {"lang": "fr", **selected_front(fr=12)}

    assert front_image_url(record, EAN) == f"{BASE}/619/150/722/0214/front_fr.12.400.jpg"


@pytest.mark.parametrize(
    "record",
    [
        pytest.param({}, id="no-images"),
        pytest.param({"images": None}, id="null-images"),
        pytest.param({"images": {"selected": {"ingredients": {}}}}, id="no-front"),
        pytest.param({"images": {"selected": {"front": {}}}}, id="empty-front"),
        pytest.param({"images": {"selected": {"front": {"fr": None}}}}, id="null-photo"),
        pytest.param({"images": {"selected": {"front": {"fr": {}}}}}, id="no-rev"),
        pytest.param(selected_front(fr="../../x"), id="bad-rev"),
        pytest.param(selected_front(fr=True), id="bool-rev"),
        pytest.param(selected_front(**{"../x": "1"}), id="bad-lang"),
        pytest.param({"images": ["front"]}, id="images-list"),
    ],
)
def test_no_front_photo(record: dict[str, Any]) -> None:
    assert front_image_url(record, EAN) is None


def test_normaliser_stores_the_source_url() -> None:
    record = {"code": EAN, "lang": "fr", "product_name": "Harissa", **selected_front(fr="3")}

    normalized = normalize(EAN, record)

    expected = f"{BASE}/619/150/722/0214/front_fr.3.400.jpg"
    assert normalized.product.source_image_url == expected


@pytest.mark.parametrize(
    ("data", "kind"),
    [
        (JPEG, ("image/jpeg", "jpg")),
        (PNG, ("image/png", "png")),
        (b"GIF89a....", None),
        (b"<html>not found</html>", None),
        (b"", None),
    ],
)
def test_sniff(data: bytes, kind: tuple[str, str] | None) -> None:
    assert sniff(data) == kind


def test_key_follows_the_content() -> None:
    first = image_key(EAN, Image(JPEG, "image/jpeg", "jpg"))
    same = image_key(EAN, Image(JPEG, "image/jpeg", "jpg"))
    other = image_key(EAN, Image(JPEG + b"!", "image/jpeg", "jpg"))

    assert first == same
    assert first != other
    assert first.startswith(f"products/{EAN}/front-")
    assert first.endswith(".jpg")
    assert len(first.rsplit("-", 1)[1]) == len("0123456789abcdef.jpg")
