import '../database/app_database.dart';
import '../models/debt_model.dart';
import '../models/transaction.dart';

class DebtRepository {
  Future<int> insertDebt(DebtModel debt) async {
    final db = await AppDatabase.instance;
    return await db.insert('debts', debt.toMap());
  }

  Future<int> updateDebt(DebtModel debt) async {
    final db = await AppDatabase.instance;
    return await db.update(
      'debts',
      debt.toMap(),
      where: 'id = ?',
      whereArgs: [debt.id],
    );
  }

  Future<int> deleteDebt(int id) async {
    final db = await AppDatabase.instance;
    return await db.transaction((txn) async {
      await txn.delete('debt_contributions', where: 'debtId = ?', whereArgs: [id]);
      return await txn.delete('debts', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> recordPayment(
    int id,
    int additionalAmount, {
    int? accountId,
    String? note,
  }) async {
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      final rows = await txn.query('debts', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return;

      final debt = DebtModel.fromMap(rows.first);
      final newPaid = debt.paidAmount + additionalAmount;
      final isSettled = newPaid >= debt.totalAmount;

      await txn.update(
        'debts',
        {
          'paidAmount': newPaid,
          'isSettled': isSettled ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      if (accountId != null && additionalAmount > 0) {
        final now = DateTime.now();
        if (debt.isDebt) {
          // Cari kategori default pengeluaran ('Tagihan' / 'Utang' / 'Cicilan' / 'Lainnya')
          int? effectiveCatId;
          final cats = await txn.query(
            'categories',
            where: "type = 'expense' AND isActive = 1 AND (LOWER(name) LIKE '%tagihan%' OR LOWER(name) LIKE '%utang%' OR LOWER(name) LIKE '%cicilan%' OR LOWER(name) = 'lainnya')",
            orderBy: 'id ASC',
            limit: 1,
          );
          if (cats.isNotEmpty) {
            effectiveCatId = cats.first['id'] as int?;
          }

          // 1. Catat transaksi pengeluaran riil agar saldo rekening langsung terpotong & tercatat di riwayat
          await txn.insert(
            'transactions',
            TransactionModel(
              type: 'expense',
              amount: additionalAmount,
              accountId: accountId,
              categoryId: effectiveCatId,
              note: (note != null && note.trim().isNotEmpty)
                  ? note.trim()
                  : 'Bayar Utang: ${debt.title} (${debt.personName})',
              date: now,
              createdAt: now,
            ).toMap(),
          );

          // 2. Catat riwayat di debt_contributions dengan isRealized = 1 (agar riwayat pembayaran tersimpan tanpa double-deduct)
          await txn.insert(
            'debt_contributions',
            {
              'debtId': id,
              'sourceAccountId': accountId,
              'amount': additionalAmount,
              'date': now.toIso8601String(),
              'note': (note != null && note.trim().isNotEmpty)
                  ? note.trim()
                  : 'Bayar Utang: ${debt.title} (${debt.personName})',
              'isRealized': 1,
            },
          );
        } else {
          // Terima piutang adalah pemasukan uang riil ke rekening
          int? effectiveCatId;
          final cats = await txn.query(
            'categories',
            where: "type = 'income' AND isActive = 1 AND (LOWER(name) LIKE '%piutang%' OR LOWER(name) = 'tambahan uang' OR LOWER(name) = 'lainnya')",
            orderBy: 'id ASC',
            limit: 1,
          );
          if (cats.isNotEmpty) {
            effectiveCatId = cats.first['id'] as int?;
          }

          await txn.insert(
            'transactions',
            TransactionModel(
              type: 'income',
              amount: additionalAmount,
              accountId: accountId,
              categoryId: effectiveCatId,
              note: (note != null && note.trim().isNotEmpty)
                  ? note.trim()
                  : 'Terima Piutang: ${debt.title} (${debt.personName})',
              date: now,
              createdAt: now,
            ).toMap(),
          );
        }
      }
    });
  }

  Future<void> toggleSettle(int id, bool currentStatus) async {
    final db = await AppDatabase.instance;
    await db.update(
      'debts',
      {'isSettled': currentStatus ? 0 : 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<DebtModel>> getAllDebts({String? type}) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'debts',
      where: type != null ? 'type = ?' : null,
      whereArgs: type != null ? [type] : null,
      orderBy: 'isSettled ASC, dueDate ASC, id DESC',
    );
    return rows.map((e) => DebtModel.fromMap(e)).toList();
  }
}

