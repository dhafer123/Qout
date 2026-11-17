"""add contributions photos_deleted_at (cleanup of rejected photos) and a client_id index

Revision ID: 10a49d11654b
Revises: d1929e5df7a6
Create Date: 2026-11-17 11:05:35.454747+00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "10a49d11654b"
down_revision: str | Sequence[str] | None = "d1929e5df7a6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "contributions", sa.Column("photos_deleted_at", sa.DateTime(timezone=True), nullable=True)
    )
    op.create_index(
        op.f("ix_contributions_client_id"), "contributions", ["client_id"], unique=False
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_contributions_client_id"), table_name="contributions")
    op.drop_column("contributions", "photos_deleted_at")
