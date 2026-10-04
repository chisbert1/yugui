"""
app/services/sync_service.py
-----------------------------
Core synchronisation logic: downloads data from YGOPRODeck
and UPSERTs it into our PostgreSQL database.

Strategy:
  - Sets first (cards reference sets via set_code)
  - Cards in batches of 500 to avoid memory pressure
  - Uses PostgreSQL ON CONFLICT DO UPDATE for idempotent sync
  - Writes a SyncMetadata record for observability
"""

import logging
from datetime import UTC, datetime

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import AsyncSessionLocal
from app.models.sync_metadata import SyncMetadata
from app.services.ygoprodeck_client import YGOProDeckClient

logger = logging.getLogger(__name__)

CARD_BATCH_SIZE = 500


class SyncService:
    """
    Handles the full synchronisation pipeline:
      fetch_sets() → upsert_sets()
      fetch_cards() → upsert_cards_and_links()
    """

    def __init__(self, client: YGOProDeckClient) -> None:
        self.client = client

    # ── Sets ──────────────────────────────────────────────────────────────────

    async def sync_sets(self) -> int:
        """Download and upsert all Yu-Gi-Oh! sets. Returns the count synced."""
        sync_log = await self._start_sync_log("full_sets")
        count = 0
        try:
            raw_sets = await self.client.fetch_all_sets()
            async with AsyncSessionLocal() as session:
                count = await self._upsert_sets(session, raw_sets)
                await session.commit()
            await self._finish_sync_log(sync_log, "completed", count)
            logger.info(f"Sets sync complete: {count} records.")
        except Exception as exc:
            await self._finish_sync_log(sync_log, "failed", error=str(exc))
            logger.exception("Sets sync failed.")
            raise
        return count

    async def _upsert_sets(self, session: AsyncSession, raw_sets: list[dict]) -> int:
        """
        UPSERT sets using raw SQL for performance (avoids ORM per-row overhead).
        INSERT ... ON CONFLICT (set_code) DO UPDATE ...
        """
        upsert_sql = text("""
            INSERT INTO master_sets (set_name, set_code, set_type, num_of_cards, tcg_date, set_image_url, source_updated_at)
            VALUES (:set_name, :set_code, :set_type, :num_of_cards, :tcg_date, :set_image_url, NOW())
            ON CONFLICT (set_code) DO UPDATE SET
                set_name        = EXCLUDED.set_name,
                set_type        = EXCLUDED.set_type,
                num_of_cards    = EXCLUDED.num_of_cards,
                tcg_date        = EXCLUDED.tcg_date,
                set_image_url   = EXCLUDED.set_image_url,
                source_updated_at = NOW()
        """)

        params = []
        for s in raw_sets:
            params.append({
                "set_name":     s.get("set_name", ""),
                "set_code":     s.get("set_code", "").upper(),
                "set_type":     s.get("set_type"),
                "num_of_cards": s.get("num_of_cards"),
                "tcg_date":     s.get("tcg_date") or None,
                "set_image_url":s.get("set_image_url"),
            })

        if params:
            await session.execute(upsert_sql, params)
        return len(params)

    # ── Cards ─────────────────────────────────────────────────────────────────

    async def sync_cards(self) -> int:
        """
        Download and upsert all Yu-Gi-Oh! cards + their set links.
        Processes in batches to control memory usage.
        Returns total card count synced.
        """
        sync_log = await self._start_sync_log("full_cards")
        total_synced = 0
        try:
            raw_cards = await self.client.fetch_all_cards()

            # Process in batches
            for i in range(0, len(raw_cards), CARD_BATCH_SIZE):
                batch = raw_cards[i : i + CARD_BATCH_SIZE]
                async with AsyncSessionLocal() as session:
                    await self._upsert_cards_batch(session, batch)
                    await session.commit()
                total_synced += len(batch)
                logger.info(f"Synced {total_synced}/{len(raw_cards)} cards...")

            await self._finish_sync_log(sync_log, "completed", total_synced)
            logger.info(f"Cards sync complete: {total_synced} records.")
        except Exception as exc:
            await self._finish_sync_log(sync_log, "failed", error=str(exc))
            logger.exception("Cards sync failed.")
            raise
        return total_synced

    async def _upsert_cards_batch(self, session: AsyncSession, batch: list[dict]) -> None:
        """UPSERT a batch of cards and their set_links in a single transaction."""
        # 1. Upsert master_cards
        card_upsert = text("""
            INSERT INTO master_cards (
                id, name, card_type, frame_type, description,
                atk, "def", level, race, attribute,
                link_val, scale, archetype,
                image_url, image_url_small,
                is_banned_tcg, is_banned_ocg,
                source_updated_at
            ) VALUES (
                :id, :name, :card_type, :frame_type, :description,
                :atk, :def_, :level, :race, :attribute,
                :link_val, :scale, :archetype,
                :image_url, :image_url_small,
                :is_banned_tcg, :is_banned_ocg,
                NOW()
            )
            ON CONFLICT (id) DO UPDATE SET
                name            = EXCLUDED.name,
                card_type       = EXCLUDED.card_type,
                frame_type      = EXCLUDED.frame_type,
                description     = EXCLUDED.description,
                atk             = EXCLUDED.atk,
                "def"           = EXCLUDED."def",
                level           = EXCLUDED.level,
                race            = EXCLUDED.race,
                attribute       = EXCLUDED.attribute,
                link_val        = EXCLUDED.link_val,
                scale           = EXCLUDED.scale,
                archetype       = EXCLUDED.archetype,
                image_url       = EXCLUDED.image_url,
                image_url_small = EXCLUDED.image_url_small,
                is_banned_tcg   = EXCLUDED.is_banned_tcg,
                is_banned_ocg   = EXCLUDED.is_banned_ocg,
                source_updated_at = NOW()
        """)

        card_params = []
        link_params = []  # for card_sets_link

        for card in batch:
            # Extract ban list info from misc field
            misc = card.get("misc_info", [{}])[0] if card.get("misc_info") else {}
            ban_tcg = card.get("banlist_info", {}).get("ban_tcg")
            ban_ocg = card.get("banlist_info", {}).get("ban_ocg")

            card_params.append({
                "id":           card["id"],
                "name":         card["name"],
                "card_type":    card.get("type", ""),
                "frame_type":   card.get("frameType"),
                "description":  card.get("desc"),
                "atk":          card.get("atk"),
                "def_":         card.get("def"),
                "level":        card.get("level"),
                "race":         card.get("race"),
                "attribute":    card.get("attribute"),
                "link_val":     card.get("linkval"),
                "scale":        card.get("scale"),
                "archetype":    card.get("archetype"),
                "image_url":    card.get("card_images", [{}])[0].get("image_url") if card.get("card_images") else None,
                "image_url_small": card.get("card_images", [{}])[0].get("image_url_small") if card.get("card_images") else None,
                "is_banned_tcg": ban_tcg,
                "is_banned_ocg": ban_ocg,
            })

            # Collect set links for this card
            for cs in card.get("card_sets", []):
                link_params.append({
                    "card_id":    card["id"],
                    "set_code_prefix": cs.get("set_code", "").split("-")[0].upper() if "-" in cs.get("set_code", "") else cs.get("set_code", "").upper(),
                    "full_set_code": cs.get("set_code", "").upper(),
                    "rarity":     cs.get("set_rarity", "Common"),
                    "rarity_code":cs.get("set_rarity_code"),
                    "price_usd":  _parse_price(cs.get("set_price")),
                })

        if card_params:
            await session.execute(card_upsert, card_params)

        # 2. Upsert card_sets_link — needs the set_id from master_sets
        if link_params:
            await self._upsert_card_set_links(session, link_params)

    async def _upsert_card_set_links(self, session: AsyncSession, link_params: list[dict]) -> None:
        """
        Upsert card_sets_link rows.
        Resolves set_code prefix → set_id via a subquery to avoid N+1 lookups.
        """
        link_upsert = text("""
            INSERT INTO card_sets_link (card_id, set_id, set_code, rarity, rarity_code, price_usd, price_updated_at)
            SELECT
                :card_id,
                ms.id,
                :full_set_code,
                :rarity,
                :rarity_code,
                :price_usd,
                NOW()
            FROM master_sets ms
            WHERE ms.set_code = :set_code_prefix
            ON CONFLICT (card_id, set_id, rarity) DO UPDATE SET
                set_code        = EXCLUDED.set_code,
                rarity_code     = EXCLUDED.rarity_code,
                price_usd       = EXCLUDED.price_usd,
                price_updated_at = NOW()
        """)
        await session.execute(link_upsert, link_params)

    # ── Audit Logging ─────────────────────────────────────────────────────────

    async def _start_sync_log(self, sync_type: str) -> SyncMetadata:
        async with AsyncSessionLocal() as session:
            log = SyncMetadata(sync_type=sync_type, status="running")
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
            # Reload the row to avoid detached instance issues
            db_log = await session.get(SyncMetadata, log.id)
            if db_log:
                db_log.status = status
                db_log.completed_at = datetime.now(UTC)
                db_log.records_synced = records
                db_log.error_message = error
                await session.commit()


def _parse_price(raw: str | None) -> float | None:
    """Parse price strings like '$0.02' or '0.02' to float. Returns None on failure."""
    if not raw:
        return None
    try:
        return float(raw.replace("$", "").strip())
    except ValueError:
        return None
