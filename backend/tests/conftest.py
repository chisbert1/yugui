"""
tests/conftest.py
-----------------
Shared pytest fixtures for integration tests.
Uses an in-memory SQLite database (via aiosqlite) so no PostgreSQL needed.
Fixtures:
  - async_client: TestClient with a fully wired FastAPI app
  - db_session:   isolated async DB session per test
  - test_user:    a pre-seeded User + valid JWT
"""

import asyncio
import uuid
from typing import AsyncGenerator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.database import Base, get_db
from app.core.security import create_access_token, hash_password
from app.main import create_app
from app.models.master_card import MasterCard
from app.models.master_set import MasterSet
from app.models.card_sets_link import CardSetsLink
from app.models.user import User

# ── In-memory SQLite engine ───────────────────────────────────────────────────
TEST_DB_URL = "sqlite+aiosqlite:///:memory:"

test_engine = create_async_engine(
    TEST_DB_URL,
    connect_args={"check_same_thread": False},
)
TestSessionLocal = async_sessionmaker(
    test_engine, class_=AsyncSession, expire_on_commit=False
)


@pytest_asyncio.fixture(scope="session", autouse=True)
async def create_tables():
    """Create all tables once per test session."""
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Provide a transactional session that rolls back after each test."""
    async with TestSessionLocal() as session:
        yield session
        await session.rollback()


@pytest_asyncio.fixture
async def async_client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """
    Provide a fully wired async HTTP client.
    The DB dependency is overridden to use the test session.
    Rate limiting is disabled (no Redis in tests).
    """
    app = create_app()

    # Override DB dependency
    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db

    # Disable rate limiter for tests (monkey-patch FastAPILimiter)
    from unittest.mock import AsyncMock, patch
    with patch("fastapi_limiter.FastAPILimiter.init", new_callable=AsyncMock):
        with patch("fastapi_limiter.depends.RateLimiter.__call__", new_callable=AsyncMock):
            async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://test"
            ) as client:
                yield client


@pytest_asyncio.fixture
async def test_user(db_session: AsyncSession) -> dict:
    """Create a test user and return user data + valid JWT."""
    user = User(
        id=uuid.uuid4(),
        username="testuser",
        email="test@example.com",
        password_hash=hash_password("testpassword123"),
        is_active=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    token = create_access_token(str(user.id))
    return {
        "user": user,
        "token": token,
        "headers": {"Authorization": f"Bearer {token}"},
    }


@pytest_asyncio.fixture
async def seeded_card(db_session: AsyncSession) -> dict:
    """
    Seed a complete card + set + link for endpoint testing.
    Represents: Dark Magician in Duelist Saga (DUSA-EN001).
    """
    ms = MasterSet(
        set_name="Duelist Saga",
        set_code="DUSA",
        set_type="Booster Pack",
        num_of_cards=100,
    )
    db_session.add(ms)
    await db_session.flush()

    mc = MasterCard(
        id=46986414,
        name="Dark Magician",
        card_type="Normal Monster",
        frame_type="normal",
        description="The ultimate wizard.",
        atk=2500,
        def_=2100,
        level=7,
        race="Spellcaster",
        attribute="DARK",
        archetype="Dark Magician",
        image_url="https://example.com/dm.jpg",
        image_url_small="https://example.com/dm_small.jpg",
    )
    db_session.add(mc)
    await db_session.flush()

    csl = CardSetsLink(
        card_id=mc.id,
        set_id=ms.id,
        set_code="DUSA-EN001",
        rarity="Ultra Rare",
        rarity_code="UR",
        price_usd=12.5,
    )
    db_session.add(csl)
    await db_session.commit()
    await db_session.refresh(csl)

    return {"set": ms, "card": mc, "link": csl}
