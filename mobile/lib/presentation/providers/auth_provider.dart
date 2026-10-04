// lib/presentation/providers/auth_provider.dart
// ----------------------------------------
// Auth state notifier for user session tracking.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
  });

  AuthState copyWith({AuthStatus? status, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AuthState()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    final loggedIn = await _repo.isLoggedIn();
    state = state.copyWith(
      status: loggedIn ? AuthStatus.authenticated : AuthStatus.unauthenticated,
    );
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final success = await _repo.login(email: email, password: password);
      if (success) {
        state = state.copyWith(status: AuthStatus.authenticated);
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Credenciales inválidas',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Error al iniciar sesión: $e',
      );
      return false;
    }
  }

  Future<bool> register(String email, String username, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final success = await _repo.register(email: email, username: username, password: password);
      if (success) {
        return await login(email, password);
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'El usuario o email ya existe',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Error en el registro: $e',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});
