"""
app/models/sync_metadata.py
----------------------------
Audit log for background synchronisation jobs.
Allows monitoring, checkpointing and debugging sync failures.
"""

from datetime import datetime

from sqlalchemy import DateTime, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class SyncMetadata(Base):
    __tablename__ = "sync_metadata"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    sync_type: Mapped[str] = mapped_column(
        String(50), nullable=False
        # Values: 'full_cards', 'full_sets', 'prices', 'sqlite_export'
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="running"
        # Values: 'running', 'completed', 'failed'
    )
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    records_synced: Mapped[int | None] = mapped_column(Integer, nullable=True)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    api_version: Mapped[str | None] = mapped_column(String(20), nullable=True)

    def __repr__(self) -> str:
        return f"<SyncMetadata type={self.sync_type} status={self.status}>"
