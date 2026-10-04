"""
app/api/routers/sets.py
------------------------
Card set (expansion) endpoints.
GET /sets/{set_code}/cards is useful for the "Complete a Set" feature
and the "missing cards" calculation.
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.orm import selectinload

from app.api.deps import CurrentUser, DB
from app.core.rate_limiter import RateLimitDefault
from app.models.card_sets_link import CardSetsLink
from app.models.master_card import MasterCard
from app.models.master_set import MasterSet
from app.models.user_inventory import UserInventory

router = APIRouter(prefix="/sets", tags=["Sets"])


# ── Schemas ───────────────────────────────────────────────────────────────────

class SetSummary(BaseModel):
    id: int
    set_name: str
    set_code: str
    set_type: str | None
    num_of_cards: int | None
    tcg_date: str | None
    set_image_url: str | None

    model_config = {"from_attributes": True}


class SetCardResponse(BaseModel):
    card_id: int
    name: str
    card_type: str
    image_url_small: str | None
    set_code: str
    rarity: str
    rarity_code: str | None
    price_usd: float | None
    owned_quantity: int  # 0 if user doesn't own it (for "missing" highlight)


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get(
    "",
    response_model=list[SetSummary],
    dependencies=[Depends(RateLimitDefault)],
)
async def list_sets(
    _: CurrentUser,
    db: DB,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=50, ge=1, le=200),
    q: str | None = Query(default=None, description="Search by name"),
) -> list[SetSummary]:
    """List all Yu-Gi-Oh! expansion sets, optionally filtered by name."""
    query = select(MasterSet).order_by(MasterSet.tcg_date.desc().nullslast())

    if q:
        query = query.where(MasterSet.set_name.ilike(f"%{q}%"))

    query = query.offset((page - 1) * limit).limit(limit)
    result = await db.execute(query)
    sets = result.scalars().all()
    return [
        SetSummary(
            id=s.id,
            set_name=s.set_name,
            set_code=s.set_code,
            set_type=s.set_type,
            num_of_cards=s.num_of_cards,
            tcg_date=str(s.tcg_date) if s.tcg_date else None,
            set_image_url=s.set_image_url,
        )
        for s in sets
    ]


@router.get(
    "/{set_code}",
    response_model=SetSummary,
    dependencies=[Depends(RateLimitDefault)],
)
async def get_set_detail(
    set_code: str,
    _: CurrentUser,
    db: DB,
) -> SetSummary:
    """Get details of a specific set by its code (e.g. 'DUSA')."""
    code = set_code.strip().upper()
    result = await db.execute(select(MasterSet).where(MasterSet.set_code == code))
    s = result.scalar_one_or_none()
    if not s:
        raise HTTPException(404, f"Set '{code}' not found.")
    return SetSummary(
        id=s.id,
        set_name=s.set_name,
        set_code=s.set_code,
        set_type=s.set_type,
        num_of_cards=s.num_of_cards,
        tcg_date=str(s.tcg_date) if s.tcg_date else None,
        set_image_url=s.set_image_url,
    )


@router.get(
    "/{set_code}/cards",
    response_model=list[SetCardResponse],
    dependencies=[Depends(RateLimitDefault)],
)
async def get_set_cards(
    set_code: str,
    current_user: CurrentUser,
    db: DB,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=100, ge=1, le=200),
    missing_only: bool = Query(default=False, description="Only show cards not owned"),
) -> list[SetCardResponse]:
    """
    List all cards in a set, annotated with how many copies the user owns.
    Use missing_only=true to see only cards not in their collection.
    Perfect for the 'Complete This Set' feature.
    """
    code = set_code.strip().upper()

    # Verify set exists
    set_result = await db.execute(
        select(MasterSet.id).where(MasterSet.set_code == code)
    )
    set_id = set_result.scalar_one_or_none()
    if not set_id:
        raise HTTPException(404, f"Set '{code}' not found.")

    # Get all cards in this set with their user inventory quantities
    links_result = await db.execute(
        select(CardSetsLink)
        .where(CardSetsLink.set_id == set_id)
        .options(selectinload(CardSetsLink.card))
        .order_by(CardSetsLink.set_code)
        .offset((page - 1) * limit)
        .limit(limit)
    )
    links = links_result.scalars().all()

    if not links:
        return []

    # Bulk-fetch owned quantities for this user in one query
    link_ids = [l.id for l in links]
    inv_result = await db.execute(
        select(
            UserInventory.card_sets_link_id,
            func.sum(UserInventory.quantity).label("total_qty"),
        )
        .where(
            UserInventory.user_id == current_user.id,
            UserInventory.card_sets_link_id.in_(link_ids),
        )
        .group_by(UserInventory.card_sets_link_id)
    )
    owned_map: dict[int, int] = {row[0]: int(row[1]) for row in inv_result.fetchall()}

    result = []
    for link in links:
        owned_qty = owned_map.get(link.id, 0)
        if missing_only and owned_qty > 0:
            continue
        result.append(
            SetCardResponse(
                card_id=link.card.id,
                name=link.card.name,
                card_type=link.card.card_type,
                image_url_small=link.card.image_url_small,
                set_code=link.set_code,
                rarity=link.rarity,
                rarity_code=link.rarity_code,
                price_usd=float(link.price_usd) if link.price_usd else None,
                owned_quantity=owned_qty,
            )
        )
    return result
