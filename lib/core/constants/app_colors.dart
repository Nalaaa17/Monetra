import 'package:flutter/material.dart';

class AppColors {
  // Brand & Accent Colors
  static const Color primary = Color(0xFFFFB800);
  static const Color primaryDark = Color(0xFFF59E0B);
  static const Color secondary = Color(0xFF38BDF8);
  static const Color tertiary = Color(0xFF34D399);
  static const Color danger = Color(0xFFF87171);

  // Light Theme Surfaces & Text (Default)
  static const Color surface = Color(0xFFFFFDF7);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);

  // Dark Theme Surfaces & Text (High Contrast & Comfortable)
  static const Color darkSurface = Color(0xFF0F172A); // Slate 900
  static const Color darkSurfaceCard = Color(0xFF1E293B); // Slate 800
  static const Color darkSurfaceElevated = Color(0xFF334155); // Slate 700
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Slate 50 (Sangat kontras & jelas)
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400 (Kontras lembut & nyaman)
  static const Color darkDivider = Color(0xFF334155); // Slate 700

  // Helper adaptif terhadap context tema
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? darkSurface : surface;

  static Color cardOf(BuildContext context) =>
      isDark(context) ? darkSurfaceCard : surfaceCard;

  static Color dividerOf(BuildContext context) =>
      isDark(context) ? darkDivider : divider;

  // Account specific colors
  static const Color seabank = Color(0xFF00B0FF);
  static const Color mandiri = Color(0xFF0B579E);
  static const Color mandiriGold = Color(0xFFF59E0B);
  static const Color cash = Color(0xFF10B981);
}
