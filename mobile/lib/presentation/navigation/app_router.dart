// lib/presentation/navigation/app_router.dart
// ----------------------------------------
// GoRouter navigation system with BottomNavigationBar shell,
// auth redirection guard, and detail screens.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/cards/card_detail_screen.dart';
import '../screens/cards/card_search_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/scanner/scanner_screen.dart';
import '../screens/sets/set_detail_screen.dart';
import '../screens/sets/sets_screen.dart';
import '../screens/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggingIn = state.matchedLocation == '/login';
      if (authState.status == AuthStatus.unauthenticated) {
        return isLoggingIn ? null : '/login';
      }
      if (authState.status == AuthStatus.authenticated && isLoggingIn) {
        return '/';
      }
      return null;
    },
    routes: [
      // Auth Route
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Standalone Fullscreen Camera Scanner
      GoRoute(
        path: '/scanner',
        builder: (context, state) => const ScannerScreen(),
      ),

      // Card Detail Screen
      GoRoute(
        path: '/cards/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
          return CardDetailScreen(cardId: id);
        },
      ),

      // Set Detail Screen
      GoRoute(
        path: '/sets/:code',
        builder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          final name = state.uri.queryParameters['name'];
          return SetDetailScreen(setCode: code, setName: name);
        },
      ),

      // Main Navigation Shell with BottomNavigationBar
      ShellRoute(
        builder: (context, state, child) {
          final location = state.matchedLocation;
          int currentIndex = 0;
          if (location.startsWith('/search')) {
            currentIndex = 1;
          } else if (location.startsWith('/sets')) {
            currentIndex = 2;
          } else if (location.startsWith('/settings')) {
            currentIndex = 3;
          }

          return Scaffold(
            body: child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) {
                switch (index) {
                  case 0:
                    context.go('/');
                    break;
                  case 1:
                    context.go('/search');
                    break;
                  case 2:
                    context.go('/sets');
                    break;
                  case 3:
                    context.go('/settings');
                    break;
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.style_outlined),
                  selectedIcon: Icon(Icons.style, color: AppTheme.primaryGold),
                  label: 'Mi Álbum',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon: Icon(Icons.search, color: AppTheme.primaryGold),
                  label: 'Catálogo',
                ),
                NavigationDestination(
                  icon: Icon(Icons.layers_outlined),
                  selectedIcon: Icon(Icons.layers, color: AppTheme.primaryGold),
                  label: 'Expansiones',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings, color: AppTheme.primaryGold),
                  label: 'Ajustes',
                ),
              ],
            ),
          );
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const CardSearchScreen(),
          ),
          GoRoute(
            path: '/sets',
            builder: (context, state) => const SetsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
