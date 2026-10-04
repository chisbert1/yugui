// lib/presentation/widgets/stats_header.dart
// ----------------------------------------
// Collection statistics header card with gold gradients and metrics.

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/inventory_stats_model.dart';

class StatsHeader extends StatelessWidget {
  final InventoryStatsModel stats;

  const StatsHeader({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2235), Color(0xFF141724)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.style, color: AppTheme.primaryGold, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Mi Colección',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4)),
                ),
                child: Text(
                  '${stats.uniqueCards} únicas',
                  style: const TextStyle(
                    color: AppTheme.primaryGold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatMetric('Total Cartas', '${stats.totalCards}', Icons.layers_outlined),
              _buildDivider(),
              _buildStatMetric(
                'Valor Est. (TCG)',
                '\$${stats.estimatedValueTcg.toStringAsFixed(2)}',
                Icons.monetization_on_outlined,
                valueColor: AppTheme.success,
              ),
              _buildDivider(),
              _buildStatMetric(
                'Wishlist',
                '${stats.wishlistCount}',
                Icons.favorite_outline,
                valueColor: Colors.pinkAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 36,
      width: 1,
      color: AppTheme.cardBorder,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildStatMetric(String label, String value, IconData icon, {Color? valueColor}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
