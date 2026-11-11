"""Test-only ORM models.

They use their own metadata and live in the `testing` schema, so they never appear in
migrations, in `Base.metadata`, or in the migration drift check.
"""

from sqlalchemy import MetaData, String
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

from app.core.models import NAMING_CONVENTION, IdTimestampMixin

TEST_SCHEMA = "testing"


class TestBase(DeclarativeBase):
    __test__ = False  # not a pytest test class
    metadata = MetaData(schema=TEST_SCHEMA, naming_convention=NAMING_CONVENTION)


class Widget(IdTimestampMixin, TestBase):
    __tablename__ = "widgets"

    name: Mapped[str] = mapped_column(String(100))
