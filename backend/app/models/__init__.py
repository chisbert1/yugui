"""
app/models/__init__.py
----------------------
Import all ORM models here so Alembic autodiscovers them.
"""

from app.models.user import User           # noqa: F401
from app.models.master_set import MasterSet  # noqa: F401
from app.models.master_card import MasterCard  # noqa: F401
from app.models.card_sets_link import CardSetsLink  # noqa: F401
from app.models.user_inventory import UserInventory  # noqa: F401
from app.models.sync_metadata import SyncMetadata   # noqa: F401
