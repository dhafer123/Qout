"""add products.source_modified_at (T15)

Revision ID: 5b1e0c7d2a91
Revises: 01aad660aaaa
Create Date: 2026-11-12 16:45:00.000000+00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "5b1e0c7d2a91"
down_revision: str | Sequence[str] | None = "01aad660aaaa"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "products", sa.Column("source_modified_at", sa.DateTime(timezone=True), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("products", "source_modified_at")
