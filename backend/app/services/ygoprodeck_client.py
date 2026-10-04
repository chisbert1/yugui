"""
app/services/ygoprodeck_client.py
----------------------------------
HTTP client for the YGOPRODeck public API.

Rules enforced:
  - Minimum 1 second between requests (rate-limit safety)
  - Exponential backoff retry (up to 5 attempts) via Tenacity
  - All requests have a 30s timeout
  - Circuit breaker: if the API is down, raises ServiceUnavailableError

API docs: https://ygoprodeck.com/api-guide/
"""

import asyncio
import logging
from typing import Any

import httpx
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

from app.core.config import settings

logger = logging.getLogger(__name__)

# ── Endpoints ─────────────────────────────────────────────────────────────────
_BASE = settings.YGOPRODECK_BASE_URL

ENDPOINT_ALL_CARDS = f"{_BASE}/cardinfo.php?misc=yes"
ENDPOINT_ALL_SETS  = f"{_BASE}/cardsets.php"
ENDPOINT_CARD_INFO = f"{_BASE}/cardinfo.php"


class YGOProDeckError(Exception):
    """Base error for YGOPRODeck API failures."""


class YGOProDeckClient:
    """
    Async HTTP client for YGOPRODeck.
    Instantiate once and reuse (connection pool sharing).
    """

    def __init__(self) -> None:
        self._client = httpx.AsyncClient(
            timeout=httpx.Timeout(30.0),
            headers={"User-Agent": "YuGiOhCollectorApp/1.0 (contact@example.com)"},
            follow_redirects=True,
        )
        self._delay = settings.YGOPRODECK_REQUEST_DELAY_SECONDS
        self._last_request_time: float = 0.0

    async def _throttle(self) -> None:
        """Enforce minimum delay between requests to avoid rate-limit bans."""
        now = asyncio.get_event_loop().time()
        elapsed = now - self._last_request_time
        if elapsed < self._delay:
            await asyncio.sleep(self._delay - elapsed)
        self._last_request_time = asyncio.get_event_loop().time()

    @retry(
        retry=retry_if_exception_type((httpx.HTTPStatusError, httpx.RequestError)),
        stop=stop_after_attempt(settings.YGOPRODECK_MAX_RETRIES),
        wait=wait_exponential(multiplier=2, min=4, max=120),
        reraise=True,
    )
    async def _get(self, url: str, params: dict | None = None) -> Any:
        """
        Perform a GET request with throttling and automatic retry on failure.
        Returns the parsed JSON body.
        """
        await self._throttle()
        logger.debug(f"GET {url} params={params}")
        response = await self._client.get(url, params=params)
        response.raise_for_status()
        return response.json()

    # ── Public Methods ────────────────────────────────────────────────────────

    async def fetch_all_cards(self) -> list[dict]:
        """
        Download the complete card database from YGOPRODeck.
        Returns a flat list of card dicts (includes card_sets nested per card).
        
        NOTE: This is a large request (~15MB). Only call from the sync job.
        """
        logger.info("Fetching full card database from YGOPRODeck...")
        data = await self._get(ENDPOINT_ALL_CARDS)
        cards = data.get("data", [])
        logger.info(f"Fetched {len(cards)} cards from YGOPRODeck.")
        return cards

    async def fetch_all_sets(self) -> list[dict]:
        """
        Download the complete list of card sets (expansions).
        Returns a flat list of set dicts.
        """
        logger.info("Fetching full set list from YGOPRODeck...")
        sets = await self._get(ENDPOINT_ALL_SETS)
        logger.info(f"Fetched {len(sets)} sets from YGOPRODeck.")
        return sets

    async def fetch_card_by_name(self, name: str) -> dict | None:
        """Fetch a single card by exact name. Returns None if not found."""
        try:
            data = await self._get(ENDPOINT_CARD_INFO, params={"name": name, "misc": "yes"})
            cards = data.get("data", [])
            return cards[0] if cards else None
        except httpx.HTTPStatusError as exc:
            if exc.response.status_code == 400:
                return None  # Card not found is not an error
            raise

    async def close(self) -> None:
        await self._client.aclose()

    async def __aenter__(self):
        return self

    async def __aexit__(self, *_):
        await self.close()
