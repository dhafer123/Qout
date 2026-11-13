"""Every ORM model, imported so `Base.metadata` is complete (Alembic, drift test).

Add each new module's models here.
"""

from app.core.models import Base
from app.modules.auth import models as auth
from app.modules.ingestion import models as ingestion
from app.modules.products import models as products

__all__ = ["Base", "auth", "ingestion", "products"]
