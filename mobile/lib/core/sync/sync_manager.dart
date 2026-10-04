// lib/core/sync/sync_manager.dart
// ----------------------------------------
// Handles downloading, hash verification, and hot-swapping
// of the SQLite Lite card database from the backend.

import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/datasources/local/database_helper.dart';
import '../constants/app_constants.dart';
import '../network/api_client.dart';

enum SyncStatus { idle, checking, downloading, installing, completed, failed }

class SyncProgress {
  final SyncStatus status;
  final double progress; // 0.0 to 1.0
  final String? message;

  const SyncProgress({
    required this.status,
    this.progress = 0.0,
    this.message,
  });
}

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  final ApiClient _apiClient = ApiClient();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  SyncProgress _currentProgress = const SyncProgress(status: SyncStatus.idle);
  SyncProgress get currentProgress => _currentProgress;

  final List<void Function(SyncProgress)> _listeners = [];

  void addListener(void Function(SyncProgress) listener) {
    _listeners.add(listener);
    listener(_currentProgress);
  }

  void removeListener(void Function(SyncProgress) listener) {
    _listeners.remove(listener);
  }

  void _notify(SyncStatus status, [double progress = 0.0, String? message]) {
    _currentProgress = SyncProgress(status: status, progress: progress, message: message);
    for (final l in _listeners) {
      l(_currentProgress);
    }
  }

  /// Checks if a new SQLite DB version is available on the backend
  Future<bool> checkForUpdates() async {
    try {
      _notify(SyncStatus.checking, 0.0, 'Comprobando actualizaciones de cartas...');
      final response = await _apiClient.dio.head('/sync/database/lite');
      
      final remoteHash = response.headers.value('x-database-sha256') ?? response.headers.value('etag');
      if (remoteHash == null) {
        _notify(SyncStatus.idle);
        return false;
      }

      final localHash = await _storage.read(key: AppConstants.keyDbHash);
      final hasUpdate = localHash != remoteHash;
      _notify(SyncStatus.idle);
      return hasUpdate;
    } catch (_) {
      _notify(SyncStatus.idle);
      return false;
    }
  }

  /// Downloads the updated SQLite database and swaps it safely
  Future<bool> downloadAndInstallDatabase() async {
    try {
      _notify(SyncStatus.downloading, 0.0, 'Descargando base de datos de cartas...');
      
      final targetPath = await _dbHelper.getCardDbPath();
      final tempPath = '$targetPath.tmp';

      String? expectedSha256;

      final response = await _apiClient.dio.download(
        '/sync/database/lite',
        tempPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            _notify(SyncStatus.downloading, progress, 'Descargando cartas: ${(progress * 100).toInt()}%');
          }
        },
      );

      expectedSha256 = response.headers.value('x-database-sha256');

      // Verify file integrity
      _notify(SyncStatus.installing, 0.9, 'Verificando integridad...');
      final tempFile = File(tempPath);
      if (!await tempFile.exists()) {
        throw Exception('Download failed, temp file missing');
      }

      if (expectedSha256 != null && expectedSha256.isNotEmpty) {
        final bytes = await tempFile.readAsBytes();
        final actualDigest = sha256.convert(bytes).toString();
        if (actualDigest.toLowerCase() != expectedSha256.toLowerCase()) {
          await tempFile.delete();
          throw Exception('SHA-256 mismatch: corrupted download');
        }
      }

      // Hot swap DB connection
      _notify(SyncStatus.installing, 0.95, 'Instalando catálogo...');
      await _dbHelper.resetCardDbConnection();

      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetPath);

      // Save new hash
      if (expectedSha256 != null) {
        await _storage.write(key: AppConstants.keyDbHash, value: expectedSha256);
      }

      _notify(SyncStatus.completed, 1.0, '¡Catálogo de cartas actualizado!');
      return true;
    } catch (e) {
      _notify(SyncStatus.failed, 0.0, 'Error al sincronizar: $e');
      return false;
    }
  }
}
