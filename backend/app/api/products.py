"""Product lookup by barcode."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status

from app.api.deps import SessionDep
from app.core.config import Settings
from app.modules.products.alternatives import (
    AlternativesFinder,
    AlternativesProductNotFoundError,
)
from app.modules.products.cache import ProductCache
from app.modules.products.ean import InvalidEanError
from app.modules.products.lookup import (
    ProductLookup,
    ProductNotFoundError,
    ProductSourceUnavailableError,
)
from app.modules.products.schemas import (
    AlternativeProduct,
    ErrorResponse,
    ProductAlternatives,
    ProductDetail,
)

router = APIRouter(prefix="/v1/products", tags=["products"])

RETRY_AFTER_SECONDS = 30
"""Sent with 503: how long the app should wait before asking again."""


def get_product_lookup(request: Request, session: SessionDep) -> ProductLookup:
    settings: Settings = request.app.state.settings
    cache = ProductCache(
        request.app.state.redis,
        ttl_seconds=settings.product_cache_ttl_seconds,
        not_found_ttl_seconds=settings.product_not_found_ttl_seconds,
    )
    return ProductLookup(session, request.app.state.off_client, cache)


@router.get(
    "/{ean}",
    summary="Look up a product by barcode",
    description=(
        "Barcode: EAN-8, UPC-A (returned as EAN-13), EAN-13 or GTIN-14, with a valid check "
        "digit. Served from the cache or our database; unknown barcodes are looked up on "
        "Open Food Facts, stored and scored."
    ),
    responses={
        status.HTTP_404_NOT_FOUND: {"model": ErrorResponse, "description": "Unknown barcode"},
        status.HTTP_422_UNPROCESSABLE_CONTENT: {
            "model": ErrorResponse,
            "description": "Not a valid barcode",
        },
        status.HTTP_503_SERVICE_UNAVAILABLE: {
            "model": ErrorResponse,
            "description": "Not stored, and Open Food Facts is unavailable; retry later",
        },
    },
)
async def get_product(
    ean: str, lookup: Annotated[ProductLookup, Depends(get_product_lookup)]
) -> ProductDetail:
    try:
        return await lookup.lookup(ean)
    except InvalidEanError as error:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, str(error)) from error
    except ProductNotFoundError as error:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(error)) from error
    except ProductSourceUnavailableError as error:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            str(error),
            headers={"Retry-After": str(RETRY_AFTER_SECONDS)},
        ) from error


@router.get(
    "/{ean}/alternatives",
    summary="Better alternatives to a product",
    description=(
        "Products of the same kind (Nutri-Score category and shared Open Food Facts food "
        "categories) with a strictly better grade, closest nutrient profile first. Reads our "
        "database only; the product must have been looked up before. A product without a "
        "grade has no alternatives (empty list)."
    ),
    responses={
        status.HTTP_404_NOT_FOUND: {"model": ErrorResponse, "description": "Unknown product"},
        status.HTTP_422_UNPROCESSABLE_CONTENT: {
            "model": ErrorResponse,
            "description": "Not a valid barcode, or limit out of range",
        },
    },
)
async def get_product_alternatives(
    ean: str,
    session: SessionDep,
    limit: Annotated[int, Query(ge=1, le=20, description="How many, at most")] = 5,
) -> ProductAlternatives:
    try:
        found = await AlternativesFinder(session).find(ean, limit=limit)
    except InvalidEanError as error:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, str(error)) from error
    except AlternativesProductNotFoundError as error:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(error)) from error
    return ProductAlternatives(
        ean=found.ean,
        items=[
            AlternativeProduct(
                ean=item.ean,
                name=item.name,
                brand=item.brand,
                grade=item.grade,
                total=item.total,
                nova_group=item.nova_group,
            )
            for item in found.items
        ],
    )
