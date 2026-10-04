// lib/presentation/screens/cards/card_detail_screen.dart
// ----------------------------------------
// Comprehensive Card Detail Screen:
// Artwork, Attributes, Monster Stats, Effect Text, Market Prices, Printings List.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/card_model.dart';
import '../../../data/models/card_set_link_model.dart';
import '../../providers/card_search_provider.dart';
import '../scanner/scan_confirmation_sheet.dart';

class CardDetailScreen extends ConsumerStatefulWidget {
  final int cardId;

  const CardDetailScreen({super.key, required this.cardId});

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  CardModel? _card;
  List<CardSetLinkModel> _printings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = ref.read(cardRepositoryProvider);
    final printings = await repo.getCardPrintings(widget.cardId);

    // Look up card details
    setState(() {
      _printings = printings;
      if (printings.isNotEmpty) {
        final p = printings.first;
        _card = CardModel(
          id: p.cardId,
          name: p.cardName ?? 'Desconocida',
          imageUrl: p.imageUrl ?? p.imageUrlSmall,
          imageUrlSmall: p.imageUrlSmall,
          type: p.type,
          desc: p.desc,
          atk: p.atk,
          def: p.def,
          level: p.level,
          attribute: p.attribute,
          tcgplayerPrice: p.setPrice,
        );
      }
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGold)),
      );
    }

    final card = _card;
    if (card == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(),
        body: const Center(child: Text('Carta no encontrada', style: TextStyle(color: AppTheme.textMuted))),
      );
    }

    final attrColor = AppTheme.getAttributeColor(card.attribute);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(card.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Center High-Res Card Artwork
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 220,
                  height: 320,
                  child: card.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: card.imageUrl!,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => Container(color: AppTheme.surfaceVariant),
                          errorWidget: (_, __, ___) => Container(
                            color: AppTheme.surfaceVariant,
                            child: const Icon(Icons.broken_image, size: 48, color: AppTheme.textMuted),
                          ),
                        )
                      : Container(color: AppTheme.surfaceVariant),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Attribute, Level, Type Badges
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (card.attribute != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: attrColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: attrColor),
                    ),
                    child: Text(
                      card.attribute!,
                      style: TextStyle(color: attrColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                if (card.level != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.primaryGold),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: AppTheme.primaryGold),
                        const SizedBox(width: 4),
                        Text(
                          'Nivel ${card.level}',
                          style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                if (card.type != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      card.type!,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // ATK / DEF box
            if (card.atk != null || card.def != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      'ATK / ${card.atk ?? '?' }',
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Container(height: 20, width: 1, color: AppTheme.cardBorder),
                    Text(
                      'DEF / ${card.def ?? '?' }',
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Card Text / Description
            if (card.desc != null && card.desc!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Texto de la Carta',
                      style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      card.desc!,
                      style: const TextStyle(color: AppTheme.textPrimary, height: 1.4, fontSize: 13),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Printings / Sets Header
            const Text(
              'Ediciones e Impresiones',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            ..._printings.map((p) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.primaryGold),
                      ),
                      child: Text(
                        p.setCode,
                        style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.setName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            p.setRarity ?? 'Common',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (p.setPrice != null && p.setPrice! > 0)
                      Text(
                        '\$${p.setPrice!.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: AppTheme.primaryGold, size: 24),
                      tooltip: 'Añadir esta edición',
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ScanConfirmationSheet(
                            cardInfo: p,
                            onDismissed: () {},
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
