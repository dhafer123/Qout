"""add moderation edits and report resolution

Revision ID: 2eee12315d26
Revises: 10a49d11654b
Create Date: 2026-11-17 11:36:24.038222+00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "2eee12315d26"
down_revision: str | Sequence[str] | None = "10a49d11654b"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "contributions",
        sa.Column("submitted_values", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    )
    op.add_column("error_reports", sa.Column("resolved_by", sa.Uuid(), nullable=True))
    op.add_column(
        "error_reports", sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True)
    )
    op.create_foreign_key(
        op.f("fk_error_reports_resolved_by_users"),
        "error_reports",
        "users",
        ["resolved_by"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint(
        op.f("fk_error_reports_resolved_by_users"), "error_reports", type_="foreignkey"
    )
    op.drop_column("error_reports", "resolved_at")
    op.drop_column("error_reports", "resolved_by")
    op.drop_column("contributions", "submitted_values")
