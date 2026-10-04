// lib/presentation/screens/sets/sets_screen.dart
// ----------------------------------------
// Booster Sets & Expansions Browser.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/card_search_provider.dart';

class SetsScreen extends ConsumerStatefulWidget {
  const SetsScreen({super.key});

  @override
  ConsumerState<SetsScreen> createState() => _SetsScreenState();
}

class _SetsScreenState extends ConsumerState<SetsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cardSearchProvider);
    final notifier = ref.read(cardSearchProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Expansiones / Sets'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => notifier.loadSets(query: val),
              decoration: InputDecoration(
                hintText: 'Filtrar expansiones (ej: Legend of Blue Eyes, 25th)...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          notifier.loadSets();
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: state.sets.isEmpty
                ? const Center(
                    child: Text('No hay expansiones disponibles', style: TextStyle(color: AppTheme.textMuted)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: state.sets.length,
                    itemBuilder: (context, index) {
                      final set = state.sets[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGold.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4)),
                            ),
                            child: Text(
                              set.setCode,
                              style: const TextStyle(
                                color: AppTheme.primaryGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          title: Text(
                            set.setName,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              if (set.numOfCards != null)
                                Text(
                                  '${set.numOfCards} cartas',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                ),
                              if (set.tcgDate != null) ...[
                                const Text(' • ', style: TextStyle(color: AppTheme.textMuted)),
                                Text(
                                  set.tcgDate!,
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                          onTap: () {
                            context.push('/sets/${set.setCode}?name=${Uri.encodeComponent(set.setName)}');
                          },
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
