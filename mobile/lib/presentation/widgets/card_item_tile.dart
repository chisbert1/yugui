// lib/presentation/widgets/card_item_tile.dart
// ----------------------------------------
// Card item tile with artwork, rarity badge, edition, quantity stepper, and price.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/inventory_item_model.dart';

class CardItemTile extends StatelessWidget {
  final InventoryItemModel item;
  final VoidCallback? onTap;
  final ValueChanged<int>? onQuantityChanged;
  final VoidCallback? onDelete;

  const CardItemTile({
    super.key,
    required this.item,
    this.onTap,
    this.onQuantityChanged,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Card image thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 50,
                  height: 72,
                  child: item.imageUrlSmall != null && item.imageUrlSmall!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.imageUrlSmall!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppTheme.surfaceVariant,
                            child: const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGold),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Set Code badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.5)),
                          ),
                          child: Text(
                            item.setCode,
                            style: const TextStyle(
                              color: AppTheme.primaryGold,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (item.rarity != null)
                          Flexible(
                            child: Text(
                              item.rarity!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          item.edition,
                          style: TextStyle(
                            color: item.edition == '1st Edition' ? AppTheme.goldLight : AppTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${item.condition}',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                        if (item.price != null && item.price! > 0) ...[
                          const Spacer(),
                          Text(
                            '\$${item.price!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppTheme.success,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Quantity Stepper
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildQuantityButton(
                        icon: Icons.remove,
                        onPressed: () => onQuantityChanged?.call(-1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _buildQuantityButton(
                        icon: Icons.add,
                        onPressed: () => onQuantityChanged?.call(1),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.surfaceVariant,
      child: const Center(
        child: Icon(Icons.crop_portrait, color: AppTheme.textMuted, size: 28),
      ),
    );
  }

  Widget _buildQuantityButton({required IconData icon, required VoidCallback onPressed}) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 16, color: AppTheme.primaryGold),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: AppTheme.surfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}
