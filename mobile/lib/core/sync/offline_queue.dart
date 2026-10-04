// lib/core/sync/offline_queue.dart
// ----------------------------------------
// Offline Queue Manager.
// Queues mutations (add card, update quantity, remove) when device is offline.
// Processes queued items in FIFO order when connectivity is restored.

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../data/datasources/local/database_helper.dart';
import '../network/api_client.dart';
import '../network/connectivity_service.dart';

enum QueueAction { addCard, updateInventory, deleteInventory }

class QueuedMutation {
  final int? id;
  final QueueAction action;
  final String endpoint;
  final String method;
  final Map<String, dynamic> payload;
  final int createdAt;
  final int retryCount;

  QueuedMutation({
    this.id,
    required this.action,
    required this.endpoint,
    required this.method,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'action': action.name,
        'endpoint': endpoint,
        'method': method,
        'payload': jsonEncode(payload),
        'created_at': createdAt,
        'retry_count': retryCount,
      };

  factory QueuedMutation.fromMap(Map<String, dynamic> map) => QueuedMutation(
        id: map['id'] as int?,
        action: QueueAction.values.byName(map['action'] as String),
        endpoint: map['endpoint'] as String,
        method: map['method'] as String,
        payload: jsonDecode(map['payload'] as String) as Map<String, dynamic>,
        createdAt: map['created_at'] as int,
        retryCount: (map['retry_count'] as int?) ?? 0,
      );
}

class OfflineQueueManager {
  static final OfflineQueueManager _instance = OfflineQueueManager._internal();
  factory OfflineQueueManager() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ApiClient _apiClient = ApiClient();
  final ConnectivityService _connectivity = ConnectivityService();

  bool _isProcessing = false;

  OfflineQueueManager._internal() {
    _connectivity.onConnectivityChanged.listen((online) {
      if (online) {
        processQueue();
      }
    });
  }

  /// Adds a mutation to the local pending_operations queue
  Future<void> enqueue({
    required QueueAction action,
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _dbHelper.inventoryDatabase;
    final mutation = QueuedMutation(
      action: action,
      endpoint: endpoint,
      method: method,
      payload: payload,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await db.insert('pending_mutations', mutation.toMap());

    // If online right now, attempt to process immediately
    if (_connectivity.isOnline) {
      processQueue();
    }
  }

  /// Returns count of pending operations
  Future<int> getPendingCount() async {
    final db = await _dbHelper.inventoryDatabase;
    final res = await db.rawQuery('SELECT COUNT(*) as count FROM pending_mutations');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Flushes pending mutations to the backend
  Future<void> processQueue() async {
    if (_isProcessing || !_connectivity.isOnline) return;
    _isProcessing = true;

    try {
      final db = await _dbHelper.inventoryDatabase;
      final rows = await db.query(
        'pending_mutations',
        orderBy: 'created_at ASC',
        limit: 50,
      );

      for (final row in rows) {
        final mutation = QueuedMutation.fromMap(row);
        try {
          if (mutation.method == 'POST') {
            await _apiClient.dio.post(mutation.endpoint, data: mutation.payload);
          } else if (mutation.method == 'PUT') {
            await _apiClient.dio.put(mutation.endpoint, data: mutation.payload);
          } else if (mutation.method == 'DELETE') {
            await _apiClient.dio.delete(mutation.endpoint, data: mutation.payload);
          }

          // Successfully processed: remove from queue
          await db.delete('pending_mutations', where: 'id = ?', whereArgs: [mutation.id]);
        } catch (e) {
          // If server rejects permanently or network fails, increment retry count
          if (mutation.retryCount >= 5) {
            // Drop persistently failing poison pill item
            await db.delete('pending_mutations', where: 'id = ?', whereArgs: [mutation.id]);
          } else {
            await db.update(
              'pending_mutations',
              {'retry_count': mutation.retryCount + 1},
              where: 'id = ?',
              whereArgs: [mutation.id],
            );
          }
        }
      }
    } finally {
      _isProcessing = false;
    }
  }
}
