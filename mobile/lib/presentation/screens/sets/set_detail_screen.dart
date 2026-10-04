// lib/presentation/screens/sets/set_detail_screen.dart
// ----------------------------------------
// Displays all cards in a set with "Complete This Set" tracker
// and filter for missing cards.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/card_set_link_model.dart';
import '../../providers/card_search_provider.dart';
import '../../providers/inventory_provider.dart';
import '../scanner/scan_confirmation_sheet.dart';

class SetDetailScreen extends ConsumerStatefulWidget {
  final String setCode;
  final String? setName;

  const SetDetailScreen({super.key, required this.setCode, this.setName});

  @override
  ConsumerState<SetDetailScreen> createState() => _SetDetailScreenState();
}

class _SetDetailScreenState extends ConsumerState<SetDetailScreen> {
  List<CardSetLinkModel> _cards = [];
  bool _isLoading = true;
  bool _missingOnly = false;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    final repo = ref.read(cardRepositoryProvider);
    final cards = await repo.getCardsInSet(widget.setCode);
    setState(() {
      _cards = cards;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryProvider);
    final ownedCodes = inventoryState.items.map((i) => i.setCode).toSet();

    final ownedCount = _cards.where((c) => ownedCodes.contains(c.setCode)).length;
    final totalCount = _cards.length;
    final progress = totalCount > 0 ? ownedCount / totalCount : 0.0;

    final displayedCards = _missingOnly
        ? _cards.where((c) => !ownedCodes.contains(c.setCode)).toList()
        : _cards;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.setName ?? widget.setCode),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : Column(
              children: [
                // Set Completion Progress Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Completitud: $ownedCount / $totalCount cartas',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: const TextStyle(
                              color: AppTheme.primaryGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: AppTheme.surfaceVariant,
                          color: AppTheme.primaryGold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Mostrar solo cartas faltantes',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                          Switch(
                            value: _missingOnly,
                            activeColor: AppTheme.primaryGold,
                            onChanged: (val) => setState(() => _missingOnly = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Cards in set list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: displayedCards.length,
                    itemBuilder: (context, index) {
                      final card = displayedCards[index];
                      final isOwned = ownedCodes.contains(card.setCode);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isOwned ? AppTheme.primaryGold.withOpacity(0.5) : AppTheme.cardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isOwned ? AppTheme.primaryGold : AppTheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                card.setCode,
                                style: TextStyle(
                                  color: isOwned ? Colors.black : AppTheme.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    card.cardName ?? '',
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    card.setRarity ?? 'Common',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            if (isOwned)
                              const Icon(Icons.check_circle, color: AppTheme.primaryGold, size: 22)
                            else
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: AppTheme.textMuted),
                                tooltip: 'Añadir carta',
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => ScanConfirmationSheet(
                                      cardInfo: card,
                                      onDismissed: () {},
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
