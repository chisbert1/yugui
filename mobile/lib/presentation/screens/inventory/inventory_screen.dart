// lib/presentation/screens/inventory/inventory_screen.dart
// ----------------------------------------
// Main collection binder screen.
// Displays inventory, stats header, filters, and FAB to open scanner.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/card_item_tile.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/stats_header.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final notifier = ref.read(inventoryProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Mi Álbum Yu-Gi-Oh!'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: AppTheme.primaryGold),
            tooltip: 'Sincronizar con servidor',
            onPressed: () => notifier.syncRemote(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          StatsHeader(stats: state.stats),

          // Search and Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => notifier.setSearchQuery(val),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o set code...',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                notifier.setSearchQuery('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Wishlist ❤️'),
                  selected: state.wishlistOnly,
                  onSelected: (_) => notifier.toggleWishlistFilter(),
                  selectedColor: AppTheme.primaryGold.withOpacity(0.2),
                  checkmarkColor: AppTheme.primaryGold,
                  labelStyle: TextStyle(
                    color: state.wishlistOnly ? AppTheme.primaryGold : AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                ...AppConstants.cardEditions.map((edition) {
                  final isSelected = state.editionFilter == edition;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(edition),
                      selected: isSelected,
                      onSelected: (selected) {
                        notifier.setEditionFilter(selected ? edition : null);
                      },
                      selectedColor: AppTheme.primaryGold.withOpacity(0.2),
                      checkmarkColor: AppTheme.primaryGold,
                      labelStyle: TextStyle(
                        color: isSelected ? AppTheme.primaryGold : AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Collection List
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
                : state.items.isEmpty
                    ? _buildEmptyState(context)
                    : RefreshIndicator(
                        color: AppTheme.primaryGold,
                        backgroundColor: AppTheme.surface,
                        onRefresh: () => notifier.loadInventory(),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: state.items.length,
                          itemBuilder: (context, index) {
                            final item = state.items[index];
                            return CardItemTile(
                              item: item,
                              onQuantityChanged: (delta) {
                                notifier.updateQuantity(item, delta);
                              },
                              onTap: () {
                                context.push('/cards/${item.cardId}');
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryGold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Escanear', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => context.push('/scanner'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.style_outlined, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          const Text(
            'Tu colección está vacía',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Usa la cámara para escanear cartas físicas o busca en el catálogo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.push('/scanner'),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Comenzar a Escanear'),
          ),
        ],
      ),
    );
  }
}
