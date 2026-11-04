import '../database/app_database.dart';
import '../models/account.dart';

class AccountWithBalance {
  final Account account;
  final int balance;

  const AccountWithBalance({
    required this.account,
    required this.balance,
  });

  int get id => account.id!;
  String get name => account.name;
  String get type => account.type;
  String get colorHex => account.colorHex;
  int get iconCodePoint => account.iconCodePoint;
}

class BalanceSummary {
  final int dailySpendingBalance; // Mandiri + Cash (Uang Harian)
  final int savingsBalance; // Seabank (Tabungan)
  final int totalNetWorth; // Total Keseluruhan

  const BalanceSummary({
    required this.dailySpendingBalance,
    required this.savingsBalance,
    required this.totalNetWorth,
  });
}

class AccountRepository {
  Future<List<Account>> getAllAccounts({bool includeArchived = false}) async {
    final db = await AppDatabase.instance;
    final maps = await db.query(
      'accounts',
      where: includeArchived ? null : 'isArchived = 0',
      orderBy: 'id ASC',
    );
    return maps.map((e) => Account.fromMap(e)).toList();
  }

  Future<Account?> getAccountById(int id) async {
    final db = await AppDatabase.instance;
    final maps = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Account.fromMap(maps.first);
  }

  Future<int> calculateAccountBalance(int accountId) async {
    final db = await AppDatabase.instance;

    // 1. Initial Balance
    final accountMaps = await db.query(
      'accounts',
      columns: ['initialBalance'],
      where: 'id = ?',
      whereArgs: [accountId],
    );
    if (accountMaps.isEmpty) return 0;
    final initialBalance = accountMaps.first['initialBalance'] as int? ?? 0;

    // 2. Sum Income
    final incomeResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE accountId = ? AND type = 'income'
    ''', [accountId]);
    final totalIncome = (incomeResult.first['total'] as num?)?.toInt() ?? 0;

    // 3. Sum Expense
    final expenseResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE accountId = ? AND type = 'expense'
    ''', [accountId]);
    final totalExpense = (expenseResult.first['total'] as num?)?.toInt() ?? 0;

    // 4. Sum Transfer In
    final transferInResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transfers
      WHERE toAccountId = ?
    ''', [accountId]);
    final totalTransferIn =
        (transferInResult.first['total'] as num?)?.toInt() ?? 0;

    // 5. Sum Transfer Out
    final transferOutResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transfers
      WHERE fromAccountId = ?
    ''', [accountId]);
    final totalTransferOut =
        (transferOutResult.first['total'] as num?)?.toInt() ?? 0;

    return initialBalance +
        totalIncome -
        totalExpense +
        totalTransferIn -
        totalTransferOut;
  }

  Future<List<AccountWithBalance>> getAllAccountsWithBalances({
    bool includeArchived = false,
  }) async {
    final accounts = await getAllAccounts(includeArchived: includeArchived);
    final List<AccountWithBalance> result = [];

    for (final acc in accounts) {
      final balance = await calculateAccountBalance(acc.id!);
      result.add(AccountWithBalance(account: acc, balance: balance));
    }

    return result;
  }

  /// Perhitungan agregasi PRD §5.3:
  /// Uang Harian = Mandiri + Cash
  /// Tabungan = Seabank
  /// Total = Uang Harian + Tabungan (atau seluruh akun)
  Future<BalanceSummary> getBalanceSummary() async {
    final accountsWithBalance = await getAllAccountsWithBalances();

    int dailySpending = 0;
    int savings = 0;
    int total = 0;

    for (final item in accountsWithBalance) {
      total += item.balance;
      final nameLower = item.name.toLowerCase();

      if (nameLower.contains('seabank')) {
        savings += item.balance;
      } else if (nameLower.contains('mandiri') || nameLower.contains('cash')) {
        dailySpending += item.balance;
      } else {
        // Jika akun bank lain, kelompokkan ke harian jika operasional
        dailySpending += item.balance;
      }
    }

    return BalanceSummary(
      dailySpendingBalance: dailySpending,
      savingsBalance: savings,
      totalNetWorth: total,
    );
  }

  Future<int> insertAccount(Account account) async {
    final db = await AppDatabase.instance;
    return await db.insert('accounts', account.toMap());
  }

  Future<int> updateAccount(Account account) async {
    final db = await AppDatabase.instance;
    return await db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> archiveAccount(int id) async {
    final db = await AppDatabase.instance;
    return await db.update(
      'accounts',
      {'isArchived': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

