// lib/main.dart
// ----------------------------------------
// Application entry point for Yu-Gi-Oh! Collector.
// Initializes SQLite databases, Riverpod state, and launches the app.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/sync/sync_manager.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/local/database_helper.dart';
import 'presentation/navigation/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize SQLite databases
  final dbHelper = DatabaseHelper();
  await dbHelper.cardDatabase;
  await dbHelper.inventoryDatabase;

  // Background check for newer SQLite dump from server
  SyncManager().checkForUpdates().then((hasUpdate) {
    if (hasUpdate) {
      SyncManager().downloadAndInstallDatabase();
    }
  });

  runApp(
    const ProviderScope(
      child: YuGiOhCollectorApp(),
    ),
  );
}

class YuGiOhCollectorApp extends ConsumerWidget {
  const YuGiOhCollectorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Yu-Gi-Oh! Collector',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
