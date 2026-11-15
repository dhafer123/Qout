"""Submitting contributions and reading one's own.

A submission refers to photos uploaded beforehand (`POST /v1/uploads`). Each key must be
one this contributor got for this contribution and for that kind of photo, and must exist
in storage; otherwise the submission is refused. Sending the same contribution again
(same contributor and `client_id`, e.g. an outbox retry) returns the stored one.
"""

import re
import uuid
from collections.abc import Sequence
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.storage import Bucket
from app.modules.contributions.models import Contribution
from app.modules.contributions.nutrition import stored_nutrition
from app.modules.contributions.schemas import ContributionCreate, PhotoKind
from app.modules.contributions.uploads import EXTENSIONS, contribution_prefix
from app.modules.products.ean import normalize_ean

_RANDOM_PART = r"[0-9a-f]{16}"
_EXTENSIONS = "|".join(sorted(EXTENSIONS.values()))


class InvalidContributionError(ValueError):
    """The submission refers to photos it may not use."""


class ContributionNotFoundError(Exception):
    def __init__(self, contribution_id: uuid.UUID) -> None:
        super().__init__(f"no contribution {contribution_id}")


@dataclass(frozen=True)
class Submitted:
    contribution: Contribution
    created: bool
    """False: the same contribution was already stored (a resend)."""


def photo_key_problem(
    user_id: uuid.UUID, client_id: uuid.UUID, kind: PhotoKind, key: str
) -> str | None:
    """Why `key` can't be this contribution's `kind` photo, or None."""
    prefix = contribution_prefix(user_id, client_id)
    pattern = re.escape(prefix) + rf"{kind.value}-{_RANDOM_PART}\.(?:{_EXTENSIONS})"
    if re.fullmatch(pattern, key) is None:
        return f"{kind.value} photo: not an upload of yours for this contribution"
    return None


class ContributionService:
    def __init__(self, session: AsyncSession, uploads: Bucket) -> None:
        self._session = session
        self._uploads = uploads

    async def submit(self, user_id: uuid.UUID, body: ContributionCreate) -> Submitted:
        """Raises InvalidEanError, InvalidContributionError, StorageError."""
        ean = normalize_ean(body.ean)
        stored = await self._find(user_id, body.client_id)
        if stored is not None:
            return Submitted(stored, created=False)
        photos = await self._checked_photos(user_id, body)

        contribution = Contribution(
            user_id=user_id,
            client_id=body.client_id,
            ean=ean,
            name=body.name,
            brand=body.brand,
            category=body.category,
            basis=body.basis,
            nutrition=stored_nutrition(body.nutrition),
            photos=photos,
            ocr_text=body.ocr_text.model_dump(exclude_none=True),
            parser_used=body.parser_used,
        )
        try:
            async with self._session.begin_nested():
                self._session.add(contribution)
        except IntegrityError:
            # Sent twice at the same time: the other request stored it.
            stored = await self._find(user_id, body.client_id)
            if stored is None:  # pragma: no cover - deleted in between
                raise
            return Submitted(stored, created=False)
        await self._session.commit()
        await self._session.refresh(contribution)
        return Submitted(contribution, created=True)

    async def mine(self, user_id: uuid.UUID, *, limit: int) -> Sequence[Contribution]:
        query = (
            select(Contribution)
            .where(Contribution.user_id == user_id)
            .order_by(Contribution.created_at.desc(), Contribution.id)
            .limit(limit)
        )
        return (await self._session.scalars(query)).all()

    async def get_mine(self, user_id: uuid.UUID, contribution_id: uuid.UUID) -> Contribution:
        """Someone else's contribution is reported as not found."""
        contribution = await self._session.get(Contribution, contribution_id)
        if contribution is None or contribution.user_id != user_id:
            raise ContributionNotFoundError(contribution_id)
        return contribution

    async def _find(self, user_id: uuid.UUID, client_id: uuid.UUID) -> Contribution | None:
        query = select(Contribution).where(
            Contribution.user_id == user_id, Contribution.client_id == client_id
        )
        return await self._session.scalar(query)

    async def _checked_photos(self, user_id: uuid.UUID, body: ContributionCreate) -> dict[str, str]:
        photos = {
            kind: key for kind in PhotoKind if (key := getattr(body.photos, kind.value)) is not None
        }
        for kind, key in photos.items():
            problem = photo_key_problem(user_id, body.client_id, kind, key)
            if problem is not None:
                raise InvalidContributionError(problem)
        for kind, key in photos.items():
            if await self._uploads.head(key) is None:
                raise InvalidContributionError(f"{kind.value} photo: not uploaded")
        return {kind.value: key for kind, key in photos.items()}
