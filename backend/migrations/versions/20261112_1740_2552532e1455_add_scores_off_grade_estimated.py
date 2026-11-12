"""add scores.off_grade_estimated (T16)

Revision ID: 2552532e1455
Revises: 45d29a6e6b22
Create Date: 2026-11-12 17:40:57.714310+00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "2552532e1455"
down_revision: str | Sequence[str] | None = "45d29a6e6b22"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("scores", sa.Column("off_grade_estimated", sa.Boolean(), nullable=True))


def downgrade() -> None:
    op.drop_column("scores", "off_grade_estimated")
