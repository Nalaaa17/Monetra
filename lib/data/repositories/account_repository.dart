import '../database/app_database.dart';
import '../models/account.dart';
import '../models/goal.dart';
import '../models/transaction.dart';
import '../services/notification_service.dart';
import 'vacation_repository.dart';

class BalanceProjectionWarning {
  final String accountName;
  final int projectedBalance;

  const BalanceProjectionWarning({
    required this.accountName,
    required this.projectedBalance,
  });
}

class AccountWithBalance {
  final Account account;
  final int balance; // Saldo bebas / siap pakai (sudah dikurangi alokasi Goal, Utang & Liburan)
  final int allocatedInGoals; // Dana yang disisihkan di Target/Goal
  final int allocatedInDebts; // Dana yang disisihkan di Utang
  final int allocatedInVacation; // Dana yang disisihkan di Kantong Liburan

  const AccountWithBalance({
    required this.account,
    required this.balance,
    this.allocatedInGoals = 0,
    this.allocatedInDebts = 0,
    this.allocatedInVacation = 0,
  });

  int get totalAllocated =>
      allocatedInGoals + allocatedInDebts + allocatedInVacation;
  int get physicalBalance => balance + totalAllocated;
  int get id => account.id!;
  String get name => account.name;
  String get type => account.type;
  String get category => account.category;
  bool get isSavings => account.isSavings;
  String get colorHex => account.colorHex;
  int get iconCodePoint => account.iconCodePoint;
  String? get logoKey => account.logoKey;
}

class BalanceSummary {
  final int dailySpendingBalance; // Saldo bebas Uang Harian
  final int savingsBalance; // Saldo bebas Tabungan
  final int totalNetWorth; // Total saldo bebas siap pakai (tidak termasuk dana Target/Utang/Liburan)
  final int allocatedInGoals; // Total dana yang disisihkan di Target
  final int allocatedInDebts; // Total dana yang disisihkan di Utang
  final int allocatedInVacation; // Total dana yang disisihkan di Kantong Liburan
  final List<String> dailyAccountNames;
  final List<String> savingsAccountNames;

  const BalanceSummary({
    required this.dailySpendingBalance,
    required this.savingsBalance,
    required this.totalNetWorth,
    this.allocatedInGoals = 0,
    this.allocatedInDebts = 0,
    this.allocatedInVacation = 0,
    this.dailyAccountNames = const [],
    this.savingsAccountNames = const [],
  });

  int get totalAllocated =>
      allocatedInGoals + allocatedInDebts + allocatedInVacation;
  int get totalPhysicalNetWorth => totalNetWorth + totalAllocated;
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

    // 6. Sum dana yang disisihkan di Target/Goal (belum direalisasikan)
    final allocatedInGoals = await calculateGoalAllocatedForAccount(accountId);

    // 7. Sum dana yang disisihkan di Utang (belum keluar fisik)
    final allocatedInDebts = await calculateDebtAllocatedForAccount(accountId);

    // 8. Sum dana yang disisihkan di Kantong Liburan aktif
    final allocatedInVacations =
        await VacationRepository().calculateVacationAllocatedForAccount(accountId);

    return initialBalance +
        totalIncome -
        totalExpense +
        totalTransferIn -
        totalTransferOut -
        allocatedInGoals -
        allocatedInDebts -
        allocatedInVacations;
  }

  /// Menghitung total dana yang sedang disisihkan di Target dari rekening ini
  Future<int> calculateGoalAllocatedForAccount(int accountId) async {
    final db = await AppDatabase.instance;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(gc.amount), 0) as total
      FROM goal_contributions gc
      JOIN goals g ON gc.goalId = g.id
      WHERE gc.sourceAccountId = ? AND gc.isRealized = 0
    ''', [accountId]);
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  /// Menghitung seluruh dana aktif yang terkunci di semua Target
  Future<int> calculateTotalAllocatedInGoals() async {
    final db = await AppDatabase.instance;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(gc.amount), 0) as total
      FROM goal_contributions gc
      JOIN goals g ON gc.goalId = g.id
      WHERE gc.isRealized = 0
    ''');
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  /// Menghitung total dana yang sedang disisihkan di Utang dari rekening ini
  Future<int> calculateDebtAllocatedForAccount(int accountId) async {
    final db = await AppDatabase.instance;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(dc.amount), 0) as total
      FROM debt_contributions dc
      JOIN debts d ON dc.debtId = d.id
      WHERE dc.sourceAccountId = ? AND dc.isRealized = 0
    ''', [accountId]);
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  /// Menghitung seluruh dana aktif yang terkunci di semua Utang
  Future<int> calculateTotalAllocatedInDebts() async {
    final db = await AppDatabase.instance;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(dc.amount), 0) as total
      FROM debt_contributions dc
      JOIN debts d ON dc.debtId = d.id
      WHERE dc.isRealized = 0
    ''');
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<AccountWithBalance>> getAllAccountsWithBalances({
    bool includeArchived = false,
  }) async {
    final accounts = await getAllAccounts(includeArchived: includeArchived);
    final List<AccountWithBalance> result = [];

    for (final acc in accounts) {
      final balance = await calculateAccountBalance(acc.id!);
      final allocatedGoals = await calculateGoalAllocatedForAccount(acc.id!);
      final allocatedDebts = await calculateDebtAllocatedForAccount(acc.id!);
      final allocatedVacations =
          await VacationRepository().calculateVacationAllocatedForAccount(acc.id!);
      result.add(AccountWithBalance(
        account: acc,
        balance: balance,
        allocatedInGoals: allocatedGoals,
        allocatedInDebts: allocatedDebts,
        allocatedInVacation: allocatedVacations,
      ));
    }

    return result;
  }

  /// Mengambil semua akun beserta saldo bebasnya untuk profil tertentu
  Future<List<AccountWithBalance>> getAccountsWithBalancesForProfile(
    String profileKey,
  ) async {
    final db = await AppDatabase.getDatabaseForProfile(profileKey);
    final rows = await db.query(
      'accounts',
      where: 'isArchived = 0',
      orderBy: 'id ASC',
    );
    final accounts = rows.map((r) => Account.fromMap(r)).toList();
    final List<AccountWithBalance> result = [];

    for (final acc in accounts) {
      final accountId = acc.id!;
      final initialBalance = acc.initialBalance;

      final incRes = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE accountId = ? AND type = 'income'",
        [accountId],
      );
      final inc = (incRes.first['total'] as num?)?.toInt() ?? 0;

      final expRes = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE accountId = ? AND type = 'expense'",
        [accountId],
      );
      final exp = (expRes.first['total'] as num?)?.toInt() ?? 0;

      final tInRes = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) as total FROM transfers WHERE toAccountId = ?",
        [accountId],
      );
      final tIn = (tInRes.first['total'] as num?)?.toInt() ?? 0;

      final tOutRes = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) as total FROM transfers WHERE fromAccountId = ?",
        [accountId],
      );
      final tOut = (tOutRes.first['total'] as num?)?.toInt() ?? 0;

      final balance = initialBalance + inc - exp + tIn - tOut;
      result.add(AccountWithBalance(
        account: acc,
        balance: balance,
      ));
    }

    return result;
  }

  Future<BalanceSummary> getBalanceSummary() async {
    final accountsWithBalance = await getAllAccountsWithBalances();
    final totalAllocatedInGoals = await calculateTotalAllocatedInGoals();
    final totalAllocatedInDebts = await calculateTotalAllocatedInDebts();
    final totalAllocatedInVacations =
        await VacationRepository().calculateTotalAllocatedInVacations();

    int dailySpending = 0;
    int savings = 0;
    int total = 0;
    final List<String> dailyNames = [];
    final List<String> savingsNames = [];

    for (final item in accountsWithBalance) {
      total += item.balance;
      final isSavings = item.account.category == 'tabungan';

      if (isSavings) {
        savings += item.balance;
        savingsNames.add(item.name);
      } else {
        dailySpending += item.balance;
        dailyNames.add(item.name);
      }
    }

    return BalanceSummary(
      dailySpendingBalance: dailySpending,
      savingsBalance: savings,
      totalNetWorth: total,
      allocatedInGoals: totalAllocatedInGoals,
      allocatedInDebts: totalAllocatedInDebts,
      allocatedInVacation: totalAllocatedInVacations,
      dailyAccountNames: dailyNames,
      savingsAccountNames: savingsNames,
    );
  }

  /// Memeriksa apakah transaksi pengeluaran baru menyebabkan saldo akun menjadi minus.
  Future<bool> checkNewTransactionBalanceWarning({
    required int accountId,
    required int amount,
    required String type,
  }) async {
    if (type == 'income' || amount <= 0) return false;
    final currentBal = await calculateAccountBalance(accountId);
    final projected = currentBal - amount;
    return projected < 0 && (currentBal >= 0 || projected < currentBal);
  }

  /// Memeriksa apakah perubahan transaksi (edit nominal/tipe/akun)
  /// menyebabkan saldo akun terkait menjadi minus atau semakin minus.
  Future<BalanceProjectionWarning?> checkEditTransactionBalanceWarning({
    required TransactionModel original,
    required String newType,
    required int newAmount,
    required int newAccountId,
  }) async {
    final newAcc = await getAccountById(newAccountId);
    final currentNewBal = await calculateAccountBalance(newAccountId);
    final newEffect = newType == 'income' ? newAmount : -newAmount;
    final oldEffect = original.isIncome ? original.amount : -original.amount;

    if (newAccountId == original.accountId) {
      final projected = currentNewBal - oldEffect + newEffect;
      if (projected < 0 && (currentNewBal >= 0 || projected < currentNewBal)) {
        return BalanceProjectionWarning(
          accountName: newAcc?.name ?? 'Akun ini',
          projectedBalance: projected,
        );
      }
      return null;
    }

    final projectedNew = currentNewBal + newEffect;
    if (projectedNew < 0 &&
        (currentNewBal >= 0 || projectedNew < currentNewBal)) {
      return BalanceProjectionWarning(
        accountName: newAcc?.name ?? 'Akun tujuan',
        projectedBalance: projectedNew,
      );
    }

    final oldAcc = await getAccountById(original.accountId);
    final currentOldBal = await calculateAccountBalance(original.accountId);
    final projectedOld = currentOldBal - oldEffect;
    if (projectedOld < 0 &&
        (currentOldBal >= 0 || projectedOld < currentOldBal)) {
      return BalanceProjectionWarning(
        accountName: oldAcc?.name ?? 'Akun asal',
        projectedBalance: projectedOld,
      );
    }

    return null;
  }

  /// Memeriksa apakah perubahan transfer menyebabkan salah satu akun terkait
  /// (termasuk akun tujuan lama saat nominal/akun berubah) menjadi minus.
  Future<BalanceProjectionWarning?> checkEditTransferBalanceWarning({
    required int oldFromAccountId,
    required int oldToAccountId,
    required int oldAmount,
    required int newFromAccountId,
    required int newToAccountId,
    required int newAmount,
  }) async {
    final affectedIds = <int>{
      oldFromAccountId,
      oldToAccountId,
      newFromAccountId,
      newToAccountId,
    };

    for (final accId in affectedIds) {
      int delta = 0;
      if (accId == oldFromAccountId) delta += oldAmount;
      if (accId == oldToAccountId) delta -= oldAmount;
      if (accId == newFromAccountId) delta -= newAmount;
      if (accId == newToAccountId) delta += newAmount;

      if (delta >= 0) continue;

      final currentBal = await calculateAccountBalance(accId);
      final projected = currentBal + delta;
      if (projected < 0 && (currentBal >= 0 || projected < currentBal)) {
        final acc = await getAccountById(accId);
        return BalanceProjectionWarning(
          accountName: acc?.name ?? 'Akun ini',
          projectedBalance: projected,
        );
      }
    }

    return null;
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

  Future<int> updateAccountCategory(int id, String category) async {
    final db = await AppDatabase.instance;
    return await db.update(
      'accounts',
      {'category': category},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAccount(int id) async {
    final db = await AppDatabase.instance;
    final List<int> deletedGoalIds = [];
    final List<Goal> rescheduledOtherGoals = [];

    final deletedRows = await db.transaction((txn) async {
      // 1. Kumpulkan semua goal yang dimiliki oleh akun ini untuk cancel notifikasinya
      final ownedGoalRows = await txn.query(
        'goals',
        columns: ['id'],
        where: 'sourceAccountId = ?',
        whereArgs: [id],
      );
      for (final r in ownedGoalRows) {
        final gid = r['id'] as int?;
        if (gid != null) deletedGoalIds.add(gid);
      }

      // 2. Hitung kontribusi aktif (belum realized) dari akun ini pada goal milik akun LAIN
      final affectedOtherRows = await txn.rawQuery('''
        SELECT gc.goalId, COALESCE(SUM(gc.amount), 0) as removedLocked
        FROM goal_contributions gc
        JOIN goals g ON gc.goalId = g.id
        WHERE gc.sourceAccountId = ? AND g.sourceAccountId != ? AND gc.isRealized = 0
        GROUP BY gc.goalId
      ''', [id, id]);

      // Hapus kontribusi milik goal yang ikut terhapus maupun yang berasal dari akun ini
      if (deletedGoalIds.isNotEmpty) {
        final placeholders = List.filled(deletedGoalIds.length, '?').join(',');
        await txn.delete(
          'goal_contributions',
          where: 'goalId IN ($placeholders)',
          whereArgs: deletedGoalIds,
        );
      }
      await txn.delete(
        'goal_contributions',
        where: 'sourceAccountId = ?',
        whereArgs: [id],
      );

      // Sinkronkan collectedAmount & status pada goal akun lain yang setorannya terhapus
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      for (final row in affectedOtherRows) {
        final otherGoalId = row['goalId'] as int;
        final removedLocked = (row['removedLocked'] as num?)?.toInt() ?? 0;
        if (removedLocked <= 0) continue;

        final goalMaps = await txn.query(
          'goals',
          where: 'id = ?',
          whereArgs: [otherGoalId],
          limit: 1,
        );
        if (goalMaps.isEmpty) continue;

        final otherGoal = Goal.fromMap(goalMaps.first);
        final updatedCollected =
            (otherGoal.collectedAmount - removedLocked).clamp(0, otherGoal.collectedAmount);
        final deadlineDay = DateTime(
          otherGoal.deadline.year,
          otherGoal.deadline.month,
          otherGoal.deadline.day,
        );
        final String updatedStatus;
        if (updatedCollected >= otherGoal.targetAmount) {
          updatedStatus = 'done';
        } else if (deadlineDay.isBefore(today)) {
          updatedStatus = 'missed';
        } else {
          updatedStatus = 'active';
        }

        await txn.update(
          'goals',
          {
            'collectedAmount': updatedCollected,
            'status': updatedStatus,
          },
          where: 'id = ?',
          whereArgs: [otherGoalId],
        );

        rescheduledOtherGoals.add(
          otherGoal.copyWith(
            collectedAmount: updatedCollected,
            status: updatedStatus,
          ),
        );
      }

      // 3. Hapus transaksi, transfer, jadwal berulang, goal milik akun ini, dan akun itu sendiri
      await txn.delete('transactions', where: 'accountId = ?', whereArgs: [id]);
      await txn.delete(
        'transfers',
        where: 'fromAccountId = ? OR toAccountId = ?',
        whereArgs: [id, id],
      );
      await txn.delete(
        'recurring_transactions',
        where: 'accountId = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'vacation_allocations',
        where: 'sourceAccountId = ?',
        whereArgs: [id],
      );
      await txn.delete('goals', where: 'sourceAccountId = ?', whereArgs: [id]);
      return await txn.delete('accounts', where: 'id = ?', whereArgs: [id]);
    });

    for (final gid in deletedGoalIds) {
      await NotificationService.cancelGoalReminder(gid);
    }
    for (final g in rescheduledOtherGoals) {
      if (g.id == null) continue;
      if (g.reminderEnabled && !g.isDone && g.status == 'active') {
        await NotificationService.scheduleGoalReminder(
          goalId: g.id!,
          goalName: g.name,
          deadline: g.deadline,
          remainingAmount: g.remainingAmount,
        );
      } else {
        await NotificationService.cancelGoalReminder(g.id!);
      }
    }

    return deletedRows;
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

