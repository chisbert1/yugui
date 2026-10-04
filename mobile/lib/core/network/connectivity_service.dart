// lib/core/network/connectivity_service.dart
// ----------------------------------------
// Real-time network connectivity monitoring with Stream.

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  bool _isOnline = true;
  bool get isOnline => _isOnline;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  ConnectivityService._internal() {
    _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((result) => result != ConnectivityResult.none);
      if (_isOnline != online) {
        _isOnline = online;
        _controller.add(online);
      }
    });
    // Check initial state
    _checkInitial();
  }

  Future<void> _checkInitial() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    _controller.add(_isOnline);
  }

  void dispose() {
    _controller.close();
  }
}
