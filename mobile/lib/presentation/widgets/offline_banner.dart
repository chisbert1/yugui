// lib/presentation/widgets/offline_banner.dart
// ----------------------------------------
// Real-time offline indicator banner displayed at top of screens.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';
import '../providers/sync_provider.dart';
import '../../core/theme/app_theme.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineAsync = ref.watch(isOnlineProvider);
    final syncState = ref.watch(syncProvider);
    final isOnline = onlineAsync.value ?? true;

    if (isOnline && syncState.pendingMutationsCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isOnline ? AppTheme.info.withOpacity(0.9) : AppTheme.warning.withOpacity(0.9),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              isOnline ? Icons.sync : Icons.cloud_off,
              size: 16,
              color: Colors.black,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                !isOnline
                    ? 'Modo Offline: Leyendo de base de datos local (${syncState.pendingMutationsCount} cambios pendientes)'
                    : 'Sincronizando ${syncState.pendingMutationsCount} cambios con el servidor...',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isOnline && syncState.pendingMutationsCount > 0)
              GestureDetector(
                onTap: () => ref.read(syncProvider.notifier).flushOfflineQueue(),
                child: const Text(
                  'SYNC',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
