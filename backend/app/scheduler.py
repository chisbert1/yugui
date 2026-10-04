"""
app/scheduler.py
-----------------
APScheduler setup for background sync jobs.
Registered on FastAPI startup, shut down on shutdown.

Job schedule:
  - full_sets_sync:   weekly (configurable via env)
  - full_cards_sync:  weekly (runs after sets to maintain FK order)
  - sqlite_export:    after each card sync completes
  - prices_update:    daily (TODO in Fase 2)
"""

import logging

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger

from app.core.config import settings
from app.services.sqlite_exporter import SQLiteExporter
from app.services.sync_service import SyncService
from app.services.ygoprodeck_client import YGOProDeckClient

logger = logging.getLogger(__name__)

scheduler = AsyncIOScheduler(timezone="UTC")


async def job_sync_sets() -> None:
    """Scheduled job: sync all Yu-Gi-Oh! sets from YGOPRODeck."""
    logger.info("[SCHEDULER] Starting sets sync job...")
    async with YGOProDeckClient() as client:
        service = SyncService(client)
        count = await service.sync_sets()
    logger.info(f"[SCHEDULER] Sets sync done: {count} records.")


async def job_sync_cards() -> None:
    """
    Scheduled job: sync all cards + rebuild SQLite export afterward.
    Sets must be synced first (FK dependency). This job chains both.
    """
    logger.info("[SCHEDULER] Starting full cards sync job...")
    async with YGOProDeckClient() as client:
        service = SyncService(client)
        # Sync sets first to ensure FK integrity
        await service.sync_sets()
        count = await service.sync_cards()
    logger.info(f"[SCHEDULER] Cards sync done: {count} records. Exporting SQLite...")

    # Rebuild the SQLite lite DB after every full card sync
    exporter = SQLiteExporter()
    info = await exporter.export()
    logger.info(f"[SCHEDULER] SQLite export done: {info['size_bytes'] / 1024 / 1024:.1f}MB")


def start_scheduler() -> None:
    """Register all jobs and start the scheduler. Called on FastAPI startup."""

    # Cards + sets: weekly
    scheduler.add_job(
        job_sync_cards,
        trigger=IntervalTrigger(days=settings.SYNC_CARDS_INTERVAL_DAYS),
        id="full_cards_sync",
        name="Full Cards & Sets Sync",
        replace_existing=True,
        misfire_grace_time=3600,  # tolerate up to 1h delay
    )

    scheduler.start()
    logger.info(
        f"[SCHEDULER] Started. Cards sync every {settings.SYNC_CARDS_INTERVAL_DAYS} days."
    )


def stop_scheduler() -> None:
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("[SCHEDULER] Stopped.")
