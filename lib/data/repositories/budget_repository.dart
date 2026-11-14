import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/category_budget.dart';

class BudgetRepository {
  static const String _overallBudgetKey = 'overall_monthly_budget';

  Future<int> getOverallMonthlyBudget() async {
    final val = await AppDatabase.getSetting(_overallBudgetKey);
    if (val == null) return 0;
    return int.tryParse(val) ?? 0;
  }

  Future<void> setOverallMonthlyBudget(int amount) async {
    await AppDatabase.setSetting(_overallBudgetKey, amount.toString());
  }

  Future<void> setCategoryBudget(int categoryId, int monthlyLimit) async {
    final db = await AppDatabase.instance;
    await db.insert(
      'category_budgets',
      {
        'categoryId': categoryId,
        'monthlyLimit': monthlyLimit,
        'createdAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCategoryBudget(int categoryId) async {
    final db = await AppDatabase.instance;
    await db.delete(
      'category_budgets',
      where: 'categoryId = ?',
      whereArgs: [categoryId],
    );
  }

  Future<List<CategoryBudget>> getCategoryBudgets(int year, int month) async {
    final db = await AppDatabase.instance;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 1).toIso8601String();

    // Query semua kategori pengeluaran beserta limit budget & realisasi pengeluaran bulan ini
    final rows = await db.rawQuery('''
      SELECT 
        c.id as catId,
        c.name as catName,
        c.iconCodePoint as iconCode,
        c.colorHex as colorHex,
        cb.id as budgetId,
        COALESCE(cb.monthlyLimit, 0) as monthlyLimit,
        COALESCE((
          SELECT SUM(t.amount) 
          FROM transactions t 
          WHERE t.categoryId = c.id 
            AND t.type = 'expense'
            AND t.date >= ? AND t.date < ?
        ), 0) as totalSpent
      FROM categories c
      LEFT JOIN category_budgets cb ON c.id = cb.categoryId
      WHERE c.type = 'expense'
      ORDER BY cb.monthlyLimit DESC, totalSpent DESC
    ''', [startDate, endDate]);

    final List<CategoryBudget> list = [];
    for (final row in rows) {
      final spent = (row['totalSpent'] as num?)?.toInt() ?? 0;
      final limit = (row['monthlyLimit'] as num?)?.toInt() ?? 0;

      final double pct;
      final String status;
      if (limit > 0) {
        pct = (spent / limit * 100);
        if (pct > 100) {
          status = 'exceeded';
        } else if (pct >= 80) {
          status = 'warning';
        } else {
          status = 'safe';
        }
      } else {
        pct = 0.0;
        status = 'unlimited';
      }

      list.add(
        CategoryBudget(
          id: (row['budgetId'] as num?)?.toInt(),
          categoryId: row['catId'] as int,
          categoryName: row['catName'] as String,
          categoryIconCodePoint: row['iconCode'] as int,
          categoryColorHex: row['colorHex'] as String,
          monthlyLimit: limit,
          spentAmount: spent,
          percentage: pct,
          status: status,
        ),
      );
    }

    return list;
  }

  Future<OverallBudgetSummary> getOverallBudgetSummary(int year, int month) async {
    final db = await AppDatabase.instance;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 1).toIso8601String();

    // 1. Total Expense
    final expResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE type = 'expense' AND date >= ? AND date < ?
    ''', [startDate, endDate]);
    final totalSpent = (expResult.first['total'] as num?)?.toInt() ?? 0;

    // 2. Total Income
    final incResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE type = 'income' AND date >= ? AND date < ?
    ''', [startDate, endDate]);
    final totalIncome = (incResult.first['total'] as num?)?.toInt() ?? 0;

    // 3. Total Target Bulanan
    var overallTarget = await getOverallMonthlyBudget();

    // Hitung jumlah kategori yang dipasangi budget
    final budgetRows = await db.rawQuery('''
      SELECT COUNT(*) as count, COALESCE(SUM(monthlyLimit), 0) as sumLimit
      FROM category_budgets
      WHERE monthlyLimit > 0
    ''');
    final count = (budgetRows.first['count'] as num?)?.toInt() ?? 0;
    final sumLimit = (budgetRows.first['sumLimit'] as num?)?.toInt() ?? 0;

    // Jika overallTarget belum diset manual, gunakan total dari category_budgets
    if (overallTarget <= 0 && sumLimit > 0) {
      overallTarget = sumLimit;
    }

    return OverallBudgetSummary(
      monthlyTarget: overallTarget,
      totalSpent: totalSpent,
      totalIncome: totalIncome,
      totalCategoriesWithBudget: count,
    );
  }
}

