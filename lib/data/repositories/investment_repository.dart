import '../database/app_database.dart';
import '../models/investment_model.dart';

class InvestmentRepository {
  Future<int> insertInvestment(InvestmentModel investment) async {
    final db = await AppDatabase.instance;
    return await db.insert('investments', investment.toMap());
  }

  Future<int> updateInvestment(InvestmentModel investment) async {
    final db = await AppDatabase.instance;
    return await db.update(
      'investments',
      investment.toMap(),
      where: 'id = ?',
      whereArgs: [investment.id],
    );
  }

  Future<int> deleteInvestment(int id) async {
    final db = await AppDatabase.instance;
    return await db.delete('investments', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateValuation(int id, int newCurrentAmount) async {
    final db = await AppDatabase.instance;
    await db.update(
      'investments',
      {
        'currentAmount': newCurrentAmount,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<InvestmentModel>> getAllInvestments({String? category}) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'investments',
      where: category != null && category.isNotEmpty ? 'category = ?' : null,
      whereArgs: category != null && category.isNotEmpty ? [category] : null,
      orderBy: 'currentAmount DESC, id DESC',
    );
    return rows.map((e) => InvestmentModel.fromMap(e)).toList();
  }

  Future<InvestmentSummary> getSummary() async {
    final list = await getAllInvestments();
    int current = 0;
    int initial = 0;
    for (final item in list) {
      current += item.currentAmount;
      initial += item.initialAmount;
    }
    final gainOrLoss = current - initial;
    final pct = initial > 0 ? (gainOrLoss / initial * 100) : 0.0;
    return InvestmentSummary(
      totalCurrentValue: current,
      totalInvested: initial,
      totalGainOrLoss: gainOrLoss,
      returnPercentage: pct,
    );
  }
}

