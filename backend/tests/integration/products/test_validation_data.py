"""Loading the validation data from Postgres: latest current-engine score per product."""

from datetime import date

from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.products.models import ProductStatus
from app.modules.products.validation import load_comparisons, render_markdown
from app.modules.scoring import Category, Grade
from tests.factories import NutritionFactsFactory, ProductFactory, ScoreFactory


async def scored(session: AsyncSession, ean: str, *, version: int = 1, **score: object) -> None:
    product = await ProductFactory.create(session, ean=ean, category=Category.GENERAL)
    facts = await NutritionFactsFactory.create(session, product_id=product.id, version=version)
    await ScoreFactory.create(session, product_id=product.id, nutrition_facts_id=facts.id, **score)


async def test_load_comparisons(db_session: AsyncSession) -> None:
    await scored(db_session, "2000000000015", grade=Grade.B, off_grade=Grade.B)
    await scored(
        db_session,
        "2000000000022",
        grade=None,
        total=None,
        breakdown={"insufficient_data": ["salt_g"]},
        off_grade=Grade.C,
        off_grade_estimated=True,
    )
    await scored(db_session, "2000000000039", off_grade=None)  # OFF has no grade
    await scored(db_session, "2000000000046", engine_version="old", off_grade=Grade.A)

    # Two current scores: the latest one counts.
    product = await ProductFactory.create(db_session, ean="2000000000053", category=Category.CHEESE)
    v1 = await NutritionFactsFactory.create(db_session, product_id=product.id)
    v2 = await NutritionFactsFactory.create(db_session, product_id=product.id, version=2)
    await ScoreFactory.create(
        db_session,
        product_id=product.id,
        nutrition_facts_id=v1.id,
        grade=Grade.E,
        off_grade=Grade.D,
    )
    await ScoreFactory.create(
        db_session,
        product_id=product.id,
        nutrition_facts_id=v2.id,
        grade=Grade.D,
        breakdown={"grade": "D", "assumed_zero": ["fibre_g"]},
        off_grade=Grade.D,
    )
    # Not scorable: hidden, or no category.
    hidden = await ProductFactory.create(
        db_session, category=Category.GENERAL, status=ProductStatus.HIDDEN
    )
    await ScoreFactory.create(db_session, product_id=hidden.id, off_grade=Grade.A)
    await ProductFactory.create(db_session, category=None)

    v = await load_comparisons(db_session)

    assert (v.scorable, v.scored) == (5, 4)  # the old-engine product is not scored yet
    assert [(c.ean, c.ours, c.off) for c in v.comparisons] == [
        ("2000000000015", Grade.B, Grade.B),
        ("2000000000022", None, Grade.C),
        ("2000000000053", Grade.D, Grade.D),
    ]
    insufficient, cheese = v.comparisons[1], v.comparisons[2]
    assert (insufficient.missing, insufficient.off_estimated) == (("salt_g",), True)
    assert (cheese.category, cheese.assumed_zero) == (Category.CHEESE, ("fibre_g",))
    assert (v.exact.matching, v.exact.total) == (2, 2)
    report = render_markdown(v, generated_on=date(2026, 11, 12), source="the test database")
    assert "1 scorable products have no score with this engine yet" in report
