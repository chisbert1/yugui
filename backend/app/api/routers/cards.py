"""
app/api/routers/cards.py
------------------------
Card lookup endpoints — the most performance-critical router.
GET /cards/set/{set_code} is called directly after every OCR scan.
"""

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.api.deps import CurrentUser, DB
from app.models.card_sets_link import CardSetsLink
from app.models.master_card import MasterCard
from app.models.master_set import MasterSet

router = APIRouter(prefix="/cards", tags=["Cards"])


# ── Schemas ───────────────────────────────────────────────────────────────────

class CardSetResponse(BaseModel):
    card_id: int
    name: str
    card_type: str
    frame_type: str | None
    image_url_small: str | None
    set_code: str
    rarity: str
    rarity_code: str | None
    price_usd: float | None
    set_name: str
    set_date: str | None

    model_config = {"from_attributes": True}


class CardDetailResponse(BaseModel):
    id: int
    name: str
    card_type: str
    frame_type: str | None
    description: str | None
    atk: int | None
    def_: int | None
    level: int | None
    race: str | None
    attribute: str | None
    archetype: str | None
    image_url: str | None
    image_url_small: str | None
    is_banned_tcg: str | None
    is_banned_ocg: str | None

    model_config = {"from_attributes": True}


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/set/{set_code}", response_model=CardSetResponse)
async def get_card_by_set_code(
    set_code: str,
    _: CurrentUser,
    db: DB,
) -> CardSetResponse:
    """
    ⚡ Critical endpoint — called immediately after every OCR scan.
    Looks up a card by its full print code (e.g. 'DUSA-EN001').
    O(log n) via the idx_csl_set_code index.
    """
    code = set_code.strip().upper()

    result = await db.execute(
        select(CardSetsLink)
        .where(CardSetsLink.set_code == code)
        .options(
            selectinload(CardSetsLink.card),
            selectinload(CardSetsLink.set_),
        )
        .limit(1)
    )
    link = result.scalar_one_or_none()

    if not link:
        raise HTTPException(status_code=404, detail=f"No card found with set code '{code}'.")

    return CardSetResponse(
        card_id=link.card.id,
        name=link.card.name,
        card_type=link.card.card_type,
        frame_type=link.card.frame_type,
        image_url_small=link.card.image_url_small,
        set_code=link.set_code,
        rarity=link.rarity,
        rarity_code=link.rarity_code,
        price_usd=float(link.price_usd) if link.price_usd else None,
        set_name=link.set_.set_name,
        set_date=str(link.set_.tcg_date) if link.set_.tcg_date else None,
    )


@router.get("/search", response_model=list[CardDetailResponse])
async def search_cards(
    q: str = Query(min_length=2, max_length=100),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
    _: CurrentUser = None,
    db: DB = None,
) -> list[CardDetailResponse]:
    """Search cards by name (partial match, case-insensitive). Paginated."""
    offset = (page - 1) * limit
    result = await db.execute(
        select(MasterCard)
        .where(MasterCard.name.ilike(f"%{q}%"))
        .order_by(MasterCard.name)
        .offset(offset)
        .limit(limit)
    )
    cards = result.scalars().all()
    return [CardDetailResponse.model_validate(c) for c in cards]


@router.get("/{card_id}", response_model=CardDetailResponse)
async def get_card_detail(
    card_id: int,
    _: CurrentUser,
    db: DB,
) -> CardDetailResponse:
    """Get full details of a single card by its YGOPRODeck ID."""
    card = await db.get(MasterCard, card_id)
    if not card:
        raise HTTPException(status_code=404, detail="Card not found.")
    return CardDetailResponse.model_validate(card)


@router.get("/{card_id}/sets", response_model=list[CardSetResponse])
async def get_card_printings(
    card_id: int,
    _: CurrentUser,
    db: DB,
) -> list[CardSetResponse]:
    """List all print editions of a card across different sets."""
    result = await db.execute(
        select(CardSetsLink)
        .where(CardSetsLink.card_id == card_id)
        .options(
            selectinload(CardSetsLink.card),
            selectinload(CardSetsLink.set_),
        )
        .order_by(CardSetsLink.set_id)
    )
    links = result.scalars().all()
    if not links:
        raise HTTPException(status_code=404, detail="Card not found or has no set links.")

    return [
        CardSetResponse(
            card_id=l.card.id,
            name=l.card.name,
            card_type=l.card.card_type,
            frame_type=l.card.frame_type,
            image_url_small=l.card.image_url_small,
            set_code=l.set_code,
            rarity=l.rarity,
            rarity_code=l.rarity_code,
            price_usd=float(l.price_usd) if l.price_usd else None,
            set_name=l.set_.set_name,
            set_date=str(l.set_.tcg_date) if l.set_.tcg_date else None,
        )
        for l in links
    ]
