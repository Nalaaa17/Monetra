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

  /// Menghasilkan statistik data saat ini untuk profil aktif
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

  /// Ekspor seluruh data (multi-profil gabungan + meta) ke teks JSON
  static Future<String> exportToJsonString() async {
    final metaDb = await AppDatabase.metaInstance;
    final profiles = await metaDb.query('profiles');
    final metaSettings = await metaDb.query('app_settings');
    final currentActiveKey = await AppDatabase.getActiveProfileKey();

    final Map<String, dynamic> profilesData = {};

    Future<Map<String, dynamic>> dumpProfileDb(dynamic db) async {
      final accounts = await db.query('accounts');
      final categories = await db.query('categories');
      final transactions = await db.query('transactions');
      final transfers = await db.query('transfers');
      final goals = await db.query('goals');
      final goalContributions = await db.query('goal_contributions');
      final recurring = await db.query('recurring_transactions');

      List<Map<String, dynamic>> budgets = [];
      try { budgets = (await db.query('category_budgets')).cast<Map<String, dynamic>>(); } catch (_) {}

      List<Map<String, dynamic>> debts = [];
      try { debts = (await db.query('debts')).cast<Map<String, dynamic>>(); } catch (_) {}

      List<Map<String, dynamic>> debtContribs = [];
      try { debtContribs = (await db.query('debt_contributions')).cast<Map<String, dynamic>>(); } catch (_) {}

      List<Map<String, dynamic>> investments = [];
      try { investments = (await db.query('investments')).cast<Map<String, dynamic>>(); } catch (_) {}

      List<Map<String, dynamic>> menus = [];
      try { menus = (await db.query('menus')).cast<Map<String, dynamic>>(); } catch (_) {}

      List<Map<String, dynamic>> settings = [];
      try { settings = (await db.query('app_settings')).cast<Map<String, dynamic>>(); } catch (_) {}

      List<Map<String, dynamic>> vacations = [];
      try { vacations = (await db.query('vacations')).cast<Map<String, dynamic>>(); } catch (_) {}

      List<Map<String, dynamic>> vacationAllocations = [];
      try { vacationAllocations = (await db.query('vacation_allocations')).cast<Map<String, dynamic>>(); } catch (_) {}

      return {
        'accounts': accounts,
        'categories': categories,
        'transactions': transactions,
        'transfers': transfers,
        'goals': goals,
        'goal_contributions': goalContributions,
        'recurring_transactions': recurring,
        'category_budgets': budgets,
        'debts': debts,
        'debt_contributions': debtContribs,
        'investments': investments,
        'menus': menus,
        'app_settings': settings,
        'vacations': vacations,
        'vacation_allocations': vacationAllocations,
      };
    }

    for (final p in profiles) {
      final pKey = p['key'] as String;
      if (pKey == currentActiveKey) {
        final activeDb = await AppDatabase.instance;
        profilesData[pKey] = await dumpProfileDb(activeDb);
      } else {
        await AppDatabase.switchProfile(pKey);
        final db = await AppDatabase.instance;
        profilesData[pKey] = await dumpProfileDb(db);
      }
    }

    // Kembalikan ke profil semula
    await AppDatabase.switchProfile(currentActiveKey);

    final activeDump = profilesData[currentActiveKey] as Map<String, dynamic>? ?? {};

    final payload = {
      'app': 'Monetra',
      'version': 3,
      'exportedAt': DateTime.now().toIso8601String(),
      'activeProfileKey': currentActiveKey,
      'meta': {
        'profiles': profiles,
        'settings': metaSettings,
      },
      'profilesData': profilesData,
      'stats': {
        'accounts': (activeDump['accounts'] as List?)?.length ?? 0,
        'categories': (activeDump['categories'] as List?)?.length ?? 0,
        'transactions': (activeDump['transactions'] as List?)?.length ?? 0,
        'transfers': (activeDump['transfers'] as List?)?.length ?? 0,
        'goals': (activeDump['goals'] as List?)?.length ?? 0,
        'recurring_transactions': (activeDump['recurring_transactions'] as List?)?.length ?? 0,
      },
      'data': {
        'accounts': activeDump['accounts'] ?? [],
        'categories': activeDump['categories'] ?? [],
        'transactions': activeDump['transactions'] ?? [],
        'transfers': activeDump['transfers'] ?? [],
        'goals': activeDump['goals'] ?? [],
        'goal_contributions': activeDump['goal_contributions'] ?? [],
        'recurring_transactions': activeDump['recurring_transactions'] ?? [],
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
      if (decoded['app'] != 'Monetra') return false;

      Future<void> restoreProfileDbData(dynamic db, Map<String, dynamic> data) async {
        final accounts = (data['accounts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final categories = (data['categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final transactions = (data['transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final transfers = (data['transfers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final goals = (data['goals'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final goalContributions = (data['goal_contributions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final recurringTransactions =
            (data['recurring_transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final categoryBudgets = (data['category_budgets'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final debts = (data['debts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final debtContributions = (data['debt_contributions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final investments = (data['investments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final menus = (data['menus'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final settings = (data['app_settings'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final vacations = (data['vacations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final vacationAllocations =
            (data['vacation_allocations'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        await db.transaction((txn) async {
          await txn.delete('goal_contributions');
          await txn.delete('goals');
          await txn.delete('recurring_transactions');
          await txn.delete('transfers');
          await txn.delete('transactions');
          await txn.delete('categories');
          await txn.delete('accounts');
          try { await txn.delete('category_budgets'); } catch (_) {}
          try { await txn.delete('debt_contributions'); } catch (_) {}
          try { await txn.delete('debts'); } catch (_) {}
          try { await txn.delete('investments'); } catch (_) {}
          try { await txn.delete('menus'); } catch (_) {}
          try { await txn.delete('app_settings'); } catch (_) {}
          try { await txn.delete('vacation_allocations'); } catch (_) {}
          try { await txn.delete('vacations'); } catch (_) {}

          for (final acc in accounts) { await txn.insert('accounts', acc); }
          for (final cat in categories) { await txn.insert('categories', cat); }
          for (final tx in transactions) { await txn.insert('transactions', tx); }
          for (final tr in transfers) { await txn.insert('transfers', tr); }
          for (final g in goals) { await txn.insert('goals', g); }
          for (final gc in goalContributions) { await txn.insert('goal_contributions', gc); }
          for (final rr in recurringTransactions) { await txn.insert('recurring_transactions', rr); }
          for (final b in categoryBudgets) { await txn.insert('category_budgets', b); }
          for (final d in debts) { await txn.insert('debts', d); }
          for (final dc in debtContributions) { await txn.insert('debt_contributions', dc); }
          for (final inv in investments) { await txn.insert('investments', inv); }
          for (final m in menus) { await txn.insert('menus', m); }
          for (final s in settings) { await txn.insert('app_settings', s); }
          for (final v in vacations) { await txn.insert('vacations', v); }
          for (final va in vacationAllocations) { await txn.insert('vacation_allocations', va); }

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
      }

      // 1. Cek format multi-profil v3
      if (decoded.containsKey('profilesData') && decoded['profilesData'] is Map) {
        final profilesData = decoded['profilesData'] as Map<String, dynamic>;
        final metaMap = decoded['meta'] as Map<String, dynamic>? ?? {};
        final profilesList = (metaMap['profiles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final metaSettings = (metaMap['settings'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final targetActiveKey = decoded['activeProfileKey'] as String? ?? AppDatabase.defaultProfileKey;

        final metaDb = await AppDatabase.metaInstance;
        if (profilesList.isNotEmpty) {
          await metaDb.delete('profiles');
          for (final p in profilesList) {
            await metaDb.insert('profiles', p);
          }
        }
        if (metaSettings.isNotEmpty) {
          await metaDb.delete('app_settings');
          for (final s in metaSettings) {
            await metaDb.insert('app_settings', s);
          }
        }

        for (final entry in profilesData.entries) {
          final pKey = entry.key;
          final pData = entry.value as Map<String, dynamic>;
          await AppDatabase.switchProfile(pKey);
          final pDb = await AppDatabase.instance;
          await restoreProfileDbData(pDb, pData);
        }

        await AppDatabase.switchProfile(targetActiveKey);
        return true;
      }
      // 2. Format legacy (single profile) -> pulihkan ke profil default 'Pribadi'
      else if (decoded.containsKey('data')) {
        await AppDatabase.switchProfile(AppDatabase.defaultProfileKey);
        final db = await AppDatabase.instance;
        final data = decoded['data'] as Map<String, dynamic>;
        await restoreProfileDbData(db, data);
        return true;
      }

      return false;
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
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
