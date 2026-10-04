"""
app/core/config.py
------------------
Centralised settings loaded from environment variables via Pydantic-Settings.
All other modules import from here — never from os.environ directly.
"""

from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # ── App ──────────────────────────────────────────────────────
    APP_ENV: str = "development"
    APP_SECRET_KEY: str = "change_me_in_production"
    API_SERVICE_KEY: str = "internal_service_key"

    # ── Database ──────────────────────────────────────────────────
    DATABASE_URL: str
    POSTGRES_HOST: str = "postgres"
    POSTGRES_PORT: int = 5432

    # ── Redis ─────────────────────────────────────────────────────
    REDIS_URL: str = "redis://redis:6379/0"

    # ── JWT ───────────────────────────────────────────────────────
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # ── YGOPRODeck ────────────────────────────────────────────────
    YGOPRODECK_BASE_URL: str = "https://db.ygoprodeck.com/api/v7"
    YGOPRODECK_REQUEST_DELAY_SECONDS: float = 1.0
    YGOPRODECK_MAX_RETRIES: int = 5

    # ── Sync Jobs ─────────────────────────────────────────────────
    SYNC_CARDS_INTERVAL_DAYS: int = 7
    SYNC_PRICES_INTERVAL_HOURS: int = 24
    SYNC_SETS_INTERVAL_DAYS: int = 7

    # ── SQLite Export ─────────────────────────────────────────────
    SQLITE_EXPORT_PATH: str = "/app/exports"


@lru_cache
def get_settings() -> Settings:
    """Return cached settings instance (singleton)."""
    return Settings()


settings = get_settings()
