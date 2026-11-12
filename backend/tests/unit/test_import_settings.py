"""Import settings derived from the application settings."""

from pathlib import Path

from app.core.config import Settings
from app.modules.ingestion.importer import ImportStats
from app.modules.ingestion.off_import import ImportSettings
from app.modules.products.upsert import UpsertOutcome


def test_from_settings(tmp_path: Path) -> None:
    settings = Settings(  # type: ignore[call-arg]
        _env_file=None,
        database_url="postgresql+asyncpg://u:p@h/d",
        redis_url="redis://h",
        import_countries="en:tunisia,algeria",
        import_batch_size=50,
        import_download_dir=tmp_path,
        off_delta_url="https://mirror.test/delta",
    )

    imports = ImportSettings.from_settings(settings)

    assert imports == ImportSettings(
        countries=frozenset({"en:tunisia", "en:algeria"}),
        batch_size=50,
        download_dir=tmp_path,
        export_url="https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz",
        delta_url="https://mirror.test/delta/",
    )


def test_every_upsert_outcome_is_counted() -> None:
    stats = ImportStats()
    for outcome in UpsertOutcome:
        stats.count(outcome)
    assert (stats.inserted, stats.updated, stats.unchanged, stats.skipped) == (1, 1, 1, 2)
