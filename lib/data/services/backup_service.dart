import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';
import '../models/goal.dart';
import 'notification_service.dart';

class BackupStats {
  final int accountsCount;
  final int categoriesCount;
  final int transactionsCount;
  final int transfersCount;
  final int goalsCount;
  final int recurringCount;
  final DateTime? lastBackupDate;

  const BackupStats({
    required this.accountsCount,
    required this.categoriesCount,
    required this.transactionsCount,
    required this.transfersCount,
    this.goalsCount = 0,
    this.recurringCount = 0,
    this.lastBackupDate,
  });
}

class BackupService {
  static const String _autoBackupEnabledKey = 'auto_backup_enabled';
  static const String _lastAutoBackupDateKey = 'last_auto_backup_date';
  static const String autoBackupFilePrefix = 'monetra_autobackup_';
  static const int maxRetainedAutoBackups = 14;

  static bool isAutoBackupFile(File file) {
    final name = file.path.split(Platform.pathSeparator).last;
    return name.startsWith(autoBackupFilePrefix);
  }

  static Future<bool> isAutoBackupEnabled() async {
    try {
      final val = await AppDatabase.getSetting(_autoBackupEnabledKey);
      return val != '0';
    } catch (_) {
      return true;
    }
  }

  static Future<void> setAutoBackupEnabled(bool enabled) async {
    await AppDatabase.setSetting(_autoBackupEnabledKey, enabled ? '1' : '0');
  }

  static Future<String?> getLastAutoBackupDate() async {
    try {
      return await AppDatabase.getSetting(_lastAutoBackupDateKey);
    } catch (_) {
      return null;
    }
  }

  /// Mendapatkan direktori folder backup lokal
  static Future<Directory> getBackupDirectory() async {
    Directory baseDir;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      final docDir = await getApplicationDocumentsDirectory();
      baseDir = Directory(p.join(docDir.path, 'Monetra', 'Backups'));
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      baseDir = Directory(p.join(docDir.path, 'backups'));
    }

    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    return baseDir;
  }

  /// Menghasilkan statistik data saat ini
  static Future<BackupStats> getCurrentStats() async {
    final db = await AppDatabase.instance;

    final accCount = (await db.rawQuery('SELECT COUNT(*) as c FROM accounts')).first['c'] as int? ?? 0;
    final catCount = (await db.rawQuery('SELECT COUNT(*) as c FROM categories')).first['c'] as int? ?? 0;
    final txCount = (await db.rawQuery('SELECT COUNT(*) as c FROM transactions')).first['c'] as int? ?? 0;
    final trCount = (await db.rawQuery('SELECT COUNT(*) as c FROM transfers')).first['c'] as int? ?? 0;
    final goalCount = (await db.rawQuery('SELECT COUNT(*) as c FROM goals')).first['c'] as int? ?? 0;
    final recurringCount = (await db.rawQuery('SELECT COUNT(*) as c FROM recurring_transactions')).first['c'] as int? ?? 0;

    final backups = await listBackupFiles();
    DateTime? lastDate;
    if (backups.isNotEmpty) {
      lastDate = await backups.first.lastModified();
    }

    return BackupStats(
      accountsCount: accCount,
      categoriesCount: catCount,
      transactionsCount: txCount,
      transfersCount: trCount,
      goalsCount: goalCount,
      recurringCount: recurringCount,
      lastBackupDate: lastDate,
    );
  }

  /// Ekspor seluruh data ke teks JSON yang diformat
  static Future<String> exportToJsonString() async {
    final db = await AppDatabase.instance;

    final accounts = await db.query('accounts');
    final categories = await db.query('categories');
    final transactions = await db.query('transactions');
    final transfers = await db.query('transfers');
    final goals = await db.query('goals');
    final goalContributions = await db.query('goal_contributions');
    final recurringTransactions = await db.query('recurring_transactions');

    final payload = {
      'app': 'Monetra',
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'stats': {
        'accounts': accounts.length,
        'categories': categories.length,
        'transactions': transactions.length,
        'transfers': transfers.length,
        'goals': goals.length,
        'recurring_transactions': recurringTransactions.length,
      },
      'data': {
        'accounts': accounts,
        'categories': categories,
        'transactions': transactions,
        'transfers': transfers,
        'goals': goals,
        'goal_contributions': goalContributions,
        'recurring_transactions': recurringTransactions,
      }
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Simpan backup otomatis/manual ke file di folder penyimpanan lokal HP
  static Future<File> createBackupFile({
    bool isAuto = false,
    DateTime? timestampOverride,
    Directory? directoryOverride,
  }) async {
    final jsonString = await exportToJsonString();
    final backupDir = directoryOverride ?? await getBackupDirectory();
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final now = timestampOverride ?? DateTime.now();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(now);
    final prefix = isAuto ? autoBackupFilePrefix : 'monetra_backup_';
    final filePath = p.join(backupDir.path, '$prefix$timestamp.json');

    final file = File(filePath);
    await file.writeAsString(jsonString);
    return file;
  }

  /// Menjalankan auto-backup harian maksimal 1x per hari (PRD §9).
  static Future<File?> runDailyAutoBackupIfNeeded({
    DateTime? nowOverride,
    Directory? directoryOverride,
  }) async {
    try {
      final enabled = await isAutoBackupEnabled();
      if (!enabled) return null;

      final now = nowOverride ?? DateTime.now();
      final todayKey = DateFormat('yyyy-MM-dd').format(now);
      final compactDate = DateFormat('yyyyMMdd').format(now);

      final lastDate = await getLastAutoBackupDate();
      if (lastDate == todayKey) {
        return null;
      }

      final backupDir = directoryOverride ?? await getBackupDirectory();
      final existingFiles = await listBackupFiles(directoryOverride: backupDir);
      final hasTodayAutoFile = existingFiles.any((f) {
        final name = f.path.split(Platform.pathSeparator).last;
        return name.startsWith('$autoBackupFilePrefix$compactDate');
      });

      if (hasTodayAutoFile) {
        await AppDatabase.setSetting(_lastAutoBackupDateKey, todayKey);
        return null;
      }

      final created = await createBackupFile(
        isAuto: true,
        timestampOverride: now,
        directoryOverride: backupDir,
      );
      await AppDatabase.setSetting(_lastAutoBackupDateKey, todayKey);
      await _pruneOldAutoBackups(backupDir);
      return created;
    } catch (e) {
      debugPrint('Auto-backup harian gagal: $e');
      return null;
    }
  }

  static Future<void> _pruneOldAutoBackups(Directory backupDir) async {
    try {
      final files = await listBackupFiles(directoryOverride: backupDir);
      final autoFiles = files.where(isAutoBackupFile).toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      if (autoFiles.length <= maxRetainedAutoBackups) return;

      for (final stale in autoFiles.skip(maxRetainedAutoBackups)) {
        await deleteBackupFile(stale);
      }
    } catch (_) {}
  }

  /// Daftar file cadangan lokal yang tersimpan
  static Future<List<File>> listBackupFiles({
    Directory? directoryOverride,
  }) async {
    try {
      final backupDir = directoryOverride ?? await getBackupDirectory();
      if (!await backupDir.exists()) return [];
      final entities = await backupDir.list().toList();
      final files = entities
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();

      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return files;
    } catch (_) {
      return [];
    }
  }

  /// Pulihkan data dari teks JSON
  static Future<bool> restoreFromJsonString(String jsonString) async {
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) return false;
      if (decoded['app'] != 'Monetra' || !decoded.containsKey('data')) {
        return false;
      }

      final data = decoded['data'] as Map<String, dynamic>;
      final accounts = (data['accounts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final categories = (data['categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final transactions = (data['transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final transfers = (data['transfers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final goals = (data['goals'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final goalContributions = (data['goal_contributions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final recurringTransactions =
          (data['recurring_transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      final db = await AppDatabase.instance;

      // Jalankan dalam SQLite Transaction agar aman jika ada kegagalan
      await db.transaction((txn) async {
        await txn.delete('goal_contributions');
        await txn.delete('goals');
        await txn.delete('recurring_transactions');
        await txn.delete('transfers');
        await txn.delete('transactions');
        await txn.delete('categories');
        await txn.delete('accounts');

        for (final acc in accounts) {
          await txn.insert('accounts', acc);
        }
        for (final cat in categories) {
          await txn.insert('categories', cat);
        }
        for (final tx in transactions) {
          await txn.insert('transactions', tx);
        }
        for (final tr in transfers) {
          await txn.insert('transfers', tr);
        }
        for (final g in goals) {
          await txn.insert('goals', g);
        }
        for (final gc in goalContributions) {
          await txn.insert('goal_contributions', gc);
        }
        for (final rr in recurringTransactions) {
          await txn.insert('recurring_transactions', rr);
        }

        // Pastikan backup versi lama tanpa sourceAccountId/category tetap konsisten
        await txn.rawUpdate('''
          UPDATE goal_contributions
          SET sourceAccountId = (
            SELECT sourceAccountId FROM goals WHERE goals.id = goal_contributions.goalId
          )
          WHERE sourceAccountId IS NULL
        ''');
        await txn.rawUpdate('''
          UPDATE accounts
          SET category = CASE
            WHEN LOWER(name) LIKE '%seabank%' THEN 'tabungan'
            ELSE 'harian'
          END
          WHERE category IS NULL OR category = ''
        ''');
      });

      // Jadwalkan ulang notifikasi H-3 untuk semua target aktif yang dipulihkan
      for (final gMap in goals) {
        try {
          final goal = Goal.fromMap(gMap);
          if (goal.id == null) continue;
          if (goal.reminderEnabled && !goal.isDone && goal.status == 'active') {
            await NotificationService.scheduleGoalReminder(
              goalId: goal.id!,
              goalName: goal.name,
              deadline: goal.deadline,
              remainingAmount: goal.remainingAmount,
            );
          } else {
            await NotificationService.cancelGoalReminder(goal.id!);
          }
        } catch (_) {}
      }

      return true;
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      return false;
    }
  }

  /// Pulihkan data dari file fisik
  static Future<bool> restoreFromFile(File file) async {
    try {
      final content = await file.readAsString();
      return await restoreFromJsonString(content);
    } catch (_) {
      return false;
    }
  }

  /// Hapus file cadangan
  static Future<bool> deleteBackupFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

