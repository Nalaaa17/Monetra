import '../database/app_database.dart';
import '../models/transfer.dart';

class TransferDetail {
  final TransferModel transfer;
  final String fromAccountName;
  final String fromAccountColorHex;
  final String toAccountName;
  final String toAccountColorHex;

  const TransferDetail({
    required this.transfer,
    required this.fromAccountName,
    required this.fromAccountColorHex,
    required this.toAccountName,
    required this.toAccountColorHex,
  });

  int get id => transfer.id!;
  int get fromAccountId => transfer.fromAccountId;
  int get toAccountId => transfer.toAccountId;
  int get amount => transfer.amount;
  String? get note => transfer.note;
  DateTime get date => transfer.date;
}

class TransferRepository {
  Future<int> insertTransfer(TransferModel transfer) async {
    final db = await AppDatabase.instance;
    return await db.insert('transfers', transfer.toMap());
  }

  Future<int> updateTransfer(TransferModel transfer) async {
    final db = await AppDatabase.instance;
    return await db.update(
      'transfers',
      transfer.toMap(),
      where: 'id = ?',
      whereArgs: [transfer.id],
    );
  }

  Future<int> deleteTransfer(int id) async {
    final db = await AppDatabase.instance;
    return await db.delete(
      'transfers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<TransferModel?> getTransferById(int id) async {
    final db = await AppDatabase.instance;
    final maps = await db.query(
      'transfers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TransferModel.fromMap(maps.first);
  }

  Future<List<TransferDetail>> getAllTransfers({
    int? accountId,
    List<int>? accountIds,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (accountId == null && accountIds != null && accountIds.isEmpty) {
      return [];
    }

    final db = await AppDatabase.instance;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (accountId != null) {
      whereClauses.add('(tr.fromAccountId = ? OR tr.toAccountId = ?)');
      whereArgs.addAll([accountId, accountId]);
    } else if (accountIds != null && accountIds.isNotEmpty) {
      final placeholders = List.filled(accountIds.length, '?').join(',');
      whereClauses.add(
        '(tr.fromAccountId IN ($placeholders) OR tr.toAccountId IN ($placeholders))',
      );
      whereArgs.addAll(accountIds);
      whereArgs.addAll(accountIds);
    }

    if (startDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      whereClauses.add('tr.date >= ?');
      whereArgs.add(start.toIso8601String());
    }
    if (endDate != null) {
      final nextDay = DateTime(endDate.year, endDate.month, endDate.day + 1);
      whereClauses.add('tr.date < ?');
      whereArgs.add(nextDay.toIso8601String());
    }

    final whereSql =
        whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final results = await db.rawQuery('''
      SELECT 
        tr.*,
        a1.name as fromAccountName,
        a1.colorHex as fromAccountColorHex,
        a2.name as toAccountName,
        a2.colorHex as toAccountColorHex
      FROM transfers tr
      JOIN accounts a1 ON tr.fromAccountId = a1.id
      JOIN accounts a2 ON tr.toAccountId = a2.id
      $whereSql
      ORDER BY tr.date DESC, tr.id DESC
    ''', whereArgs);

    return results.map((row) {
      final transfer = TransferModel.fromMap(row);
      return TransferDetail(
        transfer: transfer,
        fromAccountName: row['fromAccountName'] as String,
        fromAccountColorHex: row['fromAccountColorHex'] as String,
        toAccountName: row['toAccountName'] as String,
        toAccountColorHex: row['toAccountColorHex'] as String,
      );
    }).toList();
  }

  /// Eksekusi transfer saldo antar profil (Jembatan Pribadi <-> Bisnis: Prive & Suntik Modal)
  Future<void> executeInterProfileTransfer({
    required String fromProfileKey,
    required String fromProfileName,
    required bool isFromBusiness,
    required int fromAccountId,
    required String fromAccountName,
    required String toProfileKey,
    required String toProfileName,
    required bool isToBusiness,
    required int toAccountId,
    required String toAccountName,
    required int amount,
    String? note,
    DateTime? date,
  }) async {
    final transferDate = date ?? DateTime.now();
    final dateStr = transferDate.toIso8601String();
    final nowStr = DateTime.now().toIso8601String();

    final fromDb = await AppDatabase.getDatabaseForProfile(fromProfileKey);
    final toDb = await AppDatabase.getDatabaseForProfile(toProfileKey);

    // Tentukan kategori & label cerdas
    String fromCategoryName;
    String toCategoryName;
    String fromDefaultNote;
    String toDefaultNote;

    if (isFromBusiness && !isToBusiness) {
      // Bisnis -> Pribadi (Prive / Tarik Gaji Owner)
      fromCategoryName = 'Prive / Tarik Modal';
      toCategoryName = 'Gaji / Hasil Bisnis';
      fromDefaultNote = note?.isNotEmpty == true
          ? note!
          : 'Prive ke $toProfileName ($toAccountName)';
      toDefaultNote = note?.isNotEmpty == true
          ? note!
          : 'Gaji dari $fromProfileName ($fromAccountName)';
    } else if (!isFromBusiness && isToBusiness) {
      // Pribadi -> Bisnis (Suntik Modal Owner)
      fromCategoryName = 'Suntik Modal Usaha';
      toCategoryName = 'Setor Modal Usaha';
      fromDefaultNote = note?.isNotEmpty == true
          ? note!
          : 'Suntik Modal ke $toProfileName ($toAccountName)';
      toDefaultNote = note?.isNotEmpty == true
          ? note!
          : 'Suntik Modal dari $fromProfileName ($fromAccountName)';
    } else {
      // Antar Pribadi atau Antar Bisnis
      fromCategoryName = 'Transfer Keluar Profil';
      toCategoryName = 'Transfer Masuk Profil';
      fromDefaultNote = note?.isNotEmpty == true
          ? note!
          : 'Transfer ke $toProfileName ($toAccountName)';
      toDefaultNote = note?.isNotEmpty == true
          ? note!
          : 'Transfer dari $fromProfileName ($fromAccountName)';
    }

    // Helper cari atau buat kategori
    Future<int?> findOrCreateCategory(
      dynamic db,
      String name,
      String type,
      int iconCodePoint,
      String colorHex,
    ) async {
      try {
        final existing = await db.query(
          'categories',
          columns: ['id'],
          where: 'LOWER(name) = ? AND type = ?',
          whereArgs: [name.toLowerCase(), type],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          return existing.first['id'] as int;
        }
        return await db.insert('categories', {
          'name': name,
          'iconCodePoint': iconCodePoint,
          'colorHex': colorHex,
          'type': type,
          'isActive': 1,
        });
      } catch (_) {
        return null;
      }
    }

    // 1. Eksekusi di DB Asal (Pengeluaran / Penarikan Modal)
    final fromCatId = await findOrCreateCategory(
      fromDb,
      fromCategoryName,
      'expense',
      0xe491,
      '0xFFEF4444',
    );

    await fromDb.insert('transactions', {
      'type': 'expense',
      'amount': amount,
      'accountId': fromAccountId,
      'categoryId': fromCatId,
      'note': fromDefaultNote,
      'date': dateStr,
      'createdAt': nowStr,
    });

    // 2. Eksekusi di DB Tujuan (Pemasukan / Penambahan Modal)
    final toCatId = await findOrCreateCategory(
      toDb,
      toCategoryName,
      'income',
      0xe8e5,
      '0xFF10B981',
    );

    await toDb.insert('transactions', {
      'type': 'income',
      'amount': amount,
      'accountId': toAccountId,
      'categoryId': toCatId,
      'note': toDefaultNote,
      'date': dateStr,
      'createdAt': nowStr,
    });
  }
}
