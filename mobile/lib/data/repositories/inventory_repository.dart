// lib/data/repositories/inventory_repository.dart
// ----------------------------------------
// Inventory Repository with Optimistic Local-First updates:
// 1. All writes update local SQLite immediately for 0ms UI response.
// 2. Mutations are enqueued to OfflineQueueManager for remote backend sync.
// 3. Online sync reconciles backend state down to SQLite.

import 'package:sqflite/sqflite.dart';
import '../../core/network/api_client.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/sync/offline_queue.dart';
import '../datasources/local/database_helper.dart';
import '../models/card_set_link_model.dart';
import '../models/inventory_item_model.dart';
import '../models/inventory_stats_model.dart';

class InventoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ApiClient _apiClient = ApiClient();
  final ConnectivityService _connectivity = ConnectivityService();
  final OfflineQueueManager _queueManager = OfflineQueueManager();

  /// Gets inventory from local SQLite database (always works offline)
  Future<List<InventoryItemModel>> getInventory({
    String? search,
    bool? isWishlist,
    String? edition,
  }) async {
    final db = await _dbHelper.inventoryDatabase;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (search != null && search.isNotEmpty) {
      whereClauses.add('(name LIKE ? OR set_code LIKE ?)');
      whereArgs.addAll(['%$search%', '%$search%']);
    }

    if (isWishlist != null) {
      whereClauses.add('is_wishlist = ?');
      whereArgs.add(isWishlist ? 1 : 0);
    }

    if (edition != null && edition.isNotEmpty) {
      whereClauses.add('edition = ?');
      whereArgs.add(edition);
    }

    final where = whereClauses.isEmpty ? null : whereClauses.join(' AND ');

    final rows = await db.query(
      'local_inventory',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'updated_at DESC',
    );

    return rows.map((r) => InventoryItemModel.fromMap(r)).toList();
  }

  /// Adds a card to the inventory (Atomic Local Upsert + Async Queue)
  Future<InventoryItemModel> addCard({
    required String setCode,
    String edition = '1st Edition',
    String condition = 'Near Mint',
    int quantity = 1,
    bool isWishlist = false,
    CardSetLinkModel? cardInfo,
  }) async {
    final db = await _dbHelper.inventoryDatabase;
    final cleanCode = setCode.trim().toUpperCase();

    // Check if card with same set_code and edition already exists
    final existing = await db.query(
      'local_inventory',
      where: 'set_code = ? AND edition = ?',
      whereArgs: [cleanCode, edition],
      limit: 1,
    );

    InventoryItemModel item;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (existing.isNotEmpty) {
      // Duplicate scanned! Increment quantity
      final currentItem = InventoryItemModel.fromMap(existing.first);
      final newQuantity = currentItem.quantity + quantity;

      await db.update(
        'local_inventory',
        {
          'quantity': newQuantity,
          'condition': condition,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [currentItem.id],
      );

      item = currentItem.copyWith(
        quantity: newQuantity,
        condition: condition,
        updatedAt: now,
      );
    } else {
      // Insert new entry
      final map = {
        'card_id': cardInfo?.cardId ?? 0,
        'card_set_link_id': cardInfo?.id ?? 0,
        'set_code': cleanCode,
        'name': cardInfo?.cardName ?? cleanCode,
        'set_name': cardInfo?.setName,
        'rarity': cardInfo?.setRarity,
        'image_url_small': cardInfo?.imageUrlSmall,
        'edition': edition,
        'condition': condition,
        'quantity': quantity,
        'is_wishlist': isWishlist ? 1 : 0,
        'price': cardInfo?.setPrice,
        'notes': null,
        'updated_at': now,
      };

      final insertId = await db.insert('local_inventory', map, conflictAlgorithm: ConflictAlgorithm.replace);
      item = InventoryItemModel.fromMap({...map, 'id': insertId});
    }

    // Enqueue mutation to sync with backend
    await _queueManager.enqueue(
      action: QueueAction.addCard,
      endpoint: '/inventory/add',
      method: 'POST',
      payload: {
        'set_code': cleanCode,
        'edition': edition,
        'condition': condition,
        'quantity': quantity,
        'is_wishlist': isWishlist,
      },
    );

    return item;
  }

  /// Updates quantity, condition, or edition of an existing card
  Future<void> updateItem(InventoryItemModel item) async {
    final db = await _dbHelper.inventoryDatabase;
    await db.update(
      'local_inventory',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );

    if (item.id != null) {
      await _queueManager.enqueue(
        action: QueueAction.updateInventory,
        endpoint: '/inventory/${item.id}',
        method: 'PUT',
        payload: {
          'quantity': item.quantity,
          'condition': item.condition,
          'edition': item.edition,
          'is_wishlist': item.isWishlist,
          'notes': item.notes,
        },
      );
    }
  }

  /// Deletes a card from the collection
  Future<void> deleteItem(int id) async {
    final db = await _dbHelper.inventoryDatabase;
    await db.delete(
      'local_inventory',
      where: 'id = ?',
      whereArgs: [id],
    );

    await _queueManager.enqueue(
      action: QueueAction.deleteInventory,
      endpoint: '/inventory/$id',
      method: 'DELETE',
      payload: {},
    );
  }

  /// Calculates collection stats
  Future<InventoryStatsModel> getStats() async {
    final db = await _dbHelper.inventoryDatabase;

    final countResult = await db.rawQuery('''
      SELECT 
        SUM(quantity) AS total_cards,
        COUNT(DISTINCT set_code) AS unique_cards,
        SUM(quantity * COALESCE(price, 0)) AS estimated_value_tcg
      FROM local_inventory
      WHERE is_wishlist = 0
    ''');

    final wishlistResult = await db.rawQuery('''
      SELECT COUNT(*) AS wishlist_count
      FROM local_inventory
      WHERE is_wishlist = 1
    ''');

    if (countResult.isNotEmpty) {
      final row = countResult.first;
      final total = (row['total_cards'] as int?) ?? 0;
      final unique = (row['unique_cards'] as int?) ?? 0;
      final value = (row['estimated_value_tcg'] as num?)?.toDouble() ?? 0.0;
      final wishlist = Sqflite.firstIntValue(wishlistResult) ?? 0;

      return InventoryStatsModel(
        totalCards: total,
        uniqueCards: unique,
        estimatedValueTcg: value,
        estimatedValueCm: value * 0.92, // Approximate EUR/Cardmarket equivalent
        wishlistCount: wishlist,
      );
    }

    return InventoryStatsModel.empty();
  }

  /// Syncs inventory from backend to local SQLite when online
  Future<void> syncRemoteInventory() async {
    if (!_connectivity.isOnline) return;

    try {
      final response = await _apiClient.dio.get('/inventory', queryParameters: {'limit': 100});
      if (response.statusCode == 200 && response.data != null) {
        final items = (response.data['items'] as List<dynamic>?) ?? [];
        final db = await _dbHelper.inventoryDatabase;

        for (final item in items) {
          final setCode = item['set_code'] as String;
          final edition = item['edition'] as String? ?? '1st Edition';
          final cardData = item['card'] as Map<String, dynamic>? ?? {};

          await db.insert(
            'local_inventory',
            {
              'card_id': item['card_id'] ?? 0,
              'card_set_link_id': item['card_set_link_id'] ?? 0,
              'set_code': setCode,
              'name': cardData['name'] ?? setCode,
              'set_name': item['set_name'],
              'rarity': item['set_rarity'],
              'image_url_small': cardData['image_url_small'],
              'edition': edition,
              'condition': item['condition'] ?? 'Near Mint',
              'quantity': item['quantity'] ?? 1,
              'is_wishlist': item['is_wishlist'] == true ? 1 : 0,
              'price': item['price'],
              'notes': item['notes'],
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    } catch (_) {}
  }
}
