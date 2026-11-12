"""Entry point for the arq CLI: `uv run arq app.worker.main.WorkerSettings`."""

from app.core.config import get_settings
from app.worker.settings import worker_settings

WorkerSettings = worker_settings(get_settings())
