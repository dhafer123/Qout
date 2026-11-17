"""Admin panel (`/admin`, moderators only): SQLAdmin model views for products, nutrition
facts, scores and users, plus custom moderation pages. See `app.admin.auth` for signing in.
"""

from pathlib import Path

from sqladmin import Admin
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
from starlette.applications import Starlette
from starlette.middleware import Middleware

from app.admin.auth import AdminAuth
from app.admin.context import MainAppMiddleware
from app.admin.pages import ModerationView, ReportsView
from app.admin.views import NutritionFactsAdmin, ProductAdmin, ScoreAdmin, UserAdmin
from app.core.config import Settings

BASE_URL = "/admin"
TEMPLATES_DIR = Path(__file__).parent / "templates"


def mount_admin(
    app: Starlette, settings: Settings, sessions: async_sessionmaker[AsyncSession]
) -> Admin:
    """Mount the panel on the API at `/admin`."""
    auth = AdminAuth(settings)
    admin = Admin(
        app,
        session_maker=sessions,
        base_url=BASE_URL,
        title="Qout admin",
        templates_dir=str(TEMPLATES_DIR),
        middlewares=[Middleware(MainAppMiddleware, main=app)],
        authentication_backend=auth,
    )
    auth.templates = admin.templates
    for view in (ModerationView, ReportsView):
        admin.add_base_view(view)
    for model_view in (ProductAdmin, NutritionFactsAdmin, ScoreAdmin, UserAdmin):
        admin.add_model_view(model_view)
    return admin
