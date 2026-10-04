// lib/data/models/inventory_stats_model.dart
// ----------------------------------------
// Statistics summary for user's collection binder.

class InventoryStatsModel {
  final int totalCards;
  final int uniqueCards;
  final double estimatedValueTcg;
  final double estimatedValueCm;
  final int wishlistCount;

  InventoryStatsModel({
    required this.totalCards,
    required this.uniqueCards,
    required this.estimatedValueTcg,
    required this.estimatedValueCm,
    required this.wishlistCount,
  });

  factory InventoryStatsModel.fromMap(Map<String, dynamic> map) {
    return InventoryStatsModel(
      totalCards: (map['total_cards'] as int?) ?? 0,
      uniqueCards: (map['unique_cards'] as int?) ?? 0,
      estimatedValueTcg: (map['estimated_value_tcg'] as num?)?.toDouble() ?? 0.0,
      estimatedValueCm: (map['estimated_value_cardmarket'] as num?)?.toDouble() ?? 0.0,
      wishlistCount: (map['wishlist_count'] as int?) ?? 0,
    );
  }

  factory InventoryStatsModel.empty() {
    return InventoryStatsModel(
      totalCards: 0,
      uniqueCards: 0,
      estimatedValueTcg: 0.0,
      estimatedValueCm: 0.0,
      wishlistCount: 0,
    );
  }
}
