"""
app/models/user_inventory.py
-----------------------------
A user's card collection entry.
One row = one unique combination of (user, card_print, edition, condition).
Quantity tracks how many copies the user owns of that exact variant.
"""

import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class UserInventory(Base):
    __tablename__ = "user_inventory"
    __table_args__ = (
        # Atomic UPSERT target: same user + same print + edition + condition = one row
        UniqueConstraint(
            "user_id", "card_sets_link_id", "edition", "condition",
            name="uq_user_card_variant",
        ),
        CheckConstraint("quantity > 0", name="chk_quantity_positive"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    card_sets_link_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("card_sets_link.id"),
        nullable=False,
        index=True,
    )

    # ── Card variant fields ──────────────────────────────────────────────────
    edition: Mapped[str] = mapped_column(
        String(20), nullable=False, default="Unlimited"
        # Allowed: '1st Edition', 'Unlimited', 'Limited'
    )
    condition: Mapped[str] = mapped_column(
        String(20), nullable=False, default="Near Mint"
        # Allowed: 'Mint', 'Near Mint', 'Lightly Played',
        #          'Moderately Played', 'Heavily Played', 'Damaged'
    )
    quantity: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=1)
    is_foil: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    # ── Price tracking ───────────────────────────────────────────────────────
    acquired_price: Mapped[float | None] = mapped_column(Numeric(10, 2), nullable=True)

    # ── Status flags ─────────────────────────────────────────────────────────
    is_for_trade: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_wishlist: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    # ── Timestamps ───────────────────────────────────────────────────────────
    added_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # ── Relationships ─────────────────────────────────────────────────────────
    user: Mapped["User"] = relationship("User", back_populates="inventory")  # noqa: F821
    card_set_link: Mapped["CardSetsLink"] = relationship(  # noqa: F821
        "CardSetsLink", back_populates="inventory_entries"
    )

    def __repr__(self) -> str:
        return f"<Inventory user={self.user_id} link={self.card_sets_link_id} qty={self.quantity}>"
