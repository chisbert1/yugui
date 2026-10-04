"""
app/models/master_card.py
-------------------------
Static card data sourced from YGOPRODeck.
Uses YGOPRODeck's integer ID as the primary key to simplify UPSERT sync.
"""

from datetime import datetime

from sqlalchemy import DateTime, Integer, Numeric, SmallInteger, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class MasterCard(Base):
    __tablename__ = "master_cards"

    # YGOPRODeck integer ID used directly as PK (avoids mapping table)
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    card_type: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    frame_type: Mapped[str | None] = mapped_column(String(50), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Monster stats (NULL for Spells/Traps)
    atk: Mapped[int | None] = mapped_column(Integer, nullable=True)
    def_: Mapped[int | None] = mapped_column("def", Integer, nullable=True)  # 'def' is reserved
    level: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    race: Mapped[str | None] = mapped_column(String(50), nullable=True)
    attribute: Mapped[str | None] = mapped_column(String(20), nullable=True)

    # Special monster types
    link_val: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    scale: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)

    # Metadata
    archetype: Mapped[str | None] = mapped_column(String(100), nullable=True, index=True)
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    image_url_small: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # Banlist status
    is_banned_tcg: Mapped[str | None] = mapped_column(String(20), nullable=True)
    is_banned_ocg: Mapped[str | None] = mapped_column(String(20), nullable=True)

    source_updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Relationships
    set_links: Mapped[list["CardSetsLink"]] = relationship(  # noqa: F821
        "CardSetsLink", back_populates="card", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<MasterCard {self.id}: {self.name}>"
