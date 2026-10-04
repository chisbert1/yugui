"""
tests/test_api_auth.py
-----------------------
Integration tests for the /auth endpoints.
"""

import pytest


class TestRegister:
    @pytest.mark.asyncio
    async def test_register_success(self, async_client):
        resp = await async_client.post("/api/v1/auth/register", json={
            "username": "newuser",
            "email": "newuser@example.com",
            "password": "SecurePassword1",
        })
        assert resp.status_code == 201
        data = resp.json()
        assert data["username"] == "newuser"
        assert data["email"] == "newuser@example.com"
        assert "id" in data

    @pytest.mark.asyncio
    async def test_register_duplicate_email_returns_409(self, async_client, test_user):
        resp = await async_client.post("/api/v1/auth/register", json={
            "username": "differentname",
            "email": "test@example.com",  # same as test_user
            "password": "SecurePassword1",
        })
        assert resp.status_code == 409

    @pytest.mark.asyncio
    async def test_register_weak_password_rejected(self, async_client):
        resp = await async_client.post("/api/v1/auth/register", json={
            "username": "weakpwduser",
            "email": "weak@example.com",
            "password": "123",  # too short
        })
        assert resp.status_code == 422  # Pydantic validation


class TestLogin:
    @pytest.mark.asyncio
    async def test_login_success_returns_jwt(self, async_client, test_user):
        resp = await async_client.post("/api/v1/auth/login", json={
            "email": "test@example.com",
            "password": "testpassword123",
        })
        assert resp.status_code == 200
        data = resp.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"
        assert data["expires_in"] > 0

    @pytest.mark.asyncio
    async def test_login_wrong_password_returns_401(self, async_client, test_user):
        resp = await async_client.post("/api/v1/auth/login", json={
            "email": "test@example.com",
            "password": "wrongpassword",
        })
        assert resp.status_code == 401

    @pytest.mark.asyncio
    async def test_login_unknown_email_returns_401(self, async_client):
        resp = await async_client.post("/api/v1/auth/login", json={
            "email": "nobody@example.com",
            "password": "anypassword",
        })
        assert resp.status_code == 401


class TestRefreshToken:
    @pytest.mark.asyncio
    async def test_refresh_returns_new_access_token(self, async_client, test_user):
        from app.core.security import create_refresh_token
        refresh = create_refresh_token(str(test_user["user"].id))
        resp = await async_client.post("/api/v1/auth/refresh", json={
            "refresh_token": refresh,
        })
        assert resp.status_code == 200
        assert "access_token" in resp.json()

    @pytest.mark.asyncio
    async def test_refresh_with_access_token_returns_401(self, async_client, test_user):
        resp = await async_client.post("/api/v1/auth/refresh", json={
            "refresh_token": test_user["token"],  # access token, not refresh
        })
        assert resp.status_code == 401
