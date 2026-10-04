"""
app/main.py
-----------
FastAPI application factory.
- Registers all routers under /api/v1/
- Starts the APScheduler on startup
- Triggers the first sync if the DB is empty
- Runs Alembic migrations automatically on startup
"""

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware

from fastapi import Request
from fastapi.responses import JSONResponse
from fastapi_limiter import FastAPILimiter

from app.api.routers import auth, cards, inventory, sets, sync
from app.core.config import settings
from app.core.rate_limiter import init_rate_limiter
from app.scheduler import start_scheduler, stop_scheduler

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger(__name__)


def create_app() -> FastAPI:
    app = FastAPI(
        title="YuGiOh Collector API",
        description="Backend API for the Yu-Gi-Oh! Card Collector mobile app.",
        version="1.0.0",
        docs_url="/docs",
        redoc_url="/redoc",
    )

    # ── Middleware ────────────────────────────────────────────────────────────
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"] if settings.APP_ENV == "development" else [],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.add_middleware(GZipMiddleware, minimum_size=1024)

    # ── Routers ───────────────────────────────────────────────────────────────
    prefix = "/api/v1"
    app.include_router(auth.router,      prefix=prefix)
    app.include_router(cards.router,     prefix=prefix)
    app.include_router(inventory.router, prefix=prefix)
    app.include_router(sets.router,      prefix=prefix)
    app.include_router(sync.router,      prefix=prefix)

    # ── Exception handlers ────────────────────────────────────────────────────
    @app.exception_handler(429)
    async def rate_limit_handler(request: Request, exc: Exception) -> JSONResponse:
        return JSONResponse(
            status_code=429,
            content={"detail": "Too many requests. Please slow down."},
            headers={"Retry-After": "60"},
        )

    # ── Lifecycle events ──────────────────────────────────────────────────────
    @app.on_event("startup")
    async def startup():
        logger.info("Starting YuGiOh Collector API...")
        await _run_migrations()
        await init_rate_limiter()          # Connect fastapi-limiter to Redis
        start_scheduler()
        await _initial_sync_if_needed()
        logger.info("API ready. Docs at /docs")

    @app.on_event("shutdown")
    async def shutdown():
        stop_scheduler()
        from app.core.redis_client import close_redis
        await close_redis()
        logger.info("API shutdown complete.")

    # ── Health check ──────────────────────────────────────────────────────────
    @app.get("/health", tags=["Health"])
    async def health() -> dict:
        return {"status": "ok", "version": "1.0.0"}

    return app


async def _run_migrations() -> None:
    """Run Alembic migrations programmatically on startup."""
    import subprocess
    import sys
    result = subprocess.run(
        [sys.executable, "-m", "alembic", "upgrade", "head"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        logger.error(f"Migration failed: {result.stderr}")
    else:
        logger.info("Database migrations applied.")


async def _initial_sync_if_needed() -> None:
    """
    Trigger a full sync on first startup if master_cards is empty.
    This populates the database without waiting for the scheduled job.
    """
    from app.core.database import AsyncSessionLocal
    from sqlalchemy import func, select
    from app.models.master_card import MasterCard

    async with AsyncSessionLocal() as session:
        result = await session.execute(select(func.count(MasterCard.id)))
        count = result.scalar()

    if count == 0:
        logger.info("Database is empty. Triggering initial sync from YGOPRODeck...")
        from app.scheduler import job_sync_cards
        import asyncio
        asyncio.create_task(job_sync_cards())
    else:
        logger.info(f"Database has {count} cards. Skipping initial sync.")


app = create_app()
