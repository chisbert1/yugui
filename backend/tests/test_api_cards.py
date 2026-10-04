"""
tests/test_api_cards.py
------------------------
Integration tests for the /cards endpoints.
Covers the critical OCR lookup path: GET /cards/set/{set_code}.
"""

import pytest


class TestOCRLookup:
    """Tests for GET /cards/set/{set_code} — the most critical endpoint."""

    @pytest.mark.asyncio
    async def test_lookup_by_set_code_returns_card(self, async_client, test_user, seeded_card):
        resp = await async_client.get(
            "/api/v1/cards/set/DUSA-EN001",
            headers=test_user["headers"],
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["name"] == "Dark Magician"
        assert data["set_code"] == "DUSA-EN001"
        assert data["rarity"] == "Ultra Rare"
        assert data["set_name"] == "Duelist Saga"
        assert data["price_usd"] == 12.5

    @pytest.mark.asyncio
    async def test_lookup_case_insensitive(self, async_client, test_user, seeded_card):
        """OCR may return lowercase — endpoint should normalize."""
        resp = await async_client.get(
            "/api/v1/cards/set/dusa-en001",
            headers=test_user["headers"],
        )
        assert resp.status_code == 200
        assert resp.json()["name"] == "Dark Magician"

    @pytest.mark.asyncio
    async def test_lookup_unknown_code_returns_404(self, async_client, test_user, seeded_card):
        resp = await async_client.get(
            "/api/v1/cards/set/ZZZZZ-EN999",
            headers=test_user["headers"],
        )
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_lookup_requires_auth(self, async_client, seeded_card):
        resp = await async_client.get("/api/v1/cards/set/DUSA-EN001")
        assert resp.status_code == 403  # No Bearer token


class TestCardSearch:
    @pytest.mark.asyncio
    async def test_search_returns_results(self, async_client, test_user, seeded_card):
        resp = await async_client.get(
            "/api/v1/cards/search?q=dark",
            headers=test_user["headers"],
        )
        assert resp.status_code == 200
        results = resp.json()
        assert any(c["name"] == "Dark Magician" for c in results)

    @pytest.mark.asyncio
    async def test_search_too_short_returns_422(self, async_client, test_user):
        resp = await async_client.get(
            "/api/v1/cards/search?q=a",  # min_length=2
            headers=test_user["headers"],
        )
        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_search_no_results_returns_empty_list(self, async_client, test_user):
        resp = await async_client.get(
            "/api/v1/cards/search?q=xkjhqwerty99",
            headers=test_user["headers"],
        )
        assert resp.status_code == 200
        assert resp.json() == []


class TestCardDetail:
    @pytest.mark.asyncio
    async def test_get_card_by_id(self, async_client, test_user, seeded_card):
        resp = await async_client.get(
            "/api/v1/cards/46986414",
            headers=test_user["headers"],
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["name"] == "Dark Magician"
        assert data["atk"] == 2500

    @pytest.mark.asyncio
    async def test_get_card_printings(self, async_client, test_user, seeded_card):
        resp = await async_client.get(
            "/api/v1/cards/46986414/sets",
            headers=test_user["headers"],
        )
        assert resp.status_code == 200
        printings = resp.json()
        assert len(printings) >= 1
        assert printings[0]["set_code"] == "DUSA-EN001"
