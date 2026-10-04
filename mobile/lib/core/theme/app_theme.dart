// lib/core/theme/app_theme.dart
// ----------------------------------------
// Premium Yu-Gi-Oh! themed dark design system.
// Egyptian Gold (#F5C518), Duelist Obsidian (#0D0E15), Card Attribute Colors.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Brand Colors ──────────────────────────────────────────────────────────
  static const Color primaryGold = Color(0xFFFFD700);
  static const Color goldDark = Color(0xFFC5A000);
  static const Color goldLight = Color(0xFFFFF176);

  static const Color background = Color(0xFF0F111A);
  static const Color surface = Color(0xFF181B26);
  static const Color surfaceVariant = Color(0xFF222636);
  static const Color cardBorder = Color(0xFF2E344D);

  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // ── Status Colors ─────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Yu-Gi-Oh! Card Attribute Colors ───────────────────────────────────────
  static const Color attrDark = Color(0xFF7B1FA2);
  static const Color attrLight = Color(0xFFFBC02D);
  static const Color attrEarth = Color(0xFF8D6E63);
  static const Color attrFire = Color(0xFFE53935);
  static const Color attrWater = Color(0xFF1E88E5);
  static const Color attrWind = Color(0xFF43A047);
  static const Color attrDivine = Color(0xFFFFB300);
  static const Color attrSpell = Color(0xFF00897B);
  static const Color attrTrap = Color(0xFFC2185B);

  // ── Yu-Gi-Oh! Card Frame Colors ───────────────────────────────────────────
  static const Color frameNormal = Color(0xFFD4A373);
  static const Color frameEffect = Color(0xFFC75B26);
  static const Color frameFusion = Color(0xFF7E38B7);
  static const Color frameSynchro = Color(0xFFEDE8E1);
  static const Color frameXyz = Color(0xFF1A1A1A);
  static const Color frameLink = Color(0xFF1263CE);
  static const Color frameRitual = Color(0xFF4A89DC);

  static Color getAttributeColor(String? attr) {
    if (attr == null) return textMuted;
    switch (attr.toUpperCase()) {
      case 'DARK': return attrDark;
      case 'LIGHT': return attrLight;
      case 'EARTH': return attrEarth;
      case 'FIRE': return attrFire;
      case 'WATER': return attrWater;
      case 'WIND': return attrWind;
      case 'DIVINE': return attrDivine;
      case 'SPELL': return attrSpell;
      case 'TRAP': return attrTrap;
      default: return textMuted;
    }
  }

  // ── Dark Theme Data ───────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.interTextTheme(
      const TextTheme(
        headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textPrimary),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: textSecondary),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryGold),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryGold,
      colorScheme: const ColorScheme.dark(
        primary: primaryGold,
        secondary: goldDark,
        surface: surface,
        error: error,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primaryGold),
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        hintStyle: const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryGold, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGold,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primaryGold.withOpacity(0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryGold);
          }
          return const IconThemeData(color: textSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primaryGold, fontWeight: FontWeight.w600, fontSize: 11);
          }
          return const TextStyle(color: textSecondary, fontSize: 11);
        }),
      ),
    );
  }
}
