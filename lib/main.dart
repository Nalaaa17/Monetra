import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/theme/theme_provider.dart';
import 'data/database/app_database.dart';
import 'data/repositories/recurring_transaction_repository.dart';
import 'data/services/backup_service.dart';
import 'data/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Database lokal, preferensi tema, & layanan notifikasi
  await AppDatabase.instance;
  final savedThemeMode = await ThemeModeController.readSavedThemeMode();
  await NotificationService.initialize();

  // Jalankan transaksi berulang yang jatuh tempo sebelum auto-backup harian
  try {
    await RecurringTransactionRepository().syncRecurringTransactions();
  } catch (e) {
    debugPrint('Sinkronisasi transaksi berulang saat mulai gagal: $e');
  }

  // Jalankan auto-backup harian secara non-blocking (maks 1x per hari)
  unawaited(BackupService.runDailyAutoBackupIfNeeded());

  runApp(
    ProviderScope(
      overrides: [
        initialThemeModeProvider.overrideWithValue(savedThemeMode),
      ],
      child: const MonetraApp(),
    ),
  );
}
