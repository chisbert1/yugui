"""
app/api/routers/inventory.py
-----------------------------
User inventory (collection) CRUD endpoints.
POST /add uses atomic UPSERT to handle duplicate scans safely.
"""

import uuid

from fastapi import APIRouter, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import func, select, text
from sqlalchemy.orm import selectinload

from app.api.deps import CurrentUser, DB
from app.models.card_sets_link import CardSetsLink
from app.models.user_inventory import UserInventory

router = APIRouter(prefix="/inventory", tags=["Inventory"])

# ── Enums (as string literals for simplicity) ─────────────────────────────────
VALID_EDITIONS   = {"1st Edition", "Unlimited", "Limited"}
VALID_CONDITIONS = {"Mint", "Near Mint", "Lightly Played", "Moderately Played", "Heavily Played", "Damaged"}


# ── Schemas ───────────────────────────────────────────────────────────────────

class AddCardRequest(BaseModel):
    set_code: str = Field(description="Full print code, e.g. 'DUSA-EN001'")
    edition: str = Field(default="Unlimited")
    condition: str = Field(default="Near Mint")
    quantity: int = Field(default=1, ge=1, le=999)
    is_foil: bool = False
    acquired_price: float | None = None
    is_for_trade: bool = False
    is_wishlist: bool = False
    notes: str | None = None


class UpdateCardRequest(BaseModel):
    quantity: int | None = Field(default=None, ge=1, le=999)
    condition: str | None = None
    acquired_price: float | None = None
    is_for_trade: bool | None = None
    is_wishlist: bool | None = None
    notes: str | None = None


class InventoryItemResponse(BaseModel):
    id: str
    card_id: int
    card_name: str
    set_code: str
    rarity: str
    edition: str
    condition: str
    quantity: int
    is_foil: bool
    is_for_trade: bool
    is_wishlist: bool
    acquired_price: float | None
    price_usd: float | None
    notes: str | None
    added_at: str


# ── Helpers ───────────────────────────────────────────────────────────────────

def _item_to_response(item: UserInventory) -> InventoryItemResponse:
    link = item.card_set_link
    return InventoryItemResponse(
        id=str(item.id),
        card_id=link.card_id,
        card_name=link.card.name,
        set_code=link.set_code,
        rarity=link.rarity,
        edition=item.edition,
        condition=item.condition,
        quantity=item.quantity,
        is_foil=item.is_foil,
        is_for_trade=item.is_for_trade,
        is_wishlist=item.is_wishlist,
        acquired_price=float(item.acquired_price) if item.acquired_price else None,
        price_usd=float(link.price_usd) if link.price_usd else None,
        notes=item.notes,
        added_at=item.added_at.isoformat(),
    )


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/me", response_model=list[InventoryItemResponse])
async def get_my_inventory(
    current_user: CurrentUser,
    db: DB,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=50, ge=1, le=100),
) -> list[InventoryItemResponse]:
    """Retrieve the authenticated user's full card collection (paginated)."""
    offset = (page - 1) * limit
    result = await db.execute(
        select(UserInventory)
        .where(UserInventory.user_id == current_user.id)
        .options(
            selectinload(UserInventory.card_set_link).selectinload(CardSetsLink.card),
            selectinload(UserInventory.card_set_link).selectinload(CardSetsLink.set_),
        )
        .order_by(UserInventory.added_at.desc())
        .offset(offset)
        .limit(limit)
    )
    items = result.scalars().all()
    return [_item_to_response(i) for i in items]


@router.post("/add", status_code=status.HTTP_201_CREATED)
async def add_card(
    body: AddCardRequest,
    current_user: CurrentUser,
    db: DB,
) -> dict:
    """
    Add a card to the user's collection.
    If the same (card_print + edition + condition) already exists,
    the quantity is incremented atomically (safe for rapid/duplicate scans).
    """
    # Validate inputs
    if body.edition not in VALID_EDITIONS:
        raise HTTPException(400, f"Invalid edition. Must be one of: {VALID_EDITIONS}")
    if body.condition not in VALID_CONDITIONS:
        raise HTTPException(400, f"Invalid condition. Must be one of: {VALID_CONDITIONS}")

    # Look up the card_sets_link by set_code
    code = body.set_code.strip().upper()
    result = await db.execute(
        select(CardSetsLink)
        .where(CardSetsLink.set_code == code)
        .options(selectinload(CardSetsLink.card))
        .limit(1)
    )
    link = result.scalar_one_or_none()
    if not link:
        raise HTTPException(404, f"No card found with set code '{code}'.")

    # Atomic UPSERT: insert or increment quantity
    await db.execute(
        text("""
            INSERT INTO user_inventory
                (id, user_id, card_sets_link_id, edition, condition, quantity,
                 is_foil, acquired_price, is_for_trade, is_wishlist, notes)
            VALUES
                (:id, :user_id, :link_id, :edition, :condition, :quantity,
                 :is_foil, :acquired_price, :is_for_trade, :is_wishlist, :notes)
            ON CONFLICT (user_id, card_sets_link_id, edition, condition)
            DO UPDATE SET
                quantity       = user_inventory.quantity + EXCLUDED.quantity,
                is_foil        = EXCLUDED.is_foil,
                acquired_price = COALESCE(EXCLUDED.acquired_price, user_inventory.acquired_price),
                is_for_trade   = EXCLUDED.is_for_trade,
                is_wishlist    = EXCLUDED.is_wishlist,
                notes          = COALESCE(EXCLUDED.notes, user_inventory.notes),
                updated_at     = CURRENT_TIMESTAMP
        """),
        {
            "id": uuid.uuid4(),
            "user_id": current_user.id,
            "link_id": link.id,
            "edition": body.edition,
            "condition": body.condition,
            "quantity": body.quantity,
            "is_foil": body.is_foil,
            "acquired_price": body.acquired_price,
            "is_for_trade": body.is_for_trade,
            "is_wishlist": body.is_wishlist,
            "notes": body.notes,
        },
    )
    await db.commit()

    return {
        "card_name": link.card.name,
        "set_code": link.set_code,
        "quantity_added": body.quantity,
        "message": "Card added to inventory.",
    }


@router.put("/{item_id}", response_model=dict)
async def update_inventory_item(
    item_id: str,
    body: UpdateCardRequest,
    current_user: CurrentUser,
    db: DB,
) -> dict:
    """Update an existing inventory entry (quantity, condition, flags, notes)."""
    result = await db.execute(
        select(UserInventory)
        .where(
            UserInventory.id == uuid.UUID(item_id),
            UserInventory.user_id == current_user.id,
        )
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(404, "Inventory item not found.")

    if body.quantity is not None:
        item.quantity = body.quantity
    if body.condition is not None:
        if body.condition not in VALID_CONDITIONS:
            raise HTTPException(400, "Invalid condition.")
        item.condition = body.condition
    if body.acquired_price is not None:
        item.acquired_price = body.acquired_price
    if body.is_for_trade is not None:
        item.is_for_trade = body.is_for_trade
    if body.is_wishlist is not None:
        item.is_wishlist = body.is_wishlist
    if body.notes is not None:
        item.notes = body.notes

    await db.commit()
    return {"message": "Updated.", "id": item_id}


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_inventory_item(
    item_id: str,
    current_user: CurrentUser,
    db: DB,
) -> None:
    """Remove a card from the user's collection."""
    result = await db.execute(
        select(UserInventory)
        .where(
            UserInventory.id == uuid.UUID(item_id),
            UserInventory.user_id == current_user.id,
        )
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(404, "Inventory item not found.")
    await db.delete(item)
    await db.commit()


@router.get("/me/stats", response_model=dict)
async def get_inventory_stats(current_user: CurrentUser, db: DB) -> dict:
    """Aggregate statistics: total cards, unique cards, estimated value."""
    result = await db.execute(
        select(
            func.count(UserInventory.id).label("unique_entries"),
            func.sum(UserInventory.quantity).label("total_cards"),
        ).where(UserInventory.user_id == current_user.id)
    )
    row = result.one()
    return {
        "unique_entries": row.unique_entries or 0,
        "total_cards": int(row.total_cards or 0),
    }


@router.get("/me/wishlist", response_model=list[InventoryItemResponse])
async def get_wishlist(current_user: CurrentUser, db: DB) -> list[InventoryItemResponse]:
    """Cards the user wants to acquire."""
    result = await db.execute(
        select(UserInventory)
        .where(
            UserInventory.user_id == current_user.id,
            UserInventory.is_wishlist.is_(True),
        )
        .options(
            selectinload(UserInventory.card_set_link).selectinload(CardSetsLink.card),
            selectinload(UserInventory.card_set_link).selectinload(CardSetsLink.set_),
        )
    )
    return [_item_to_response(i) for i in result.scalars().all()]


@router.get("/me/trades", response_model=list[InventoryItemResponse])
async def get_trades(current_user: CurrentUser, db: DB) -> list[InventoryItemResponse]:
    """Cards the user is willing to trade."""
    result = await db.execute(
        select(UserInventory)
        .where(
            UserInventory.user_id == current_user.id,
            UserInventory.is_for_trade.is_(True),
        )
        .options(
            selectinload(UserInventory.card_set_link).selectinload(CardSetsLink.card),
            selectinload(UserInventory.card_set_link).selectinload(CardSetsLink.set_),
        )
    )
    return [_item_to_response(i) for i in result.scalars().all()]
