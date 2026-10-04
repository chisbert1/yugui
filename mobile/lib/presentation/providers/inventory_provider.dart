// lib/presentation/providers/inventory_provider.dart
// ----------------------------------------
// StateNotifier for user collection, reactive filtering, and statistics.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/card_set_link_model.dart';
import '../../data/models/inventory_item_model.dart';
import '../../data/models/inventory_stats_model.dart';
import '../../data/repositories/inventory_repository.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) => InventoryRepository());

class InventoryState {
  final List<InventoryItemModel> items;
  final InventoryStatsModel stats;
  final bool isLoading;
  final String searchQuery;
  final bool wishlistOnly;
  final String? editionFilter;
  final String? error;

  const InventoryState({
    this.items = const [],
    required this.stats,
    this.isLoading = false,
    this.searchQuery = '',
    this.wishlistOnly = false,
    this.editionFilter,
    this.error,
  });

  InventoryState copyWith({
    List<InventoryItemModel>? items,
    InventoryStatsModel? stats,
    bool? isLoading,
    String? searchQuery,
    bool? wishlistOnly,
    String? editionFilter,
    String? error,
  }) {
    return InventoryState(
      items: items ?? this.items,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      wishlistOnly: wishlistOnly ?? this.wishlistOnly,
      editionFilter: editionFilter ?? this.editionFilter,
      error: error,
    );
  }
}

class InventoryNotifier extends StateNotifier<InventoryState> {
  final InventoryRepository _repo;

  InventoryNotifier(this._repo) : super(InventoryState(stats: InventoryStatsModel.empty())) {
    loadInventory();
  }

  Future<void> loadInventory() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repo.getInventory(
        search: state.searchQuery.isEmpty ? null : state.searchQuery,
        isWishlist: state.wishlistOnly ? true : null,
        edition: state.editionFilter,
      );
      final stats = await _repo.getStats();
      state = state.copyWith(items: items, stats: stats, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadInventory();
  }

  void toggleWishlistFilter() {
    state = state.copyWith(wishlistOnly: !state.wishlistOnly);
    loadInventory();
  }

  void setEditionFilter(String? edition) {
    state = state.copyWith(editionFilter: edition);
    loadInventory();
  }

  Future<InventoryItemModel> addCard({
    required String setCode,
    String edition = '1st Edition',
    String condition = 'Near Mint',
    int quantity = 1,
    bool isWishlist = false,
    CardSetLinkModel? cardInfo,
  }) async {
    final item = await _repo.addCard(
      setCode: setCode,
      edition: edition,
      condition: condition,
      quantity: quantity,
      isWishlist: isWishlist,
      cardInfo: cardInfo,
    );
    await loadInventory();
    return item;
  }

  Future<void> updateQuantity(InventoryItemModel item, int delta) async {
    final newQty = item.quantity + delta;
    if (newQty <= 0) {
      await _repo.deleteItem(item.id ?? 0);
    } else {
      await _repo.updateItem(item.copyWith(quantity: newQty));
    }
    await loadInventory();
  }

  Future<void> deleteItem(int id) async {
    await _repo.deleteItem(id);
    await loadInventory();
  }

  Future<void> syncRemote() async {
    await _repo.syncRemoteInventory();
    await loadInventory();
  }
}

final inventoryProvider = StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return InventoryNotifier(repo);
});
