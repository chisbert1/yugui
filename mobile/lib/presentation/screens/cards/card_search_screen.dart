// lib/presentation/screens/cards/card_search_screen.dart
// ----------------------------------------
// Fast local catalog search across all Yu-Gi-Oh! cards.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/card_search_provider.dart';

class CardSearchScreen extends ConsumerStatefulWidget {
  const CardSearchScreen({super.key});

  @override
  ConsumerState<CardSearchScreen> createState() => _CardSearchScreenState();
}

class _CardSearchScreenState extends ConsumerState<CardSearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cardSearchProvider);
    final notifier = ref.read(cardSearchProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Catálogo de Cartas'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              onChanged: (val) => notifier.search(val),
              decoration: InputDecoration(
                hintText: 'Buscar carta por nombre (ej: Dark Magician, Blue-Eyes)...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          notifier.search('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Results Grid
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
                : state.cards.isEmpty
                    ? const Center(
                        child: Text(
                          'No se encontraron cartas en el catálogo',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: state.cards.length,
                        itemBuilder: (context, index) {
                          final card = state.cards[index];
                          return InkWell(
                            onTap: () => context.push('/cards/${card.id}'),
                            borderRadius: BorderRadius.circular(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: card.imageUrlSmall != null
                                        ? CachedNetworkImage(
                                            imageUrl: card.imageUrlSmall!,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(color: AppTheme.surfaceVariant),
                                            errorWidget: (_, __, ___) => Container(
                                              color: AppTheme.surfaceVariant,
                                              child: const Icon(Icons.broken_image, color: AppTheme.textMuted),
                                            ),
                                          )
                                        : Container(color: AppTheme.surfaceVariant),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  card.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
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
