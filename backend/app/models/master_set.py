"""
app/models/master_set.py
------------------------
Yu-Gi-Oh! expansion set (booster pack, structure deck, etc.)
Data sourced from YGOPRODeck and periodically refreshed.
"""

from datetime import date, datetime

from sqlalchemy import Date, DateTime, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class MasterSet(Base):
    __tablename__ = "master_sets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    set_name: Mapped[str] = mapped_column(String(255), nullable=False)
    set_code: Mapped[str] = mapped_column(String(10), unique=True, nullable=False, index=True)
    set_type: Mapped[str | None] = mapped_column(String(50), nullable=True)
    num_of_cards: Mapped[int | None] = mapped_column(Integer, nullable=True)
    tcg_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    set_image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    source_updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Relationships
    card_links: Mapped[list["CardSetsLink"]] = relationship(  # noqa: F821
        "CardSetsLink", back_populates="set_", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<MasterSet {self.set_code}: {self.set_name}>"
