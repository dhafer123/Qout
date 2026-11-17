"""The panel's model views: products (name, brand and status editable, cache dropped),
nutrition facts and scores (read-only), users (role and active only, not one's own)."""

import httpx
import pytest
from redis.asyncio import Redis

from app.modules.auth.models import User, UserRole
from app.modules.products.cache import cache_key
from app.modules.products.models import Product, ProductStatus
from tests.factories import NutritionFactsFactory, ProductFactory, ScoreFactory
from tests.integration.admin.conftest import Sessions, account, reload


async def product(sessions: Sessions, **values: object) -> Product:
    async with sessions() as session:
        created = await ProductFactory.create(session, **values)
        await session.commit()
        return created


async def test_products_are_listed_and_searched(
    panel: httpx.AsyncClient, sessions: Sessions
) -> None:
    harissa = await product(sessions, name="Harissa du Cap Bon")
    other = await product(sessions, name="Couscous")

    listed = (await panel.get("/admin/product/list")).text
    assert harissa.ean in listed
    assert other.ean in listed

    found = (await panel.get("/admin/product/list", params={"search": "harissa"})).text
    assert harissa.ean in found
    assert other.ean not in found
    assert (await panel.get(f"/admin/product/details/{harissa.id}")).status_code == 200


async def test_editing_a_product_drops_its_cached_response(
    panel: httpx.AsyncClient, sessions: Sessions, redis: Redis
) -> None:
    item = await product(sessions, name="Old name")
    await redis.set(cache_key(item.ean), "{}")

    response = await panel.post(
        f"/admin/product/edit/{item.id}",
        data={"name": "New name", "brand": "Brand", "status": "hidden", "save": "Save"},
    )

    assert response.status_code == 302
    saved = await reload(sessions, Product, item.id)
    assert (saved.name, saved.brand, saved.status) == ("New name", "Brand", ProductStatus.HIDDEN)
    assert await redis.exists(cache_key(item.ean)) == 0


async def test_only_name_brand_and_status_are_editable(
    panel: httpx.AsyncClient, sessions: Sessions
) -> None:
    item = await product(sessions)
    form = (await panel.get(f"/admin/product/edit/{item.id}")).text
    assert 'name="status"' in form
    for column in ("ean", "category", "source", "image_key"):
        assert f'name="{column}"' not in form


@pytest.mark.parametrize("identity", ["product", "nutrition-facts", "score", "user"])
async def test_nothing_is_created_or_deleted(panel: httpx.AsyncClient, identity: str) -> None:
    assert (await panel.get(f"/admin/{identity}/create")).status_code == 403
    assert (await panel.delete(f"/admin/{identity}/delete", params={"pks": "x"})).status_code == 403


async def test_nutrition_and_scores_are_read_only(
    panel: httpx.AsyncClient, sessions: Sessions
) -> None:
    item = await product(sessions)
    async with sessions() as session:
        facts = await NutritionFactsFactory.create(session, product_id=item.id)
        score = await ScoreFactory.create(session, product_id=item.id, nutrition_facts_id=facts.id)
        await session.commit()

    assert str(item.id) in (await panel.get("/admin/nutrition-facts/list")).text
    assert (await panel.get(f"/admin/score/details/{score.id}")).status_code == 200
    assert (await panel.get(f"/admin/score/edit/{score.id}")).status_code == 403
    assert (await panel.get(f"/admin/nutrition-facts/edit/{facts.id}")).status_code == 403


async def test_users_are_listed_without_password_hashes(
    panel: httpx.AsyncClient, sessions: Sessions, admin: User
) -> None:
    contributor = await account(sessions, "contributor@example.tn")
    listed = (await panel.get("/admin/user/list")).text
    assert contributor.email in listed
    details = (await panel.get(f"/admin/user/details/{contributor.id}")).text
    assert contributor.email in details
    assert "argon2" not in details
    assert "password" not in details.lower()


async def test_a_moderator_promotes_and_deactivates_others(
    panel: httpx.AsyncClient, sessions: Sessions
) -> None:
    contributor = await account(sessions, "contributor@example.tn")

    response = await panel.post(
        f"/admin/user/edit/{contributor.id}", data={"role": "admin", "save": "Save"}
    )  # an unticked box is not sent: inactive

    assert response.status_code == 302
    saved = await reload(sessions, User, contributor.id)
    assert (saved.role, saved.is_active) == (UserRole.ADMIN, False)


@pytest.mark.parametrize(
    "form",
    [{"role": "contributor", "is_active": "y"}, {"role": "admin"}],
    ids=["demote", "deactivate"],
)
async def test_a_moderator_cannot_remove_their_own_access(
    panel: httpx.AsyncClient, sessions: Sessions, admin: User, form: dict[str, str]
) -> None:
    response = await panel.post(f"/admin/user/edit/{admin.id}", data=form | {"save": "Save"})

    assert response.status_code == 400
    assert "can&#39;t remove your own admin access" in response.text
    saved = await reload(sessions, User, admin.id)
    assert (saved.role, saved.is_active) == (UserRole.ADMIN, True)


async def test_a_moderator_may_save_their_own_account_unchanged(
    panel: httpx.AsyncClient, admin: User
) -> None:
    response = await panel.post(
        f"/admin/user/edit/{admin.id}", data={"role": "admin", "is_active": "y", "save": "Save"}
    )
    assert response.status_code == 302
