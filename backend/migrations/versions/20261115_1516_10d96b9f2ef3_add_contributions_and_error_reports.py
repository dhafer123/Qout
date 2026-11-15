"""add contributions and error reports

Revision ID: 10d96b9f2ef3
Revises: 5c1f3d9a7b42
Create Date: 2026-11-15 15:16:12.436993+00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "10d96b9f2ef3"
down_revision: str | Sequence[str] | None = "5c1f3d9a7b42"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "contributions",
        sa.Column("user_id", sa.Uuid(), nullable=True),
        sa.Column("client_id", sa.Uuid(), nullable=False),
        sa.Column("ean", sa.String(length=14), nullable=False),
        sa.Column("name", sa.Text(), nullable=True),
        sa.Column("brand", sa.Text(), nullable=True),
        sa.Column(
            "category",
            sa.Enum(
                "general",
                "red_meat",
                "cheese",
                "fats_oils_nuts_seeds",
                "beverage",
                "water",
                name="contribution_category",
                native_enum=False,
                create_constraint=True,
            ),
            nullable=False,
        ),
        sa.Column(
            "basis",
            sa.Enum(
                "per_100g",
                "per_100ml",
                name="contribution_nutrition_basis",
                native_enum=False,
                create_constraint=True,
            ),
            nullable=False,
        ),
        sa.Column("nutrition", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("photos", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("ocr_text", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column(
            "parser_used",
            sa.Enum(
                "rules",
                "llm",
                "manual",
                name="contribution_parser",
                native_enum=False,
                create_constraint=True,
            ),
            nullable=False,
        ),
        sa.Column(
            "status",
            sa.Enum(
                "pending",
                "approved",
                "rejected",
                name="contribution_status",
                native_enum=False,
                create_constraint=True,
            ),
            server_default="pending",
            nullable=False,
        ),
        sa.Column("reviewed_by", sa.Uuid(), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("review_note", sa.Text(), nullable=True),
        sa.Column("product_id", sa.Uuid(), nullable=True),
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
        sa.CheckConstraint("ean ~ '^[0-9]{8,14}$'", name=op.f("ck_contributions_ean_digits")),
        sa.ForeignKeyConstraint(
            ["product_id"],
            ["products.id"],
            name=op.f("fk_contributions_product_id_products"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["reviewed_by"],
            ["users.id"],
            name=op.f("fk_contributions_reviewed_by_users"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_contributions_user_id_users"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_contributions")),
        sa.UniqueConstraint(
            "user_id", "client_id", name=op.f("uq_contributions_user_id_client_id")
        ),
    )
    op.create_index(op.f("ix_contributions_ean"), "contributions", ["ean"], unique=False)
    op.create_index(
        "ix_contributions_status_created_at",
        "contributions",
        ["status", "created_at"],
        unique=False,
    )
    op.create_index(op.f("ix_contributions_user_id"), "contributions", ["user_id"], unique=False)
    op.create_table(
        "error_reports",
        sa.Column("client_id", sa.String(length=32), nullable=False),
        sa.Column("ean", sa.String(length=14), nullable=False),
        sa.Column("product_id", sa.Uuid(), nullable=True),
        sa.Column("user_id", sa.Uuid(), nullable=True),
        sa.Column("reasons", postgresql.ARRAY(sa.String(length=16)), nullable=False),
        sa.Column("comment", sa.Text(), nullable=True),
        sa.Column("product_updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("reported_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "status",
            sa.Enum(
                "open",
                "resolved",
                "dismissed",
                name="report_status",
                native_enum=False,
                create_constraint=True,
            ),
            server_default="open",
            nullable=False,
        ),
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
            "client_id ~ '^[0-9a-f]{32}$'", name=op.f("ck_error_reports_client_id_hex")
        ),
        sa.CheckConstraint("ean ~ '^[0-9]{8,14}$'", name=op.f("ck_error_reports_ean_digits")),
        sa.CheckConstraint("cardinality(reasons) > 0", name=op.f("ck_error_reports_has_reasons")),
        sa.CheckConstraint(
            "char_length(comment) <= 500", name=op.f("ck_error_reports_comment_length")
        ),
        sa.ForeignKeyConstraint(
            ["product_id"],
            ["products.id"],
            name=op.f("fk_error_reports_product_id_products"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_error_reports_user_id_users"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_error_reports")),
        sa.UniqueConstraint("client_id", name=op.f("uq_error_reports_client_id")),
    )
    op.create_index(
        op.f("ix_error_reports_product_id"), "error_reports", ["product_id"], unique=False
    )
    op.create_index(
        "ix_error_reports_status_created_at",
        "error_reports",
        ["status", "created_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_error_reports_status_created_at", table_name="error_reports")
    op.drop_index(op.f("ix_error_reports_product_id"), table_name="error_reports")
    op.drop_table("error_reports")
    op.drop_index(op.f("ix_contributions_user_id"), table_name="contributions")
    op.drop_index("ix_contributions_status_created_at", table_name="contributions")
    op.drop_index(op.f("ix_contributions_ean"), table_name="contributions")
    op.drop_table("contributions")
