// lib/data/datasources/local/database_helper.dart
// ----------------------------------------
// Dual database management:
// 1. Lite Card Database (yugioh_lite.db) - offline catalog downloaded from backend.
// 2. User Inventory Database (inventory.db) - user collection and offline sync queue.

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/constants/app_constants.dart';
import 'initial_card_seed.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _cardDb;
  Database? _inventoryDb;

  /// Returns connection to the master card catalog SQLite database
  Future<Database> get cardDatabase async {
    if (_cardDb != null && _cardDb!.isOpen) return _cardDb!;
    _cardDb = await _initCardDb();
    return _cardDb!;
  }

  /// Returns connection to the user's local inventory & offline queue database
  Future<Database> get inventoryDatabase async {
    if (_inventoryDb != null && _inventoryDb!.isOpen) return _inventoryDb!;
    _inventoryDb = await _initInventoryDb();
    return _inventoryDb!;
  }

  Future<String> getCardDbPath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return join(docsDir.path, AppConstants.localDbName);
  }

  Future<Database> _initCardDb() async {
    final path = await getCardDbPath();

    // If card DB doesn't exist yet, create a baseline schema
    // (This will be replaced completely when full lite DB is downloaded from backend)
    final db = await openDatabase(
      path,
      version: AppConstants.localDbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS master_cards (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT,
            frame_type TEXT,
            desc TEXT,
            atk INTEGER,
            def INTEGER,
            level INTEGER,
            race TEXT,
            attribute TEXT,
            image_url_small TEXT,
            image_url TEXT,
            tcgplayer_price REAL,
            cardmarket_price REAL
          );
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS master_sets (
            id INTEGER PRIMARY KEY,
            set_code TEXT UNIQUE NOT NULL,
            set_name TEXT NOT NULL,
            num_of_cards INTEGER,
            tcg_date TEXT
          );
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS card_sets_link (
            id INTEGER PRIMARY KEY,
            card_id INTEGER NOT NULL,
            set_id INTEGER NOT NULL,
            set_code TEXT NOT NULL,
            set_rarity TEXT,
            set_rarity_code TEXT,
            set_price REAL
          );
        ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_csl_set_code ON card_sets_link(set_code);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_csl_card_id ON card_sets_link(card_id);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_csl_set_id ON card_sets_link(set_id);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_cards_name ON master_cards(name);');

        await InitialCardSeed.seedIfEmpty(db);
      },
    );

    // Ensure database is populated if opened from an existing empty database
    await InitialCardSeed.seedIfEmpty(db);
    return db;
  }

  Future<Database> _initInventoryDb() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, AppConstants.inventoryDbName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // User inventory cache
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_inventory (
            id INTEGER PRIMARY KEY,
            card_id INTEGER NOT NULL,
            card_set_link_id INTEGER NOT NULL,
            set_code TEXT NOT NULL,
            name TEXT NOT NULL,
            set_name TEXT,
            rarity TEXT,
            image_url_small TEXT,
            edition TEXT NOT NULL DEFAULT '1st Edition',
            condition TEXT NOT NULL DEFAULT 'Near Mint',
            quantity INTEGER NOT NULL DEFAULT 1,
            is_wishlist INTEGER NOT NULL DEFAULT 0,
            price REAL,
            notes TEXT,
            updated_at INTEGER NOT NULL
          );
        ''');

        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_inv_code_ed ON local_inventory(set_code, edition);');

        // Pending mutations queue for offline syncing
        await db.execute('''
          CREATE TABLE IF NOT EXISTS pending_mutations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT NOT NULL,
            endpoint TEXT NOT NULL,
            method TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0
          );
        ''');
      },
    );
  }

  /// Closes and resets card DB connection (used when updating downloaded SQLite file)
  Future<void> resetCardDbConnection() async {
    if (_cardDb != null && _cardDb!.isOpen) {
      await _cardDb!.close();
      _cardDb = null;
    }
  }
}
