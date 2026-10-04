"""
tests/test_api_inventory.py
----------------------------
Integration tests for the /inventory endpoints.
Critical: verifies the atomic UPSERT behaviour on duplicate scans.
"""

import pytest


class TestAddCard:
    @pytest.mark.asyncio
    async def test_add_card_returns_201(self, async_client, test_user, seeded_card):
        resp = await async_client.post(
            "/api/v1/inventory/add",
            headers=test_user["headers"],
            json={
                "set_code": "DUSA-EN001",
                "edition": "1st Edition",
                "condition": "Near Mint",
                "quantity": 1,
            },
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["card_name"] == "Dark Magician"
        assert data["quantity_added"] == 1

    @pytest.mark.asyncio
    async def test_add_same_card_twice_increments_quantity(
        self, async_client, test_user, seeded_card
    ):
        """
        CRITICAL: scanning the same card twice must NOT create a duplicate row.
        The quantity should increment atomically.
        """
        payload = {
            "set_code": "DUSA-EN001",
            "edition": "Unlimited",
            "condition": "Near Mint",
            "quantity": 1,
        }
        # First scan
        await async_client.post("/api/v1/inventory/add", headers=test_user["headers"], json=payload)
        # Second scan (same card)
        await async_client.post("/api/v1/inventory/add", headers=test_user["headers"], json=payload)

        # Check inventory — should be exactly 1 row with quantity=2
        resp = await async_client.get("/api/v1/inventory/me", headers=test_user["headers"])
        inventory = resp.json()
        same_cards = [
            i for i in inventory
            if i["set_code"] == "DUSA-EN001"
            and i["edition"] == "Unlimited"
            and i["condition"] == "Near Mint"
        ]
        assert len(same_cards) == 1
        assert same_cards[0]["quantity"] == 2

    @pytest.mark.asyncio
    async def test_different_editions_are_separate_rows(
        self, async_client, test_user, seeded_card
    ):
        """1st Edition and Unlimited are different collector items — must be separate rows."""
        await async_client.post(
            "/api/v1/inventory/add",
            headers=test_user["headers"],
            json={"set_code": "DUSA-EN001", "edition": "1st Edition", "condition": "Mint", "quantity": 1},
        )
        await async_client.post(
            "/api/v1/inventory/add",
            headers=test_user["headers"],
            json={"set_code": "DUSA-EN001", "edition": "Unlimited", "condition": "Mint", "quantity": 1},
        )
        resp = await async_client.get("/api/v1/inventory/me", headers=test_user["headers"])
        inventory = resp.json()
        dusa_entries = [i for i in inventory if i["set_code"] == "DUSA-EN001"]
        assert len(dusa_entries) >= 2

    @pytest.mark.asyncio
    async def test_add_unknown_set_code_returns_404(self, async_client, test_user):
        resp = await async_client.post(
            "/api/v1/inventory/add",
            headers=test_user["headers"],
            json={"set_code": "ZZZZZ-EN999", "edition": "Unlimited", "condition": "Mint"},
        )
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_add_invalid_edition_returns_400(self, async_client, test_user, seeded_card):
        resp = await async_client.post(
            "/api/v1/inventory/add",
            headers=test_user["headers"],
            json={"set_code": "DUSA-EN001", "edition": "Fake Edition", "condition": "Mint"},
        )
        assert resp.status_code == 400


class TestGetInventory:
    @pytest.mark.asyncio
    async def test_get_inventory_returns_list(self, async_client, test_user, seeded_card):
        # Add a card first
        await async_client.post(
            "/api/v1/inventory/add",
            headers=test_user["headers"],
            json={"set_code": "DUSA-EN001", "edition": "Unlimited", "condition": "Near Mint"},
        )
        resp = await async_client.get("/api/v1/inventory/me", headers=test_user["headers"])
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    @pytest.mark.asyncio
    async def test_get_inventory_stats(self, async_client, test_user, seeded_card):
        await async_client.post(
            "/api/v1/inventory/add",
            headers=test_user["headers"],
            json={"set_code": "DUSA-EN001", "edition": "Unlimited", "condition": "Near Mint", "quantity": 3},
        )
        resp = await async_client.get("/api/v1/inventory/me/stats", headers=test_user["headers"])
        assert resp.status_code == 200
        data = resp.json()
        assert data["total_cards"] >= 3
        assert data["unique_entries"] >= 1

    @pytest.mark.asyncio
    async def test_wishlist_filter(self, async_client, test_user, seeded_card):
        await async_client.post(
            "/api/v1/inventory/add",
            headers=test_user["headers"],
            json={
                "set_code": "DUSA-EN001",
                "edition": "Limited",
                "condition": "Mint",
                "is_wishlist": True,
            },
        )
        resp = await async_client.get("/api/v1/inventory/me/wishlist", headers=test_user["headers"])
        assert resp.status_code == 200
        items = resp.json()
        assert all(i.get("is_wishlist") for i in items)


class TestUpdateDeleteInventory:
    @pytest.mark.asyncio
    async def test_update_quantity(self, async_client, test_user, seeded_card):
        add_resp = await async_client.post(
            "/api/v1/inventory/add",
            headers=test_user["headers"],
            json={"set_code": "DUSA-EN001", "edition": "Unlimited", "condition": "Damaged", "quantity": 1},
        )
        assert add_resp.status_code == 201

        inv_resp = await async_client.get("/api/v1/inventory/me", headers=test_user["headers"])
        item_id = inv_resp.json()[-1]["id"]

        update_resp = await async_client.put(
            f"/api/v1/inventory/{item_id}",
            headers=test_user["headers"],
            json={"quantity": 5},
        )
        assert update_resp.status_code == 200

    @pytest.mark.asyncio
    async def test_delete_inventory_item(self, async_client, test_user, seeded_card):
        await async_client.post(
            "/api/v1/inventory/add",
            headers=test_user["headers"],
            json={"set_code": "DUSA-EN001", "edition": "1st Edition", "condition": "Damaged"},
        )
        inv_resp = await async_client.get("/api/v1/inventory/me", headers=test_user["headers"])
        item_id = inv_resp.json()[-1]["id"]

        del_resp = await async_client.delete(
            f"/api/v1/inventory/{item_id}",
            headers=test_user["headers"],
        )
        assert del_resp.status_code == 204
