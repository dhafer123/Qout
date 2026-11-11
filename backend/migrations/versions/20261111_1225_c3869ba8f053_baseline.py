"""baseline

Empty starting point of the migration chain. Tables arrive with later tasks (T12+).

Revision ID: c3869ba8f053
Revises:
Create Date: 2026-11-11 12:25:20.377313+00:00
"""

from collections.abc import Sequence

# revision identifiers, used by Alembic.
revision: str = "c3869ba8f053"
down_revision: str | Sequence[str] | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
