"""add import runs (T15)

Revision ID: 45d29a6e6b22
Revises: 5b1e0c7d2a91
Create Date: 2026-11-12 16:57:46.446039+00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "45d29a6e6b22"
down_revision: str | Sequence[str] | None = "5b1e0c7d2a91"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "import_runs",
        sa.Column(
            "kind",
            sa.Enum("full", "delta", name="import_kind", native_enum=False, create_constraint=True),
            nullable=False,
        ),
        sa.Column("source", sa.String(length=255), nullable=False),
        sa.Column("countries", sa.ARRAY(sa.String(length=64)), nullable=False),
        sa.Column(
            "status",
            sa.Enum(
                "running",
                "completed",
                "failed",
                name="import_status",
                native_enum=False,
                create_constraint=True,
            ),
            nullable=False,
        ),
        sa.Column("checkpoint_line", sa.Integer(), server_default="0", nullable=False),
        sa.Column("finished_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column("lines", sa.Integer(), server_default="0", nullable=False),
        sa.Column("selected", sa.Integer(), server_default="0", nullable=False),
        sa.Column("inserted", sa.Integer(), server_default="0", nullable=False),
        sa.Column("updated", sa.Integer(), server_default="0", nullable=False),
        sa.Column("unchanged", sa.Integer(), server_default="0", nullable=False),
        sa.Column("skipped", sa.Integer(), server_default="0", nullable=False),
        sa.Column("rejected", sa.Integer(), server_default="0", nullable=False),
        sa.Column("failed", sa.Integer(), server_default="0", nullable=False),
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
            "checkpoint_line >= 0", name=op.f("ck_import_runs_checkpoint_non_negative")
        ),
        sa.CheckConstraint("failed >= 0", name=op.f("ck_import_runs_failed_non_negative")),
        sa.CheckConstraint("inserted >= 0", name=op.f("ck_import_runs_inserted_non_negative")),
        sa.CheckConstraint("lines >= 0", name=op.f("ck_import_runs_lines_non_negative")),
        sa.CheckConstraint("rejected >= 0", name=op.f("ck_import_runs_rejected_non_negative")),
        sa.CheckConstraint("selected >= 0", name=op.f("ck_import_runs_selected_non_negative")),
        sa.CheckConstraint("skipped >= 0", name=op.f("ck_import_runs_skipped_non_negative")),
        sa.CheckConstraint("unchanged >= 0", name=op.f("ck_import_runs_unchanged_non_negative")),
        sa.CheckConstraint("updated >= 0", name=op.f("ck_import_runs_updated_non_negative")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_import_runs")),
    )
    op.create_index("ix_import_runs_kind_source", "import_runs", ["kind", "source"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_import_runs_kind_source", table_name="import_runs")
    op.drop_table("import_runs")
