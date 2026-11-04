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

  Future<List<TransferDetail>> getAllTransfers({int? accountId}) async {
    final db = await AppDatabase.instance;
    String whereSql = '';
    List<dynamic> whereArgs = [];

    if (accountId != null) {
      whereSql = 'WHERE tr.fromAccountId = ? OR tr.toAccountId = ?';
      whereArgs = [accountId, accountId];
    }

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
}
