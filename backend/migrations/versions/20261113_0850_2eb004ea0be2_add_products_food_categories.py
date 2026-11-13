"""add products food_categories

Revision ID: 2eb004ea0be2
Revises: 2552532e1455
Create Date: 2026-11-13 08:50:07.919206+00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "2eb004ea0be2"
down_revision: str | Sequence[str] | None = "2552532e1455"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "products",
        sa.Column(
            "food_categories",
            postgresql.ARRAY(sa.String(length=128)),
            server_default=sa.text("'{}'::varchar[]"),
            nullable=False,
        ),
    )
    op.create_index(
        "ix_products_food_categories",
        "products",
        ["food_categories"],
        unique=False,
        postgresql_using="gin",
    )


def downgrade() -> None:
    op.drop_index("ix_products_food_categories", table_name="products", postgresql_using="gin")
    op.drop_column("products", "food_categories")
