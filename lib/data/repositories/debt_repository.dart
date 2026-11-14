import '../database/app_database.dart';
import '../models/debt_model.dart';

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
    return await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> recordPayment(int id, int additionalAmount) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('debts', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;

    final debt = DebtModel.fromMap(rows.first);
    final newPaid = debt.paidAmount + additionalAmount;
    final isSettled = newPaid >= debt.totalAmount;

    await db.update(
      'debts',
      {
        'paidAmount': newPaid,
        'isSettled': isSettled ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
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

