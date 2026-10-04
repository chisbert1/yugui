// lib/presentation/providers/sync_provider.dart
// ----------------------------------------
// StateNotifier for catalog SQLite download & sync progress.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sync/offline_queue.dart';
import '../../core/sync/sync_manager.dart';

class SyncState {
  final SyncProgress progress;
  final int pendingMutationsCount;
  final bool hasUpdateAvailable;

  const SyncState({
    required this.progress,
    this.pendingMutationsCount = 0,
    this.hasUpdateAvailable = false,
  });

  SyncState copyWith({
    SyncProgress? progress,
    int? pendingMutationsCount,
    bool? hasUpdateAvailable,
  }) {
    return SyncState(
      progress: progress ?? this.progress,
      pendingMutationsCount: pendingMutationsCount ?? this.pendingMutationsCount,
      hasUpdateAvailable: hasUpdateAvailable ?? this.hasUpdateAvailable,
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  final SyncManager _syncManager = SyncManager();
  final OfflineQueueManager _queueManager = OfflineQueueManager();

  SyncNotifier() : super(SyncState(progress: SyncManager().currentProgress)) {
    _syncManager.addListener(_onProgressUpdated);
    _checkPendingCount();
  }

  void _onProgressUpdated(SyncProgress progress) {
    state = state.copyWith(progress: progress);
  }

  Future<void> _checkPendingCount() async {
    final count = await _queueManager.getPendingCount();
    state = state.copyWith(pendingMutationsCount: count);
  }

  Future<void> checkForUpdates() async {
    final update = await _syncManager.checkForUpdates();
    state = state.copyWith(hasUpdateAvailable: update);
  }

  Future<bool> triggerDatabaseDownload() async {
    final success = await _syncManager.downloadAndInstallDatabase();
    if (success) {
      state = state.copyWith(hasUpdateAvailable: false);
    }
    return success;
  }

  Future<void> flushOfflineQueue() async {
    await _queueManager.processQueue();
    await _checkPendingCount();
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier();
});
