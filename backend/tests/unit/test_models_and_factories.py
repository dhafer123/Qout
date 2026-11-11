import pytest
from sqlalchemy import Column, ForeignKey, Integer, MetaData, Table, UniqueConstraint
from sqlalchemy.dialects import postgresql
from sqlalchemy.schema import CreateTable

from app.core.models import NAMING_CONVENTION, Base
from tests.factories import WidgetFactory
from tests.models import Widget


def test_base_metadata_uses_naming_convention() -> None:
    assert Base.metadata.naming_convention == NAMING_CONVENTION


def test_naming_convention_produces_expected_names() -> None:
    metadata = MetaData(naming_convention=NAMING_CONVENTION)
    Table("brands", metadata, Column("id", Integer, primary_key=True))
    products = Table(
        "products",
        metadata,
        Column("id", Integer, primary_key=True),
        Column("ean", Integer, index=True),
        Column("brand_id", ForeignKey("brands.id")),
        UniqueConstraint("ean"),
    )

    names = {c.name for c in products.constraints} | {i.name for i in products.indexes}

    assert names == {
        "pk_products",
        "uq_products_ean",
        "fk_products_brand_id_brands",
        "ix_products_ean",
    }


def test_mixin_columns_are_server_generated() -> None:
    ddl = str(CreateTable(Widget.__table__).compile(dialect=postgresql.dialect()))  # type: ignore[arg-type]

    assert "id UUID DEFAULT gen_random_uuid() NOT NULL" in ddl
    assert "created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL" in ddl
    assert "updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL" in ddl
    assert "CONSTRAINT pk_widgets PRIMARY KEY (id)" in ddl


def test_factory_builds_unsaved_instance_with_unique_defaults() -> None:
    first, second = WidgetFactory.build(), WidgetFactory.build()

    assert isinstance(first, Widget)
    assert first.name != second.name
    assert first.id is None  # assigned by the database on flush


def test_factory_overrides_defaults() -> None:
    assert WidgetFactory.build(name="custom").name == "custom"


def test_factory_rejects_unknown_fields() -> None:
    with pytest.raises(TypeError, match="unknown fields \\['colour'\\]"):
        WidgetFactory.build(colour="red")
