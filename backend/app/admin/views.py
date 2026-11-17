"""Model views of the admin panel: products, nutrition facts, scores, users.

Nothing is created or deleted here: products come from Open Food Facts or contributions
(a product is hidden, not deleted), accounts from the app. What can be edited is limited:
a product's name, brand and status (nutrition and category go through contributions, which
rescore), a user's role and active flag.
"""

from typing import Any, ClassVar, override

from sqladmin import ModelView
from sqladmin.filters import BooleanFilter, StaticValuesFilter
from starlette.requests import Request

from app.admin.context import product_cache, signed_in_admin
from app.modules.auth.models import User, UserRole
from app.modules.products.models import (
    DataSource,
    NutritionFacts,
    Product,
    ProductStatus,
    Score,
)


def _choices(enum: Any) -> list[tuple[str, str]]:
    return [(member.value, member.value) for member in enum]


class ReadOnlyView(ModelView):
    can_create = False
    can_edit = False
    can_delete = False
    can_export = False
    page_size = 50


class ProductAdmin(ModelView, model=Product):
    category = "Catalogue"
    icon = "fa-solid fa-box"
    can_create = False
    can_delete = False
    can_export = False
    page_size = 50
    column_list: ClassVar[Any] = [
        Product.ean,
        Product.name,
        Product.brand,
        Product.category,
        Product.source,
        Product.status,
        Product.quality_flag,
        Product.updated_at,
    ]
    column_searchable_list: ClassVar[Any] = [Product.ean, Product.name, Product.brand]
    column_sortable_list: ClassVar[Any] = [Product.ean, Product.name, Product.updated_at]
    column_default_sort: ClassVar[Any] = (Product.updated_at, True)
    column_filters: ClassVar[Any] = [
        StaticValuesFilter(Product.source, _choices(DataSource)),
        StaticValuesFilter(Product.status, _choices(ProductStatus)),
    ]
    form_columns: ClassVar[Any] = [Product.name, Product.brand, Product.status]

    @override
    async def after_model_change(
        self, data: dict[str, Any], model: Any, is_created: bool, request: Request
    ) -> None:
        """The lookup serves cached responses: drop this product's."""
        await product_cache(request).invalidate(model.ean)


class NutritionFactsAdmin(ReadOnlyView, model=NutritionFacts):
    name_plural = "Nutrition facts"
    category = "Catalogue"
    icon = "fa-solid fa-list"
    column_list: ClassVar[Any] = [
        NutritionFacts.product_id,
        NutritionFacts.version,
        NutritionFacts.basis,
        NutritionFacts.source,
        NutritionFacts.energy_kj,
        NutritionFacts.sugars_g,
        NutritionFacts.saturated_fat_g,
        NutritionFacts.salt_g,
        NutritionFacts.created_at,
    ]
    column_searchable_list: ClassVar[Any] = [NutritionFacts.product_id]
    column_default_sort: ClassVar[Any] = (NutritionFacts.created_at, True)


class ScoreAdmin(ReadOnlyView, model=Score):
    category = "Catalogue"
    icon = "fa-solid fa-star"
    column_list: ClassVar[Any] = [
        Score.product_id,
        Score.engine_version,
        Score.grade,
        Score.total,
        Score.off_grade,
        Score.off_grade_estimated,
        Score.created_at,
    ]
    column_searchable_list: ClassVar[Any] = [Score.product_id]
    column_default_sort: ClassVar[Any] = (Score.created_at, True)


class UserAdmin(ModelView, model=User):
    icon = "fa-solid fa-user"
    can_create = False
    can_delete = False
    can_export = False
    page_size = 50
    column_list: ClassVar[Any] = [
        User.email,
        User.role,
        User.is_active,
        User.last_login_at,
        User.created_at,
    ]
    column_details_list: ClassVar[Any] = [
        User.id,
        User.email,
        User.role,
        User.is_active,
        User.last_login_at,
        User.created_at,
        User.updated_at,
    ]
    column_searchable_list: ClassVar[Any] = [User.email]
    column_sortable_list: ClassVar[Any] = [User.email, User.last_login_at, User.created_at]
    column_default_sort: ClassVar[Any] = (User.created_at, True)
    column_filters: ClassVar[Any] = [
        StaticValuesFilter(User.role, _choices(UserRole)),
        BooleanFilter(User.is_active),
    ]
    form_columns: ClassVar[Any] = [User.role, User.is_active]

    @override
    async def on_model_change(
        self, data: dict[str, Any], model: Any, is_created: bool, request: Request
    ) -> None:
        """A moderator can't take away their own access (nobody left to give it back)."""
        if model.id != signed_in_admin(request):
            return
        role = data.get("role", model.role)
        if UserRole(getattr(role, "value", role)) != UserRole.ADMIN or not data.get(
            "is_active", model.is_active
        ):
            msg = "You can't remove your own admin access; ask another moderator."
            raise ValueError(msg)
