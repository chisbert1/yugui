// lib/data/repositories/card_repository.dart
// ----------------------------------------
// Hybrid Card Repository implementing the Offline-First OCR lookup pattern.
// 1. Check local SQLite DB first (0ms latency, works offline).
// 2. Fallback to REST API if missing (new card released) and save to local DB.

import '../../core/network/api_client.dart';
import '../../core/network/connectivity_service.dart';
import '../datasources/local/card_local_data_source.dart';
import '../models/card_model.dart';
import '../models/card_set_link_model.dart';
import '../models/set_model.dart';

class CardRepository {
  final CardLocalDataSource _localSource = CardLocalDataSource();
  final ApiClient _apiClient = ApiClient();
  final ConnectivityService _connectivity = ConnectivityService();

  /// Primary OCR lookup method
  Future<CardSetLinkModel?> lookupBySetCode(String setCode) async {
    final cleanCode = setCode.trim().toUpperCase();

    // 1. Try local SQLite database first
    final localResult = await _localSource.lookupBySetCode(cleanCode);
    if (localResult != null) {
      return localResult;
    }

    // 2. If not found in local DB and we are online, query backend API
    if (_connectivity.isOnline) {
      try {
        final response = await _apiClient.dio.get('/cards/set/$cleanCode');
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data as Map<String, dynamic>;
          final cardData = data['card'] as Map<String, dynamic>? ?? {};
          final printingData = data['printing'] as Map<String, dynamic>? ?? {};

          return CardSetLinkModel(
            id: printingData['id'] as int? ?? 0,
            cardId: cardData['id'] as int? ?? 0,
            setId: printingData['set_id'] as int? ?? 0,
            setCode: printingData['set_code'] as String? ?? cleanCode,
            setRarity: printingData['set_rarity'] as String?,
            setRarityCode: printingData['set_rarity_code'] as String?,
            setPrice: (printingData['set_price'] as num?)?.toDouble(),
            cardName: cardData['name'] as String?,
            imageUrlSmall: cardData['image_url_small'] as String?,
            imageUrl: cardData['image_url'] as String?,
            type: cardData['type'] as String?,
            desc: cardData['desc'] as String?,
            atk: cardData['atk'] as int?,
            def: cardData['def'] as int?,
            level: cardData['level'] as int?,
            attribute: cardData['attribute'] as String?,
          );
        }
      } catch (_) {
        // Backend lookup failed or 404
      }
    }

    return null;
  }

  /// Search cards in catalog
  Future<List<CardModel>> searchCards(String query, {int limit = 30, int offset = 0}) async {
    return _localSource.searchCards(query, limit: limit, offset: offset);
  }

  /// Get card printings
  Future<List<CardSetLinkModel>> getCardPrintings(int cardId) async {
    return _localSource.getCardPrintings(cardId);
  }

  /// Get list of expansion sets
  Future<List<SetModel>> getSets({String? query}) async {
    return _localSource.getSets(query: query);
  }

  /// Get all cards in a set
  Future<List<CardSetLinkModel>> getCardsInSet(String setCode) async {
    return _localSource.getCardsInSet(setCode);
  }
}
