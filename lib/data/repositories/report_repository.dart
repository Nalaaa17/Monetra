import '../../core/utils/date_formatter.dart';
import '../database/app_database.dart';

class MonthlyCashflowPoint {
  final int year;
  final int month;
  final String label;
  final int totalIncome;
  final int totalExpense;

  const MonthlyCashflowPoint({
    required this.year,
    required this.month,
    required this.label,
    required this.totalIncome,
    required this.totalExpense,
  });

  int get net => totalIncome - totalExpense;
}

class CategoryExpenseShare {
  final int categoryId;
  final String categoryName;
  final String colorHex;
  final int iconCodePoint;
  final int totalAmount;
  final double percentage;

  const CategoryExpenseShare({
    required this.categoryId,
    required this.categoryName,
    required this.colorHex,
    required this.iconCodePoint,
    required this.totalAmount,
    required this.percentage,
  });
}

class AccountExpenseShare {
  final int accountId;
  final String accountName;
  final String colorHex;
  final int totalExpense;
  final int totalIncome;

  const AccountExpenseShare({
    required this.accountId,
    required this.accountName,
    required this.colorHex,
    required this.totalExpense,
    required this.totalIncome,
  });
}

class MonthlyReportSummary {
  final int year;
  final int month;
  final int totalIncome;
  final int totalExpense;
  final int netSavings;
  final int dailyAverageExpense;
  final String? highestExpenseDay;
  final int highestExpenseAmount;
  final List<CategoryExpenseShare> categoryExpenses;
  final List<AccountExpenseShare> accountExpenses;

  const MonthlyReportSummary({
    required this.year,
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.dailyAverageExpense,
    this.highestExpenseDay,
    required this.highestExpenseAmount,
    required this.categoryExpenses,
    required this.accountExpenses,
  });

  CategoryExpenseShare? get topCategory =>
      categoryExpenses.isNotEmpty ? categoryExpenses.first : null;
}

class ReportRepository {
  Future<MonthlyReportSummary> getMonthlyReport(int year, int month) async {
    final db = await AppDatabase.instance;

    // Rentang awal dan akhir bulan
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 1).toIso8601String();

    // 1. Total Income & Total Expense
    final incomeResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE type = 'income' AND date >= ? AND date < ?
    ''', [startDate, endDate]);
    final totalIncome = (incomeResult.first['total'] as num?)?.toInt() ?? 0;

    final expenseResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE type = 'expense' AND date >= ? AND date < ?
    ''', [startDate, endDate]);
    final totalExpense = (expenseResult.first['total'] as num?)?.toInt() ?? 0;

    // 2. Pengeluaran per Kategori (LEFT JOIN agar pengeluaran tanpa kategori tetap masuk total chart)
    final categoryRows = await db.rawQuery('''
      SELECT 
        COALESCE(c.id, -1) as categoryId,
        COALESCE(c.name, 'Tanpa Kategori') as categoryName,
        COALESCE(c.colorHex, '0xFF6B7280') as colorHex,
        c.iconCodePoint as iconCodePoint,
        COALESCE(SUM(t.amount), 0) as totalAmount
      FROM transactions t
      LEFT JOIN categories c ON t.categoryId = c.id
      WHERE t.type = 'expense' AND t.date >= ? AND t.date < ?
      GROUP BY COALESCE(c.id, -1)
      ORDER BY totalAmount DESC
    ''', [startDate, endDate]);

    final List<CategoryExpenseShare> categoryExpenses = [];
    for (final row in categoryRows) {
      final amount = (row['totalAmount'] as num?)?.toInt() ?? 0;
      final percentage =
          totalExpense > 0 ? (amount / totalExpense) * 100 : 0.0;

      categoryExpenses.add(
        CategoryExpenseShare(
          categoryId: (row['categoryId'] as num?)?.toInt() ?? -1,
          categoryName: (row['categoryName'] as String?) ?? 'Tanpa Kategori',
          colorHex: (row['colorHex'] as String?) ?? '0xFF6B7280',
          iconCodePoint: (row['iconCodePoint'] as num?)?.toInt() ?? 0,
          totalAmount: amount,
          percentage: percentage,
        ),
      );
    }

    // 3. Pengeluaran per Akun
    final accountRows = await db.rawQuery('''
      SELECT 
        a.id as accountId,
        a.name as accountName,
        a.colorHex as colorHex,
        COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END), 0) as totalExpense,
        COALESCE(SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE 0 END), 0) as totalIncome
      FROM accounts a
      LEFT JOIN transactions t ON a.id = t.accountId AND t.date >= ? AND t.date < ?
      WHERE a.isArchived = 0
      GROUP BY a.id
      ORDER BY totalExpense DESC
    ''', [startDate, endDate]);

    final List<AccountExpenseShare> accountExpenses = accountRows.map((row) {
      return AccountExpenseShare(
        accountId: row['accountId'] as int,
        accountName: row['accountName'] as String,
        colorHex: row['colorHex'] as String,
        totalExpense: (row['totalExpense'] as num?)?.toInt() ?? 0,
        totalIncome: (row['totalIncome'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    // 4. Hari dengan pengeluaran terbesar & Rata-rata harian
    final dailyRows = await db.rawQuery('''
      SELECT 
        substr(date, 1, 10) as dayDate,
        COALESCE(SUM(amount), 0) as dayTotal
      FROM transactions
      WHERE type = 'expense' AND date >= ? AND date < ?
      GROUP BY dayDate
      ORDER BY dayTotal DESC
    ''', [startDate, endDate]);

    String? topDay;
    int topAmount = 0;
    if (dailyRows.isNotEmpty) {
      topDay = dailyRows.first['dayDate'] as String?;
      topAmount = (dailyRows.first['dayTotal'] as num?)?.toInt() ?? 0;
    }

    // Jumlah hari aktif atau hari berjalan dalam bulan tersebut
    final now = DateTime.now();
    int daysDivisor;
    if (year == now.year && month == now.month) {
      daysDivisor = now.day > 0 ? now.day : 1;
    } else {
      daysDivisor = DateTime(year, month + 1, 0).day;
    }
    final dailyAvg = daysDivisor > 0 ? (totalExpense / daysDivisor).round() : 0;

    return MonthlyReportSummary(
      year: year,
      month: month,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netSavings: totalIncome - totalExpense,
      dailyAverageExpense: dailyAvg,
      highestExpenseDay: topDay,
      highestExpenseAmount: topAmount,
      categoryExpenses: categoryExpenses,
      accountExpenses: accountExpenses,
    );
  }

  /// Mengambil ringkasan pemasukan vs pengeluaran selama [monthsCount] bulan terakhir
  /// hingga bulan [endYear]-[endMonth] secara berurutan (lama -> baru).
  Future<List<MonthlyCashflowPoint>> getSixMonthTrend(
    int endYear,
    int endMonth, {
    int monthsCount = 6,
  }) async {
    final db = await AppDatabase.instance;
    final startMonthDate = DateTime(endYear, endMonth - (monthsCount - 1), 1);
    final endExclusiveDate = DateTime(endYear, endMonth + 1, 1);

    final rows = await db.rawQuery('''
      SELECT
        substr(date, 1, 7) as ym,
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as totalIncome,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as totalExpense
      FROM transactions
      WHERE date >= ? AND date < ?
      GROUP BY ym
    ''', [
      startMonthDate.toIso8601String(),
      endExclusiveDate.toIso8601String(),
    ]);

    final byYm = <String, ({int income, int expense})>{};
    for (final row in rows) {
      final ym = row['ym'] as String?;
      if (ym == null) continue;
      byYm[ym] = (
        income: (row['totalIncome'] as num?)?.toInt() ?? 0,
        expense: (row['totalExpense'] as num?)?.toInt() ?? 0,
      );
    }

    final points = <MonthlyCashflowPoint>[];
    for (int i = 0; i < monthsCount; i++) {
      final d = DateTime(startMonthDate.year, startMonthDate.month + i, 1);
      final ymKey = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      final match = byYm[ymKey];
      points.add(
        MonthlyCashflowPoint(
          year: d.year,
          month: d.month,
          label: DateFormatter.shortMonthName(d.month),
          totalIncome: match?.income ?? 0,
          totalExpense: match?.expense ?? 0,
        ),
      );
    }
    return points;
  }
}

