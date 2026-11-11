import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';

/// Menyediakan ThemeMode awal hasil pembacaan saat startup (`main.dart`).
final initialThemeModeProvider = Provider<ThemeMode>((ref) {
  return ThemeMode.light;
});

class ThemeModeController extends StateController<ThemeMode> {
  static const String settingKey = 'theme_mode';

  ThemeModeController([super.state = ThemeMode.light]);

  @override
  set state(ThemeMode value) {
    if (super.state == value) return;
    super.state = value;
    unawaited(persistThemeMode(value));
  }

  /// Menyimpan preferensi tema ke tabel lokal `app_settings` bila DB aktif.
  static Future<void> persistThemeMode(ThemeMode mode) async {
    try {
      if (!AppDatabase.isOpen) return;
      await AppDatabase.setSetting(
        settingKey,
        mode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {}
  }

  /// Membaca preferensi tema terakhir yang tersimpan di penyimpanan lokal.
  static Future<ThemeMode> readSavedThemeMode() async {
    try {
      final raw = await AppDatabase.getSetting(settingKey);
      if (raw == 'dark') return ThemeMode.dark;
    } catch (_) {}
    return ThemeMode.light;
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref.watch(initialThemeModeProvider));
});
