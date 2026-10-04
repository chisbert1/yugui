"""
app/models/card_sets_link.py
-----------------------------
N:M junction table between MasterCard and MasterSet.
Each row represents ONE specific printing of a card
(set_code like "DUSA-EN001" is what the OCR reads from the physical card).
"""

from datetime import datetime

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class CardSetsLink(Base):
    __tablename__ = "card_sets_link"
    __table_args__ = (
        # One card has exactly one rarity per print in a specific set
        UniqueConstraint("card_id", "set_id", "rarity", name="uq_card_set_rarity"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    card_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("master_cards.id", ondelete="CASCADE"), nullable=False, index=True
    )
    set_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("master_sets.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # Full print code — THE field the OCR returns (e.g. "DUSA-EN001")
    # This is the most queried column in the entire system.
    set_code: Mapped[str] = mapped_column(String(20), nullable=False, index=True)

    rarity: Mapped[str] = mapped_column(String(50), nullable=False)
    rarity_code: Mapped[str | None] = mapped_column(String(10), nullable=True)

    # Market price (updated by the daily price sync job)
    price_usd: Mapped[float | None] = mapped_column(Numeric(10, 4), nullable=True)
    price_updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Relationships
    card: Mapped["MasterCard"] = relationship("MasterCard", back_populates="set_links")  # noqa: F821
    set_: Mapped["MasterSet"] = relationship("MasterSet", back_populates="card_links")  # noqa: F821
    inventory_entries: Mapped[list["UserInventory"]] = relationship(  # noqa: F821
        "UserInventory", back_populates="card_set_link"
    )

    def __repr__(self) -> str:
        return f"<CardSetsLink {self.set_code} | {self.rarity}>"
