"""Initial schema — all tables

Revision ID: 0001
Revises: 
Create Date: 2026-10-04
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── users ─────────────────────────────────────────────────────────────────
    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("username", sa.String(50), nullable=False),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("last_sync_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_unique_constraint("uq_users_username", "users", ["username"])
    op.create_unique_constraint("uq_users_email", "users", ["email"])
    op.create_index("idx_users_email", "users", ["email"])
    op.create_index("idx_users_username", "users", ["username"])

    # ── master_sets ───────────────────────────────────────────────────────────
    op.create_table(
        "master_sets",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("set_name", sa.String(255), nullable=False),
        sa.Column("set_code", sa.String(10), nullable=False),
        sa.Column("set_type", sa.String(50), nullable=True),
        sa.Column("num_of_cards", sa.Integer(), nullable=True),
        sa.Column("tcg_date", sa.Date(), nullable=True),
        sa.Column("set_image_url", sa.String(500), nullable=True),
        sa.Column("source_updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_unique_constraint("uq_master_sets_code", "master_sets", ["set_code"])
    op.create_index("idx_master_sets_code", "master_sets", ["set_code"], unique=True)

    # ── master_cards ──────────────────────────────────────────────────────────
    op.create_table(
        "master_cards",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("card_type", sa.String(50), nullable=False),
        sa.Column("frame_type", sa.String(50), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("atk", sa.Integer(), nullable=True),
        sa.Column("def", sa.Integer(), nullable=True),
        sa.Column("level", sa.SmallInteger(), nullable=True),
        sa.Column("race", sa.String(50), nullable=True),
        sa.Column("attribute", sa.String(20), nullable=True),
        sa.Column("link_val", sa.SmallInteger(), nullable=True),
        sa.Column("scale", sa.SmallInteger(), nullable=True),
        sa.Column("archetype", sa.String(100), nullable=True),
        sa.Column("image_url", sa.String(500), nullable=True),
        sa.Column("image_url_small", sa.String(500), nullable=True),
        sa.Column("is_banned_tcg", sa.String(20), nullable=True),
        sa.Column("is_banned_ocg", sa.String(20), nullable=True),
        sa.Column("source_updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("idx_master_cards_name", "master_cards", ["name"])
    op.create_index("idx_master_cards_type", "master_cards", ["card_type"])
    op.create_index("idx_master_cards_archetype", "master_cards", ["archetype"])

    # ── card_sets_link ────────────────────────────────────────────────────────
    op.create_table(
        "card_sets_link",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("card_id", sa.Integer(), sa.ForeignKey("master_cards.id", ondelete="CASCADE"), nullable=False),
        sa.Column("set_id", sa.Integer(), sa.ForeignKey("master_sets.id", ondelete="CASCADE"), nullable=False),
        sa.Column("set_code", sa.String(20), nullable=False),
        sa.Column("rarity", sa.String(50), nullable=False),
        sa.Column("rarity_code", sa.String(10), nullable=True),
        sa.Column("price_usd", sa.Numeric(10, 4), nullable=True),
        sa.Column("price_updated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_unique_constraint("uq_card_set_rarity", "card_sets_link", ["card_id", "set_id", "rarity"])
    op.create_index("idx_csl_set_code", "card_sets_link", ["set_code"])   # ← Critical OCR lookup
    op.create_index("idx_csl_card_id",  "card_sets_link", ["card_id"])
    op.create_index("idx_csl_set_id",   "card_sets_link", ["set_id"])
    op.create_index("idx_csl_card_set", "card_sets_link", ["card_id", "set_id"])

    # ── user_inventory ────────────────────────────────────────────────────────
    op.create_table(
        "user_inventory",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("card_sets_link_id", sa.Integer(), sa.ForeignKey("card_sets_link.id"), nullable=False),
        sa.Column("edition", sa.String(20), nullable=False, server_default="Unlimited"),
        sa.Column("condition", sa.String(20), nullable=False, server_default="Near Mint"),
        sa.Column("quantity", sa.SmallInteger(), nullable=False, server_default="1"),
        sa.Column("is_foil", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("acquired_price", sa.Numeric(10, 2), nullable=True),
        sa.Column("is_for_trade", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("is_wishlist", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("added_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("quantity > 0", name="chk_quantity_positive"),
    )
    op.create_unique_constraint(
        "uq_user_card_variant", "user_inventory",
        ["user_id", "card_sets_link_id", "edition", "condition"]
    )
    op.create_index("idx_inventory_user_id",      "user_inventory", ["user_id"])
    op.create_index("idx_inventory_card_sets_link","user_inventory", ["card_sets_link_id"])
    op.create_index("idx_inventory_added_at",      "user_inventory", ["user_id", "added_at"])

    # Partial indexes for filtered queries (trade and wishlist)
    op.execute(
        "CREATE INDEX idx_inventory_user_trade ON user_inventory(user_id) WHERE is_for_trade = true"
    )
    op.execute(
        "CREATE INDEX idx_inventory_wishlist ON user_inventory(user_id) WHERE is_wishlist = true"
    )

    # ── sync_metadata ─────────────────────────────────────────────────────────
    op.create_table(
        "sync_metadata",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("sync_type", sa.String(50), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="running"),
        sa.Column("started_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("records_synced", sa.Integer(), nullable=True),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("api_version", sa.String(20), nullable=True),
    )


def downgrade() -> None:
    op.drop_table("sync_metadata")
    op.execute("DROP INDEX IF EXISTS idx_inventory_wishlist")
    op.execute("DROP INDEX IF EXISTS idx_inventory_user_trade")
    op.drop_table("user_inventory")
    op.drop_table("card_sets_link")
    op.drop_table("master_cards")
    op.drop_table("master_sets")
    op.drop_table("users")
