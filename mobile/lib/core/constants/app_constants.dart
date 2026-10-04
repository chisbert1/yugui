// lib/core/constants/app_constants.dart
// ----------------------------------------
// Centralised constants to avoid magic strings throughout the app.

class AppConstants {
  AppConstants._();

  // ── API ──────────────────────────────────────────────────────────────────
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1'; // Android emulator
  // static const String baseUrl = 'http://localhost:8000/api/v1'; // iOS simulator
  // static const String baseUrl = 'https://your-production-api.com/api/v1';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ── Local DB ──────────────────────────────────────────────────────────────
  static const String localDbName = 'yugioh_lite.db';
  static const String inventoryDbName = 'inventory.db';
  static const int localDbVersion = 1;

  // ── Cache ────────────────────────────────────────────────────────────────
  static const Duration imageCacheTtl = Duration(days: 7);
  static const int maxImageCacheItems = 500;

  // ── OCR ──────────────────────────────────────────────────────────────────
  static const int ocrFrameIntervalMs = 500; // max 2 fps for OCR processing
  static const double ocrMinConfidence = 0.75;

  // ── Secure Storage Keys ───────────────────────────────────────────────────
  static const String keyAccessToken  = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId       = 'user_id';
  static const String keyDbHash       = 'db_hash'; // SHA-256 of last SQLite download

  // ── Card Editions ─────────────────────────────────────────────────────────
  static const List<String> cardEditions = ['1st Edition', 'Unlimited', 'Limited'];

  // ── Card Conditions ───────────────────────────────────────────────────────
  static const List<String> cardConditions = [
    'Mint',
    'Near Mint',
    'Lightly Played',
    'Moderately Played',
    'Heavily Played',
    'Damaged',
  ];
}
