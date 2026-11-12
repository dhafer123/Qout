"""add products, nutrition facts, scores and scan events (T12)

Revision ID: 01aad660aaaa
Revises: c3869ba8f053
Create Date: 2026-11-12 09:42:46.816229+00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "01aad660aaaa"
down_revision: str | Sequence[str] | None = "c3869ba8f053"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "products",
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
                name="product_category",
                native_enum=False,
                create_constraint=True,
            ),
            nullable=True,
        ),
        sa.Column("image_url", sa.Text(), nullable=True),
        sa.Column(
            "source",
            sa.Enum(
                "open_food_facts",
                "contribution",
                "manual",
                name="product_source",
                native_enum=False,
                create_constraint=True,
            ),
            nullable=False,
        ),
        sa.Column(
            "status",
            sa.Enum(
                "unverified",
                "verified",
                "hidden",
                name="product_status",
                native_enum=False,
                create_constraint=True,
            ),
            server_default="unverified",
            nullable=False,
        ),
        sa.Column(
            "quality_flag",
            sa.Enum(
                "complete",
                "incomplete",
                "suspect",
                name="product_quality_flag",
                native_enum=False,
                create_constraint=True,
            ),
            nullable=True,
        ),
        sa.Column("nova_group", sa.SmallInteger(), nullable=True),
        sa.Column(
            "additives",
            postgresql.ARRAY(sa.String(length=16)),
            server_default=sa.text("'{}'::varchar[]"),
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
        sa.CheckConstraint("ean ~ '^[0-9]{8,14}$'", name=op.f("ck_products_ean_digits")),
        sa.CheckConstraint("nova_group BETWEEN 1 AND 4", name=op.f("ck_products_nova_group_range")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_products")),
        sa.UniqueConstraint("ean", name=op.f("uq_products_ean")),
    )
    op.create_table(
        "nutrition_facts",
        sa.Column("product_id", sa.Uuid(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column(
            "basis",
            sa.Enum(
                "per_100g",
                "per_100ml",
                name="nutrition_basis",
                native_enum=False,
                create_constraint=True,
            ),
            nullable=False,
        ),
        sa.Column(
            "source",
            sa.Enum(
                "open_food_facts",
                "contribution",
                "manual",
                name="nutrition_source",
                native_enum=False,
                create_constraint=True,
            ),
            nullable=False,
        ),
        sa.Column("energy_kj", sa.Numeric(), nullable=True),
        sa.Column("sugars_g", sa.Numeric(), nullable=True),
        sa.Column("saturated_fat_g", sa.Numeric(), nullable=True),
        sa.Column("total_fat_g", sa.Numeric(), nullable=True),
        sa.Column("salt_g", sa.Numeric(), nullable=True),
        sa.Column("fibre_g", sa.Numeric(), nullable=True),
        sa.Column("protein_g", sa.Numeric(), nullable=True),
        sa.Column("fvl_percent", sa.Numeric(), nullable=True),
        sa.Column("non_nutritive_sweeteners", sa.Boolean(), nullable=True),
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
            "energy_kj >= 0", name=op.f("ck_nutrition_facts_energy_kj_non_negative")
        ),
        sa.CheckConstraint("fibre_g <= 100", name=op.f("ck_nutrition_facts_fibre_g_at_most_100")),
        sa.CheckConstraint("fibre_g >= 0", name=op.f("ck_nutrition_facts_fibre_g_non_negative")),
        sa.CheckConstraint(
            "fvl_percent <= 100", name=op.f("ck_nutrition_facts_fvl_percent_at_most_100")
        ),
        sa.CheckConstraint(
            "fvl_percent >= 0", name=op.f("ck_nutrition_facts_fvl_percent_non_negative")
        ),
        sa.CheckConstraint(
            "protein_g <= 100", name=op.f("ck_nutrition_facts_protein_g_at_most_100")
        ),
        sa.CheckConstraint(
            "protein_g >= 0", name=op.f("ck_nutrition_facts_protein_g_non_negative")
        ),
        sa.CheckConstraint("salt_g <= 100", name=op.f("ck_nutrition_facts_salt_g_at_most_100")),
        sa.CheckConstraint("salt_g >= 0", name=op.f("ck_nutrition_facts_salt_g_non_negative")),
        sa.CheckConstraint(
            "saturated_fat_g <= 100", name=op.f("ck_nutrition_facts_saturated_fat_g_at_most_100")
        ),
        sa.CheckConstraint(
            "saturated_fat_g >= 0", name=op.f("ck_nutrition_facts_saturated_fat_g_non_negative")
        ),
        sa.CheckConstraint("sugars_g <= 100", name=op.f("ck_nutrition_facts_sugars_g_at_most_100")),
        sa.CheckConstraint("sugars_g >= 0", name=op.f("ck_nutrition_facts_sugars_g_non_negative")),
        sa.CheckConstraint(
            "total_fat_g <= 100", name=op.f("ck_nutrition_facts_total_fat_g_at_most_100")
        ),
        sa.CheckConstraint(
            "total_fat_g >= 0", name=op.f("ck_nutrition_facts_total_fat_g_non_negative")
        ),
        sa.CheckConstraint("version >= 1", name=op.f("ck_nutrition_facts_version_positive")),
        sa.ForeignKeyConstraint(
            ["product_id"],
            ["products.id"],
            name=op.f("fk_nutrition_facts_product_id_products"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_nutrition_facts")),
        sa.UniqueConstraint(
            "product_id", "version", name=op.f("uq_nutrition_facts_product_id_version")
        ),
    )
    op.create_table(
        "scan_events",
        sa.Column("ean", sa.String(length=14), nullable=False),
        sa.Column("product_id", sa.Uuid(), nullable=True),
        sa.Column(
            "outcome",
            sa.Enum(
                "found", "not_found", name="scan_outcome", native_enum=False, create_constraint=True
            ),
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
        sa.CheckConstraint("ean ~ '^[0-9]{8,14}$'", name=op.f("ck_scan_events_ean_digits")),
        sa.ForeignKeyConstraint(
            ["product_id"],
            ["products.id"],
            name=op.f("fk_scan_events_product_id_products"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_scan_events")),
    )
    op.create_index(op.f("ix_scan_events_ean"), "scan_events", ["ean"], unique=False)
    op.create_table(
        "scores",
        sa.Column("product_id", sa.Uuid(), nullable=False),
        sa.Column("nutrition_facts_id", sa.Uuid(), nullable=True),
        sa.Column("engine_version", sa.String(length=32), nullable=False),
        sa.Column(
            "grade",
            sa.Enum(
                "A",
                "B",
                "C",
                "D",
                "E",
                name="score_grade",
                native_enum=False,
                create_constraint=True,
            ),
            nullable=True,
        ),
        sa.Column("total", sa.Integer(), nullable=True),
        sa.Column("breakdown", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column(
            "off_grade",
            sa.Enum(
                "A",
                "B",
                "C",
                "D",
                "E",
                name="score_off_grade",
                native_enum=False,
                create_constraint=True,
            ),
            nullable=True,
        ),
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("clock_timestamp()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "total IS NULL OR grade IS NOT NULL", name=op.f("ck_scores_total_needs_grade")
        ),
        sa.ForeignKeyConstraint(
            ["nutrition_facts_id"],
            ["nutrition_facts.id"],
            name=op.f("fk_scores_nutrition_facts_id_nutrition_facts"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["product_id"],
            ["products.id"],
            name=op.f("fk_scores_product_id_products"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_scores")),
        sa.UniqueConstraint(
            "nutrition_facts_id",
            "engine_version",
            name=op.f("uq_scores_nutrition_facts_id_engine_version"),
        ),
    )
    op.create_index(
        "ix_scores_product_id_created_at", "scores", ["product_id", "created_at"], unique=False
    )


def downgrade() -> None:
    op.drop_index("ix_scores_product_id_created_at", table_name="scores")
    op.drop_table("scores")
    op.drop_index(op.f("ix_scan_events_ean"), table_name="scan_events")
    op.drop_table("scan_events")
    op.drop_table("nutrition_facts")
    op.drop_table("products")
