"""
seed_demo_data.py
------------------
Seeds the PostgreSQL database with iconic Yu-Gi-Oh! cards, sets, and printings,
creates a demo user, and triggers SQLite export for immediate mobile testing.

Run inside docker:
  docker compose exec backend python seed_demo_data.py
Or locally:
  python seed_demo_data.py
"""

import asyncio
from decimal import Decimal
from sqlalchemy import select
from app.core.database import AsyncSessionLocal
from app.core.security import get_password_hash
from app.models.models import User, MasterCard, MasterSet, CardSetsLink
from app.services.sqlite_exporter import SQLiteExporter


SAMPLE_SETS = [
    {
        "set_code": "LOB",
        "set_name": "Legend of Blue Eyes White Dragon",
        "num_of_cards": 126,
        "tcg_date": "2002-03-08",
    },
    {
        "set_code": "SDK",
        "set_name": "Starter Deck: Kaiba",
        "num_of_cards": 50,
        "tcg_date": "2002-03-29",
    },
    {
        "set_code": "SDY",
        "set_name": "Starter Deck: Yugi",
        "num_of_cards": 50,
        "tcg_date": "2002-03-29",
    },
    {
        "set_code": "MP21",
        "set_name": "2021 Tin of Ancient Battles",
        "num_of_cards": 258,
        "tcg_date": "2021-10-01",
    },
]

SAMPLE_CARDS = [
    {
        "id": 89631139,
        "name": "Blue-Eyes White Dragon",
        "type": "Normal Monster",
        "frame_type": "normal",
        "desc": "This legendary dragon is a powerful engine of destruction. Virtually invincible, very few have faced this awesome creature and lived to tell the tale.",
        "atk": 3000,
        "def": 2500,
        "level": 8,
        "race": "Dragon",
        "attribute": "LIGHT",
        "image_url": "https://images.ygoprodeck.com/images/cards/89631139.jpg",
        "image_url_small": "https://images.ygoprodeck.com/images/cards_small/89631139.jpg",
        "tcgplayer_price": Decimal("18.50"),
        "cardmarket_price": Decimal("16.20"),
        "printings": [
            {"set_code": "LOB-001", "set_name": "Legend of Blue Eyes White Dragon", "rarity": "Ultra Rare", "rarity_code": "(UR)", "price": Decimal("85.00")},
            {"set_code": "SDK-001", "set_name": "Starter Deck: Kaiba", "rarity": "Ultra Rare", "rarity_code": "(UR)", "price": Decimal("45.00")},
            {"set_code": "MP21-EN001", "set_name": "2021 Tin of Ancient Battles", "rarity": "Prismatic Secret Rare", "rarity_code": "(PScR)", "price": Decimal("12.00")},
        ],
    },
    {
        "id": 46986414,
        "name": "Dark Magician",
        "type": "Normal Monster",
        "frame_type": "normal",
        "desc": "The ultimate wizard in terms of attack and defense.",
        "atk": 2500,
        "def": 2100,
        "level": 7,
        "race": "Spellcaster",
        "attribute": "DARK",
        "image_url": "https://images.ygoprodeck.com/images/cards/46986414.jpg",
        "image_url_small": "https://images.ygoprodeck.com/images/cards_small/46986414.jpg",
        "tcgplayer_price": Decimal("14.00"),
        "cardmarket_price": Decimal("12.50"),
        "printings": [
            {"set_code": "LOB-005", "set_name": "Legend of Blue Eyes White Dragon", "rarity": "Ultra Rare", "rarity_code": "(UR)", "price": Decimal("65.00")},
            {"set_code": "SDY-006", "set_name": "Starter Deck: Yugi", "rarity": "Ultra Rare", "rarity_code": "(UR)", "price": Decimal("35.00")},
        ],
    },
    {
        "id": 74677422,
        "name": "Red-Eyes Black Dragon",
        "type": "Normal Monster",
        "frame_type": "normal",
        "desc": "A ferocious dragon with a deadly attack.",
        "atk": 2400,
        "def": 2000,
        "level": 7,
        "race": "Dragon",
        "attribute": "DARK",
        "image_url": "https://images.ygoprodeck.com/images/cards/74677422.jpg",
        "image_url_small": "https://images.ygoprodeck.com/images/cards_small/74677422.jpg",
        "tcgplayer_price": Decimal("12.00"),
        "cardmarket_price": Decimal("11.00"),
        "printings": [
            {"set_code": "LOB-070", "set_name": "Legend of Blue Eyes White Dragon", "rarity": "Ultra Rare", "rarity_code": "(UR)", "price": Decimal("50.00")},
        ],
    },
    {
        "id": 33396948,
        "name": "Exodia the Forbidden One",
        "type": "Effect Monster",
        "frame_type": "effect",
        "desc": "If you have 'Right Leg of the Forbidden One', 'Left Leg of the Forbidden One', 'Right Arm of the Forbidden One' and 'Left Arm of the Forbidden One' in addition to this card in your hand, you win the Duel.",
        "atk": 1000,
        "def": 1000,
        "level": 3,
        "race": "Spellcaster",
        "attribute": "DARK",
        "image_url": "https://images.ygoprodeck.com/images/cards/33396948.jpg",
        "image_url_small": "https://images.ygoprodeck.com/images/cards_small/33396948.jpg",
        "tcgplayer_price": Decimal("25.00"),
        "cardmarket_price": Decimal("22.00"),
        "printings": [
            {"set_code": "LOB-124", "set_name": "Legend of Blue Eyes White Dragon", "rarity": "Ultra Rare", "rarity_code": "(UR)", "price": Decimal("90.00")},
        ],
    },
    {
        "id": 55144522,
        "name": "Pot of Greed",
        "type": "Spell Card",
        "frame_type": "spell",
        "desc": "Draw 2 cards.",
        "atk": None,
        "def": None,
        "level": None,
        "race": "Normal",
        "attribute": "SPELL",
        "image_url": "https://images.ygoprodeck.com/images/cards/55144522.jpg",
        "image_url_small": "https://images.ygoprodeck.com/images/cards_small/55144522.jpg",
        "tcgplayer_price": Decimal("8.00"),
        "cardmarket_price": Decimal("6.50"),
        "printings": [
            {"set_code": "LOB-119", "set_name": "Legend of Blue Eyes White Dragon", "rarity": "Rare", "rarity_code": "(R)", "price": Decimal("15.00")},
        ],
    },
]


async def seed():
    print("🌱 Iniciando seed de datos de demostración...")
    async with AsyncSessionLocal() as session:
        # 1. Crear usuario de prueba
        user_stmt = select(User).where(User.email == "yugi@duel.com")
        existing_user = (await session.execute(user_stmt)).scalar_one_or_none()
        if not existing_user:
            demo_user = User(
                email="yugi@duel.com",
                username="YugiMuto",
                hashed_password=get_password_hash("password123"),
                is_active=True,
            )
            session.add(demo_user)
            print("  ✅ Usuario demo creado: yugi@duel.com / password123")
        else:
            print("  ℹ️ Usuario demo ya existe")

        # 2. Insertar Sets
        set_map = {}
        for s in SAMPLE_SETS:
            res = await session.execute(select(MasterSet).where(MasterSet.set_code == s["set_code"]))
            existing_set = res.scalar_one_or_none()
            if not existing_set:
                new_set = MasterSet(**s)
                session.add(new_set)
                await session.flush()
                set_map[s["set_code"]] = new_set.id
            else:
                set_map[s["set_code"]] = existing_set.id

        print(f"  ✅ {len(SAMPLE_SETS)} expansiones verificadas")

        # 3. Insertar Cartas y enlaces de sets
        for card_data in SAMPLE_CARDS:
            printings = card_data.pop("printings", [])
            card_res = await session.execute(select(MasterCard).where(MasterCard.id == card_data["id"]))
            card = card_res.scalar_one_or_none()
            if not card:
                card = MasterCard(**card_data)
                session.add(card)
                await session.flush()

            # Insertar Printings
            for p in printings:
                set_code_prefix = p["set_code"].split("-")[0]
                set_id = set_map.get(set_code_prefix)
                if set_id:
                    link_res = await session.execute(
                        select(CardSetsLink).where(CardSetsLink.set_code == p["set_code"])
                    )
                    if not link_res.scalar_one_or_none():
                        link = CardSetsLink(
                            card_id=card.id,
                            set_id=set_id,
                            set_code=p["set_code"],
                            set_rarity=p["rarity"],
                            set_rarity_code=p["rarity_code"],
                            set_price=p["price"],
                        )
                        session.add(link)

        await session.commit()
        print(f"  ✅ {len(SAMPLE_CARDS)} cartas maestras e impresiones verificadas")

    # 4. Generar el dump SQLite para la app móvil
    print("📦 Generando archivo SQLite local (yugioh_lite.db)...")
    exporter = SQLiteExporter()
    sqlite_path = await exporter.export()
    print(f"  ✅ Dump SQLite generado exitosamente en: {sqlite_path}")
    print("🎉 Seed de demostración completado con éxito.")


if __name__ == "__main__":
    asyncio.run(seed())
