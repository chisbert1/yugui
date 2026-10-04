// lib/data/repositories/auth_repository.dart
// ----------------------------------------
// Handles user authentication, token storage, and session validation.

import '../../core/network/api_client.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  Future<bool> register({required String email, required String username, required String password}) async {
    final response = await _apiClient.dio.post('/auth/register', data: {
      'email': email,
      'username': username,
      'password': password,
    });
    return response.statusCode == 201;
  }

  Future<bool> login({required String email, required String password}) async {
    final response = await _apiClient.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final accessToken = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String? ?? '';
      final user = data['user'] as Map<String, dynamic>?;
      final userId = user?['id']?.toString() ?? '1';

      await _apiClient.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: userId,
      );
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    await _apiClient.clearAuth();
  }

  Future<bool> isLoggedIn() => _apiClient.isAuthenticated();
}
