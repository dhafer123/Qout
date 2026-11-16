"""add label fallbacks

Revision ID: d1929e5df7a6
Revises: 10d96b9f2ef3
Create Date: 2026-11-16 10:19:50.641714+00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "d1929e5df7a6"
down_revision: str | Sequence[str] | None = "10d96b9f2ef3"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "label_fallbacks",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("ocr_text", sa.Text(), nullable=False),
        sa.Column(
            "status",
            sa.Enum(
                "pending",
                "done",
                "needs_manual_entry",
                name="label_fallback_status",
                native_enum=False,
                create_constraint=True,
            ),
            server_default="pending",
            nullable=False,
        ),
        sa.Column(
            "reason",
            sa.Enum(
                "disabled",
                "rate_limited",
                "timeout",
                "unavailable",
                "refused",
                "invalid_output",
                "ungrounded_value",
                "failed_checks",
                name="label_fallback_reason",
                native_enum=False,
                create_constraint=True,
            ),
            nullable=True,
        ),
        sa.Column("result", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("model", sa.String(length=100), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "(status = 'done') = (result IS NOT NULL)",
            name=op.f("ck_label_fallbacks_result_when_done"),
        ),
        sa.CheckConstraint(
            "(status = 'needs_manual_entry') = (reason IS NOT NULL)",
            name=op.f("ck_label_fallbacks_reason_when_failed"),
        ),
        sa.CheckConstraint(
            "(status = 'pending') = (completed_at IS NULL)",
            name=op.f("ck_label_fallbacks_completed_unless_pending"),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_label_fallbacks_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_label_fallbacks")),
    )
    op.create_index(
        op.f("ix_label_fallbacks_user_id"), "label_fallbacks", ["user_id"], unique=False
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_label_fallbacks_user_id"), table_name="label_fallbacks")
    op.drop_table("label_fallbacks")
