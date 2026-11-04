import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';

class BackupStats {
  final int accountsCount;
  final int categoriesCount;
  final int transactionsCount;
  final int transfersCount;
  final DateTime? lastBackupDate;

  const BackupStats({
    required this.accountsCount,
    required this.categoriesCount,
    required this.transactionsCount,
    required this.transfersCount,
    this.lastBackupDate,
  });
}

class BackupService {
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

    final payload = {
      'app': 'Monetra',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'stats': {
        'accounts': accounts.length,
        'categories': categories.length,
        'transactions': transactions.length,
        'transfers': transfers.length,
      },
      'data': {
        'accounts': accounts,
        'categories': categories,
        'transactions': transactions,
        'transfers': transfers,
      }
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Simpan backup otomatis ke file di folder penyimpanan lokal HP
  static Future<File> createBackupFile() async {
    final jsonString = await exportToJsonString();
    final backupDir = await getBackupDirectory();

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = p.join(backupDir.path, 'monetra_backup_$timestamp.json');

    final file = File(filePath);
    await file.writeAsString(jsonString);
    return file;
  }

  /// Daftar file cadangan lokal yang tersimpan
  static Future<List<File>> listBackupFiles() async {
    try {
      final backupDir = await getBackupDirectory();
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

      final db = await AppDatabase.instance;

      // Jalankan dalam SQLite Transaction agar aman jika ada kegagalan
      await db.transaction((txn) async {
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
      });

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

