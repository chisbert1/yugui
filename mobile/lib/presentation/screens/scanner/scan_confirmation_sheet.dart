// lib/presentation/screens/scanner/scan_confirmation_sheet.dart
// ----------------------------------------
// Bottom sheet presented upon successful OCR detection.
// Allows user to pick Edition (1st Ed / Unlimited), Condition, and Quantity.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/card_set_link_model.dart';
import '../../providers/inventory_provider.dart';

class ScanConfirmationSheet extends StatefulWidget {
  final CardSetLinkModel cardInfo;
  final VoidCallback onDismissed;

  const ScanConfirmationSheet({
    super.key,
    required this.cardInfo,
    required this.onDismissed,
  });

  @override
  State<ScanConfirmationSheet> createState() => _ScanConfirmationSheetState();
}

class _ScanConfirmationSheetState extends State<ScanConfirmationSheet> {
  String _selectedEdition = AppConstants.cardEditions.first;
  String _selectedCondition = AppConstants.cardConditions[1]; // Near Mint
  int _quantity = 1;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final card = widget.cardInfo;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 70,
                    height: 102,
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
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.cardName ?? 'Carta Reconocida',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGold.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.primaryGold),
                            ),
                            child: Text(
                              card.setCode,
                              style: const TextStyle(
                                color: AppTheme.primaryGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (card.setRarity != null)
                            Flexible(
                              child: Text(
                                card.setRarity!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        card.setName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                      if (card.setPrice != null && card.setPrice! > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Precio Est.: \$${card.setPrice!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppTheme.success,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(color: AppTheme.cardBorder),
            const SizedBox(height: 12),

            // Edition Selector
            Row(
              children: [
                const SizedBox(
                  width: 90,
                  child: Text(
                    'Edición:',
                    style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedEdition,
                    dropdownColor: AppTheme.surfaceVariant,
                    items: AppConstants.cardEditions
                        .map((ed) => DropdownMenuItem(value: ed, child: Text(ed)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedEdition = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Condition Selector
            Row(
              children: [
                const SizedBox(
                  width: 90,
                  child: Text(
                    'Estado:',
                    style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCondition,
                    dropdownColor: AppTheme.surfaceVariant,
                    items: AppConstants.cardConditions
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCondition = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quantity Stepper
            Row(
              children: [
                const SizedBox(
                  width: 90,
                  child: Text(
                    'Cantidad:',
                    style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primaryGold),
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                ),
                Text(
                  '$_quantity',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryGold),
                  onPressed: () => setState(() => _quantity++),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Consumer(
              builder: (context, ref, child) {
                return ElevatedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          await ref.read(inventoryProvider.notifier).addCard(
                                setCode: card.setCode,
                                edition: _selectedEdition,
                                condition: _selectedCondition,
                                quantity: _quantity,
                                cardInfo: card,
                              );
                          if (mounted) {
                            Navigator.pop(context);
                            widget.onDismissed();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppTheme.surfaceVariant,
                                content: Text(
                                  '¡${card.cardName ?? card.setCode} añadido a tu colección!',
                                  style: const TextStyle(color: AppTheme.primaryGold),
                                ),
                              ),
                            );
                          }
                        },
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.add_task),
                  label: Text(_isSaving ? 'Guardando...' : 'Añadir a mi Colección'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
