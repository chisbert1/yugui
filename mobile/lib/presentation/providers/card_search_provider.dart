// lib/presentation/providers/card_search_provider.dart
// ----------------------------------------
// State management for catalog card search and sets exploration.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/card_model.dart';
import '../../data/models/set_model.dart';
import '../../data/repositories/card_repository.dart';

final cardRepositoryProvider = Provider<CardRepository>((ref) => CardRepository());

class CardSearchState {
  final List<CardModel> cards;
  final List<SetModel> sets;
  final bool isLoading;
  final String query;
  final String? error;

  const CardSearchState({
    this.cards = const [],
    this.sets = const [],
    this.isLoading = false,
    this.query = '',
    this.error,
  });

  CardSearchState copyWith({
    List<CardModel>? cards,
    List<SetModel>? sets,
    bool? isLoading,
    String? query,
    String? error,
  }) {
    return CardSearchState(
      cards: cards ?? this.cards,
      sets: sets ?? this.sets,
      isLoading: isLoading ?? this.isLoading,
      query: query ?? this.query,
      error: error,
    );
  }
}

class CardSearchNotifier extends StateNotifier<CardSearchState> {
  final CardRepository _repo;

  CardSearchNotifier(this._repo) : super(const CardSearchState()) {
    search('');
    loadSets();
  }

  Future<void> search(String query) async {
    state = state.copyWith(isLoading: true, query: query, error: null);
    try {
      final results = await _repo.searchCards(query);
      state = state.copyWith(cards: results, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadSets({String? query}) async {
    try {
      final sets = await _repo.getSets(query: query);
      state = state.copyWith(sets: sets);
    } catch (_) {}
  }
}

final cardSearchProvider = StateNotifierProvider<CardSearchNotifier, CardSearchState>((ref) {
  final repo = ref.watch(cardRepositoryProvider);
  return CardSearchNotifier(repo);
});
