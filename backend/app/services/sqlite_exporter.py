"""
app/services/sqlite_exporter.py
--------------------------------
Generates a lightweight SQLite database for mobile offline use.

The exported .db file contains:
  - master_sets      (id, set_name, set_code)
  - master_cards     (id, name, card_type, image_url_small)
  - card_sets_link   (id, card_id, set_id, set_code, rarity)

This is intentionally minimal (~5–12MB) to allow fast over-the-air updates.
Images are NOT included — loaded on demand by the mobile app.

The file is compressed with gzip after generation.
A SHA-256 hash is computed and stored alongside for integrity checking.
"""

import gzip
import hashlib
import logging
import os
import sqlite3
import tempfile
from datetime import UTC, datetime
from pathlib import Path

from sqlalchemy import text

from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.models.sync_metadata import SyncMetadata

logger = logging.getLogger(__name__)

EXPORT_DIR = Path(settings.SQLITE_EXPORT_PATH)
DB_FILENAME = "yugioh_lite.db"
GZ_FILENAME = "yugioh_lite.db.gz"
HASH_FILENAME = "yugioh_lite.db.gz.sha256"


class SQLiteExporter:
    """Exports a read-only SQLite snapshot from PostgreSQL for mobile sync."""

    async def export(self) -> dict:
        """
        Main entry point. Exports data, compresses, computes hash.
        Returns dict with { path, hash, size_bytes, record_counts }.
        """
        sync_log = await self._start_sync_log()
        try:
            result = await self._do_export()
            await self._finish_sync_log(sync_log, "completed", result["total_records"])
            return result
        except Exception as exc:
            await self._finish_sync_log(sync_log, "failed", error=str(exc))
            logger.exception("SQLite export failed.")
            raise

    async def _do_export(self) -> dict:
        EXPORT_DIR.mkdir(parents=True, exist_ok=True)

        db_path = EXPORT_DIR / DB_FILENAME
        gz_path = EXPORT_DIR / GZ_FILENAME
        hash_path = EXPORT_DIR / HASH_FILENAME

        # Step 1: Build the SQLite file in a temp location then move atomically
        with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as tmp:
            tmp_path = tmp.name

        try:
            record_counts = await self._build_sqlite(tmp_path)

            # Step 2: Compress
            with open(tmp_path, "rb") as f_in:
                with gzip.open(str(gz_path) + ".tmp", "wb", compresslevel=6) as f_out:
                    f_out.write(f_in.read())

            # Step 3: Atomic replace
            os.replace(str(gz_path) + ".tmp", str(gz_path))

            # Step 4: Compute SHA-256 of the compressed file
            sha256 = self._compute_sha256(gz_path)
            hash_path.write_text(sha256)

            # Step 5: Copy the uncompressed DB for reference
            os.replace(tmp_path, str(db_path))

            total = sum(record_counts.values())
            size = gz_path.stat().st_size

            logger.info(
                f"SQLite export complete: {total} records, "
                f"{size / 1024 / 1024:.1f}MB compressed. SHA256={sha256[:12]}..."
            )
            return {
                "path": str(gz_path),
                "hash": sha256,
                "size_bytes": size,
                "total_records": total,
                "record_counts": record_counts,
                "generated_at": datetime.now(UTC).isoformat(),
            }
        finally:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)

    async def _build_sqlite(self, db_path: str) -> dict:
        """
        Reads data from PostgreSQL async and writes it to a SQLite file.
        Returns a dict of table → record count.
        """
        conn = sqlite3.connect(db_path, isolation_level=None)
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA synchronous=NORMAL")

        # ── Schema ─────────────────────────────────────────────────────────
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS master_sets (
                id          INTEGER PRIMARY KEY,
                set_name    TEXT    NOT NULL,
                set_code    TEXT    NOT NULL UNIQUE
            );

            CREATE TABLE IF NOT EXISTS master_cards (
                id              INTEGER PRIMARY KEY,
                name            TEXT    NOT NULL,
                card_type       TEXT    NOT NULL,
                image_url_small TEXT
            );

            CREATE TABLE IF NOT EXISTS card_sets_link (
                id      INTEGER PRIMARY KEY,
                card_id INTEGER NOT NULL REFERENCES master_cards(id),
                set_id  INTEGER NOT NULL REFERENCES master_sets(id),
                set_code TEXT   NOT NULL,
                rarity   TEXT   NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_lite_csl_set_code ON card_sets_link(set_code);
            CREATE INDEX IF NOT EXISTS idx_lite_cards_name   ON master_cards(name);
        """)

        counts = {}

        async with AsyncSessionLocal() as session:
            # ── Export master_sets ──────────────────────────────────────────
            result = await session.execute(
                text("SELECT id, set_name, set_code FROM master_sets ORDER BY id")
            )
            rows = result.fetchall()
            conn.executemany(
                "INSERT OR REPLACE INTO master_sets (id, set_name, set_code) VALUES (?,?,?)",
                rows,
            )
            counts["master_sets"] = len(rows)
            logger.debug(f"Exported {len(rows)} sets.")

            # ── Export master_cards ─────────────────────────────────────────
            result = await session.execute(
                text("SELECT id, name, card_type, image_url_small FROM master_cards ORDER BY id")
            )
            rows = result.fetchall()
            conn.executemany(
                "INSERT OR REPLACE INTO master_cards (id, name, card_type, image_url_small) VALUES (?,?,?,?)",
                rows,
            )
            counts["master_cards"] = len(rows)
            logger.debug(f"Exported {len(rows)} cards.")

            # ── Export card_sets_link ───────────────────────────────────────
            result = await session.execute(
                text("SELECT id, card_id, set_id, set_code, rarity FROM card_sets_link ORDER BY id")
            )
            rows = result.fetchall()
            conn.executemany(
                "INSERT OR REPLACE INTO card_sets_link (id, card_id, set_id, set_code, rarity) VALUES (?,?,?,?,?)",
                rows,
            )
            counts["card_sets_link"] = len(rows)
            logger.debug(f"Exported {len(rows)} card-set links.")

        conn.execute("VACUUM")
        conn.close()
        return counts

    @staticmethod
    def _compute_sha256(path: Path) -> str:
        sha = hashlib.sha256()
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                sha.update(chunk)
        return sha.hexdigest()

    # ── Latest export info ────────────────────────────────────────────────────

    @staticmethod
    def get_latest_info() -> dict | None:
        """Return metadata about the most recently generated export, or None."""
        gz_path = EXPORT_DIR / GZ_FILENAME
        hash_path = EXPORT_DIR / HASH_FILENAME
        if not gz_path.exists():
            return None
        sha256 = hash_path.read_text().strip() if hash_path.exists() else "unknown"
        stat = gz_path.stat()
        return {
            "path": str(gz_path),
            "hash": sha256,
            "size_bytes": stat.st_size,
            "generated_at": datetime.fromtimestamp(stat.st_mtime, tz=UTC).isoformat(),
        }

    # ── Audit Logging ─────────────────────────────────────────────────────────

    async def _start_sync_log(self) -> SyncMetadata:
        async with AsyncSessionLocal() as session:
            log = SyncMetadata(sync_type="sqlite_export", status="running")
            session.add(log)
            await session.commit()
            await session.refresh(log)
            return log

    async def _finish_sync_log(
        self,
        log: SyncMetadata,
        status: str,
        records: int = 0,
        error: str | None = None,
    ) -> None:
        async with AsyncSessionLocal() as session:
            db_log = await session.get(SyncMetadata, log.id)
            if db_log:
                db_log.status = status
                db_log.completed_at = datetime.now(UTC)
                db_log.records_synced = records
                db_log.error_message = error
                await session.commit()
