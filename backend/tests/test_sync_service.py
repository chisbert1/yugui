"""
tests/test_sync_service.py
---------------------------
Unit tests for the sync service.
YGOPRODeck API calls are fully mocked — no real HTTP requests.
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch


# ── Fixtures ──────────────────────────────────────────────────────────────────

MOCK_SETS = [
    {"set_name": "Legend of Blue Eyes White Dragon", "set_code": "LOB", "set_type": "Core Set", "num_of_cards": 126, "tcg_date": "2002-03-08"},
    {"set_name": "Duelist Saga", "set_code": "DUSA", "set_type": "Booster Pack", "num_of_cards": 100, "tcg_date": "2017-03-31"},
]

MOCK_CARDS = [
    {
        "id": 46986414,
        "name": "Dark Magician",
        "type": "Normal Monster",
        "frameType": "normal",
        "desc": "The ultimate wizard in terms of attack and defense.",
        "atk": 2500,
        "def": 2100,
        "level": 7,
        "race": "Spellcaster",
        "attribute": "DARK",
        "archetype": "Dark Magician",
        "card_images": [{"image_url": "https://example.com/img.jpg", "image_url_small": "https://example.com/img_small.jpg"}],
        "card_sets": [
            {"set_name": "Duelist Saga", "set_code": "DUSA-EN001", "set_rarity": "Ultra Rare", "set_rarity_code": "UR", "set_price": "12.50"},
        ],
        "misc_info": [{}],
        "banlist_info": {},
    }
]


# ── Tests: YGOProDeckClient ───────────────────────────────────────────────────

class TestYGOProDeckClient:
    @pytest.mark.asyncio
    async def test_fetch_all_sets_returns_list(self):
        from app.services.ygoprodeck_client import YGOProDeckClient
        client = YGOProDeckClient()
        client._get = AsyncMock(return_value=MOCK_SETS)
        result = await client.fetch_all_sets()
        assert isinstance(result, list)
        assert len(result) == 2
        assert result[0]["set_code"] == "LOB"

    @pytest.mark.asyncio
    async def test_fetch_all_cards_extracts_data_key(self):
        from app.services.ygoprodeck_client import YGOProDeckClient
        client = YGOProDeckClient()
        client._get = AsyncMock(return_value={"data": MOCK_CARDS})
        result = await client.fetch_all_cards()
        assert len(result) == 1
        assert result[0]["name"] == "Dark Magician"

    @pytest.mark.asyncio
    async def test_throttle_enforces_delay(self):
        """Ensure at least 1 second delay between consecutive requests."""
        import time
        from app.services.ygoprodeck_client import YGOProDeckClient
        client = YGOProDeckClient()
        client._delay = 0.1  # Speed up for testing
        client._last_request_time = time.monotonic()

        start = time.monotonic()
        await client._throttle()
        elapsed = time.monotonic() - start
        assert elapsed >= 0.08  # Allow 20ms tolerance


# ── Tests: parse_price helper ─────────────────────────────────────────────────

class TestParsePriceHelper:
    def test_parses_dollar_sign_string(self):
        from app.services.sync_service import _parse_price
        assert _parse_price("$12.50") == 12.50

    def test_parses_plain_float_string(self):
        from app.services.sync_service import _parse_price
        assert _parse_price("0.02") == 0.02

    def test_returns_none_for_empty(self):
        from app.services.sync_service import _parse_price
        assert _parse_price(None) is None
        assert _parse_price("") is None

    def test_returns_none_for_invalid(self):
        from app.services.sync_service import _parse_price
        assert _parse_price("N/A") is None


# ── Tests: SQLiteExporter ─────────────────────────────────────────────────────

class TestSQLiteExporter:
    def test_compute_sha256_is_deterministic(self, tmp_path):
        from app.services.sqlite_exporter import SQLiteExporter
        test_file = tmp_path / "test.db"
        test_file.write_bytes(b"hello world")
        hash1 = SQLiteExporter._compute_sha256(test_file)
        hash2 = SQLiteExporter._compute_sha256(test_file)
        assert hash1 == hash2
        assert len(hash1) == 64  # SHA-256 hex string

    def test_get_latest_info_returns_none_when_no_export(self, tmp_path, monkeypatch):
        from app.services import sqlite_exporter
        monkeypatch.setattr(sqlite_exporter, "EXPORT_DIR", tmp_path)
        result = sqlite_exporter.SQLiteExporter.get_latest_info()
        assert result is None
