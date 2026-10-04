// lib/data/datasources/local/card_local_data_source.dart
// ----------------------------------------
// Queries the local SQLite card database (yugioh_lite.db).
// Fast offline reads for OCR lookups, catalog searching, and sets.

import 'package:yugioh_collector/data/models/card_model.dart';
import 'package:yugioh_collector/data/models/card_set_link_model.dart';
import 'package:yugioh_collector/data/models/set_model.dart';
import 'database_helper.dart';

class CardLocalDataSource {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Critical OCR lookup: finds card & printing by set code (e.g. "LOB-001")
  Future<CardSetLinkModel?> lookupBySetCode(String setCode) async {
    final db = await _dbHelper.cardDatabase;
    final normalized = setCode.trim().toUpperCase();

    final results = await db.rawQuery('''
      SELECT 
        csl.id,
        csl.card_id,
        csl.set_id,
        csl.set_code,
        csl.set_rarity,
        csl.set_rarity_code,
        csl.set_price,
        mc.name AS card_name,
        mc.type,
        mc.frame_type,
        mc.desc,
        mc.atk,
        mc.def,
        mc.level,
        mc.attribute,
        mc.image_url_small,
        mc.image_url,
        ms.set_name
      FROM card_sets_link csl
      JOIN master_cards mc ON csl.card_id = mc.id
      JOIN master_sets ms ON csl.set_id = ms.id
      WHERE UPPER(csl.set_code) = ?
      LIMIT 1
    ''', [normalized]);

    if (results.isEmpty) return null;
    return CardSetLinkModel.fromMap(results.first);
  }

  /// Searches cards by name or card text
  Future<List<CardModel>> searchCards(String query, {int limit = 30, int offset = 0}) async {
    final db = await _dbHelper.cardDatabase;
    final cleanQuery = '%${query.trim()}%';

    final results = await db.rawQuery('''
      SELECT * FROM master_cards
      WHERE name LIKE ?
      ORDER BY name ASC
      LIMIT ? OFFSET ?
    ''', [cleanQuery, limit, offset]);

    return results.map((row) => CardModel.fromMap(row)).toList();
  }

  /// Gets all printings for a specific card
  Future<List<CardSetLinkModel>> getCardPrintings(int cardId) async {
    final db = await _dbHelper.cardDatabase;

    final results = await db.rawQuery('''
      SELECT 
        csl.id,
        csl.card_id,
        csl.set_id,
        csl.set_code,
        csl.set_rarity,
        csl.set_rarity_code,
        csl.set_price,
        mc.name AS card_name,
        mc.image_url_small,
        ms.set_name
      FROM card_sets_link csl
      JOIN master_cards mc ON csl.card_id = mc.id
      JOIN master_sets ms ON csl.set_id = ms.id
      WHERE csl.card_id = ?
      ORDER BY ms.tcg_date DESC, csl.set_code ASC
    ''', [cardId]);

    return results.map((row) => CardSetLinkModel.fromMap(row)).toList();
  }

  /// Lists expansion sets
  Future<List<SetModel>> getSets({String? query, int limit = 100}) async {
    final db = await _dbHelper.cardDatabase;

    List<Map<String, dynamic>> results;
    if (query != null && query.isNotEmpty) {
      results = await db.rawQuery('''
        SELECT * FROM master_sets
        WHERE set_name LIKE ? OR set_code LIKE ?
        ORDER BY tcg_date DESC
        LIMIT ?
      ''', ['%$query%', '%$query%', limit]);
    } else {
      results = await db.rawQuery('''
        SELECT * FROM master_sets
        ORDER BY tcg_date DESC
        LIMIT ?
      ''', [limit]);
    }

    return results.map((row) => SetModel.fromMap(row)).toList();
  }

  /// Gets all cards in a specific set
  Future<List<CardSetLinkModel>> getCardsInSet(String setCode) async {
    final db = await _dbHelper.cardDatabase;

    final results = await db.rawQuery('''
      SELECT 
        csl.id,
        csl.card_id,
        csl.set_id,
        csl.set_code,
        csl.set_rarity,
        csl.set_rarity_code,
        csl.set_price,
        mc.name AS card_name,
        mc.type,
        mc.frame_type,
        mc.desc,
        mc.atk,
        mc.def,
        mc.level,
        mc.attribute,
        mc.image_url_small,
        ms.set_name
      FROM card_sets_link csl
      JOIN master_cards mc ON csl.card_id = mc.id
      JOIN master_sets ms ON csl.set_id = ms.id
      WHERE UPPER(ms.set_code) = ?
      ORDER BY csl.set_code ASC
    ''', [setCode.trim().toUpperCase()]);

    return results.map((row) => CardSetLinkModel.fromMap(row)).toList();
  }
}
