// lib/presentation/screens/settings/settings_screen.dart
// ----------------------------------------
// Settings, Offline Database Manager, and Sync Panel.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/sync_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    final syncNotifier = ref.read(syncProvider.notifier);
    final authNotifier = ref.read(authProvider.notifier);
    final onlineAsync = ref.watch(isOnlineProvider);
    final isOnline = onlineAsync.value ?? true;

    final progress = syncState.progress;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Configuración y Sincronización'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Network & Sync Section
          _buildSectionHeader('ESTADO DE LA RED Y SINCRONIZACIÓN'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Conexión de red', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                    Row(
                      children: [
                        Icon(
                          isOnline ? Icons.wifi : Icons.wifi_off,
                          size: 16,
                          color: isOnline ? AppTheme.success : AppTheme.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOnline ? 'En línea' : 'Sin conexión',
                          style: TextStyle(
                            color: isOnline ? AppTheme.success : AppTheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(color: AppTheme.cardBorder, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Cambios pendientes en cola offline', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: syncState.pendingMutationsCount > 0 ? AppTheme.warning.withOpacity(0.2) : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${syncState.pendingMutationsCount}',
                        style: TextStyle(
                          color: syncState.pendingMutationsCount > 0 ? AppTheme.warning : AppTheme.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (syncState.pendingMutationsCount > 0 && isOnline) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => syncNotifier.flushOfflineQueue(),
                      icon: const Icon(Icons.cloud_upload_outlined, color: AppTheme.primaryGold),
                      label: const Text('Forzar sincronización ahora', style: TextStyle(color: AppTheme.primaryGold)),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // SQLite Database Section
          _buildSectionHeader('BASE DE DATOS LOCAL OFFLINE'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Catálogo SQLite Lite (~13.000 cartas)',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Permite reconocimiento OCR y búsqueda de cartas sin necesidad de internet.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),

                if (progress.status == SyncStatus.downloading || progress.status == SyncStatus.installing) ...[
                  LinearProgressIndicator(
                    value: progress.progress > 0 ? progress.progress : null,
                    backgroundColor: AppTheme.surfaceVariant,
                    color: AppTheme.primaryGold,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    progress.message ?? 'Descargando base de datos...',
                    style: const TextStyle(color: AppTheme.primaryGold, fontSize: 12),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isOnline ? () => syncNotifier.triggerDatabaseDownload() : null,
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Descargar / Actualizar BD'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // API Server Info
          _buildSectionHeader('SERVIDOR BACKEND'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('URL Base', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                Text(
                  AppConstants.baseUrl,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Logout Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error.withOpacity(0.15),
              foregroundColor: AppTheme.error,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppTheme.error),
            ),
            onPressed: () async {
              await authNotifier.logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.primaryGold,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
