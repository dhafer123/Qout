"""copy product images into our storage

Revision ID: 5c1f3d9a7b42
Revises: 730436261105
Create Date: 2026-11-15 16:00:00.000000+00:00

`image_url` held Open Food Facts' URL; it becomes `source_image_url`, and the copy in our
public bucket is `image_key`. Stored URLs are kept, so the copy job picks them up.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "5c1f3d9a7b42"
down_revision: str | Sequence[str] | None = "730436261105"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column("products", "image_url", new_column_name="source_image_url")
    op.add_column("products", sa.Column("image_key", sa.Text(), nullable=True))
    op.add_column("products", sa.Column("image_copied_from", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("products", "image_copied_from")
    op.drop_column("products", "image_key")
    op.alter_column("products", "source_image_url", new_column_name="image_url")
