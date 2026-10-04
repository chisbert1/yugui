"""
app/api/routers/sync.py
------------------------
Sync-related endpoints:
  - GET /sync/database/lite  → download the SQLite file for mobile offline use
  - POST /sync/trigger/*     → manually trigger sync jobs (admin/service key)
  - GET /sync/status         → view last sync job status
"""

import asyncio

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from fastapi.responses import FileResponse

from app.api.deps import CurrentUser, require_service_key
from app.models.sync_metadata import SyncMetadata
from app.services.sqlite_exporter import SQLiteExporter
from app.services.sync_service import SyncService
from app.services.ygoprodeck_client import YGOProDeckClient
from app.core.database import AsyncSessionLocal
from sqlalchemy import select

router = APIRouter(prefix="/sync", tags=["Sync"])


# ── Mobile: Download SQLite lite DB ──────────────────────────────────────────

@router.get("/database/lite")
async def download_lite_db(_: CurrentUser) -> FileResponse:
    """
    Download the compressed SQLite database for mobile offline use.
    Returns the gzip-compressed file with SHA-256 hash in response header.
    The mobile app checks X-DB-Hash against its cached hash to skip re-download.
    """
    info = SQLiteExporter.get_latest_info()
    if not info:
        raise HTTPException(
            status_code=503,
            detail="Database export not yet available. Try again later.",
        )

    return FileResponse(
        path=info["path"],
        media_type="application/octet-stream",
        filename="yugioh_lite.db.gz",
        headers={
            "X-DB-Hash": info["hash"],
            "X-DB-Size": str(info["size_bytes"]),
            "X-DB-Generated-At": info["generated_at"],
            "Cache-Control": "public, max-age=3600",
        },
    )


# ── Admin: Trigger sync jobs ──────────────────────────────────────────────────

async def _run_full_sync() -> None:
    """Background task: sync sets + cards + rebuild SQLite."""
    async with YGOProDeckClient() as client:
        service = SyncService(client)
        await service.sync_sets()
        await service.sync_cards()
    exporter = SQLiteExporter()
    await exporter.export()


@router.post(
    "/trigger/cards",
    dependencies=[Depends(require_service_key)],
    status_code=202,
)
async def trigger_cards_sync(background_tasks: BackgroundTasks) -> dict:
    """
    Manually trigger a full cards + sets sync (admin only).
    Runs asynchronously in the background.
    Requires X-Service-Key header.
    """
    background_tasks.add_task(_run_full_sync)
    return {"message": "Full sync triggered in background."}


@router.post(
    "/trigger/sets",
    dependencies=[Depends(require_service_key)],
    status_code=202,
)
async def trigger_sets_sync(background_tasks: BackgroundTasks) -> dict:
    """Manually trigger a sets-only sync (admin only)."""
    async def _sync_sets():
        async with YGOProDeckClient() as client:
            service = SyncService(client)
            await service.sync_sets()

    background_tasks.add_task(_sync_sets)
    return {"message": "Sets sync triggered in background."}


# ── Admin: Sync status ────────────────────────────────────────────────────────

@router.get("/status", dependencies=[Depends(require_service_key)])
async def get_sync_status() -> dict:
    """Return the status of the 5 most recent sync jobs."""
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(SyncMetadata).order_by(SyncMetadata.started_at.desc()).limit(5)
        )
        logs = result.scalars().all()

    return {
        "recent_jobs": [
            {
                "id": log.id,
                "type": log.sync_type,
                "status": log.status,
                "started_at": log.started_at.isoformat(),
                "completed_at": log.completed_at.isoformat() if log.completed_at else None,
                "records_synced": log.records_synced,
                "error": log.error_message,
            }
            for log in logs
        ],
        "latest_export": SQLiteExporter.get_latest_info(),
    }
