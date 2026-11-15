import '../database/app_database.dart';
import '../models/transaction.dart';
import 'transfer_repository.dart';

class TransactionDetail {
  final TransactionModel transaction;
  final String accountName;
  final String accountColorHex;
  final String? accountLogoKey;
  final String? categoryName;
  final int? categoryIconCodePoint;
  final String? categoryColorHex;

  const TransactionDetail({
    required this.transaction,
    required this.accountName,
    required this.accountColorHex,
    this.accountLogoKey,
    this.categoryName,
    this.categoryIconCodePoint,
    this.categoryColorHex,
  });

  int get id => transaction.id!;
  String get type => transaction.type;
  int get amount => transaction.amount;
  int get accountId => transaction.accountId;
  int? get categoryId => transaction.categoryId;
  String? get note => transaction.note;
  DateTime get date => transaction.date;
  bool get isIncome => transaction.isIncome;
  bool get isExpense => transaction.isExpense;
  String? get imagePath => transaction.imagePath;
  bool get hasReceipt => transaction.hasReceipt;
}

class DailyTransactionsGroup {
  final DateTime date;
  final List<TransactionDetail> items;
  final List<TransferDetail> transfers;
  final int totalIncome;
  final int totalExpense;

  const DailyTransactionsGroup({
    required this.date,
    required this.items,
    this.transfers = const [],
    required this.totalIncome,
    required this.totalExpense,
  });
}

class TransactionRepository {
  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await AppDatabase.instance;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    final db = await AppDatabase.instance;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await AppDatabase.instance;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<TransactionModel?> getTransactionById(int id) async {
    final db = await AppDatabase.instance;
    final maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TransactionModel.fromMap(maps.first);
  }

  Future<List<TransactionDetail>> getRecentTransactionDetails({int limit = 10}) async {
    final db = await AppDatabase.instance;
    final results = await db.rawQuery('''
      SELECT 
        t.*,
        a.name as accountName,
        a.colorHex as accountColorHex,
        a.logoKey as accountLogoKey,
        c.name as categoryName,
        c.iconCodePoint as categoryIconCodePoint,
        c.colorHex as categoryColorHex
      FROM transactions t
      JOIN accounts a ON t.accountId = a.id
      LEFT JOIN categories c ON t.categoryId = c.id
      ORDER BY t.date DESC, t.id DESC
      LIMIT ?
    ''', [limit]);

    return results.map((row) {
      final transaction = TransactionModel.fromMap(row);
      return TransactionDetail(
        transaction: transaction,
        accountName: row['accountName'] as String,
        accountColorHex: row['accountColorHex'] as String,
        accountLogoKey: row['accountLogoKey'] as String?,
        categoryName: row['categoryName'] as String?,
        categoryIconCodePoint: row['categoryIconCodePoint'] as int?,
        categoryColorHex: row['categoryColorHex'] as String?,
      );
    }).toList();
  }

  Future<List<TransactionDetail>> getAllTransactionDetails({
    int? accountId,
    List<int>? accountIds,
    int? categoryId,
    String? type,
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
      whereClauses.add('t.accountId = ?');
      whereArgs.add(accountId);
    } else if (accountIds != null && accountIds.isNotEmpty) {
      final placeholders = List.filled(accountIds.length, '?').join(',');
      whereClauses.add('t.accountId IN ($placeholders)');
      whereArgs.addAll(accountIds);
    }
    if (categoryId != null) {
      whereClauses.add('t.categoryId = ?');
      whereArgs.add(categoryId);
    }
    if (type != null) {
      whereClauses.add('t.type = ?');
      whereArgs.add(type);
    }
    if (startDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      whereClauses.add('t.date >= ?');
      whereArgs.add(start.toIso8601String());
    }
    if (endDate != null) {
      final nextDay = DateTime(endDate.year, endDate.month, endDate.day + 1);
      whereClauses.add('t.date < ?');
      whereArgs.add(nextDay.toIso8601String());
    }

    final whereSql =
        whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final results = await db.rawQuery('''
      SELECT 
        t.*,
        a.name as accountName,
        a.colorHex as accountColorHex,
        a.logoKey as accountLogoKey,
        c.name as categoryName,
        c.iconCodePoint as categoryIconCodePoint,
        c.colorHex as categoryColorHex
      FROM transactions t
      JOIN accounts a ON t.accountId = a.id
      LEFT JOIN categories c ON t.categoryId = c.id
      $whereSql
      ORDER BY t.date DESC, t.id DESC
    ''', whereArgs);

    return results.map((row) {
      final transaction = TransactionModel.fromMap(row);
      return TransactionDetail(
        transaction: transaction,
        accountName: row['accountName'] as String,
        accountColorHex: row['accountColorHex'] as String,
        accountLogoKey: row['accountLogoKey'] as String?,
        categoryName: row['categoryName'] as String?,
        categoryIconCodePoint: row['categoryIconCodePoint'] as int?,
        categoryColorHex: row['categoryColorHex'] as String?,
      );
    }).toList();
  }

  /// Mengelompokkan transaksi & transfer per tanggal (format Notes HP):
  /// Senin, 23 Nov 2026:
  ///   • Transaksi A ...
  ///   • Transfer Mandiri ➔ Cash ...
  /// Total keluar: Rp ... · Total masuk: Rp ...
  Future<List<DailyTransactionsGroup>> getGroupedTransactionsByDate({
    int? accountId,
    List<int>? accountIds,
    int? categoryId,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    final normalizedQuery = searchQuery?.trim().toLowerCase() ?? '';
    final numericQuery = normalizedQuery.replaceAll(RegExp(r'[^0-9]'), '');
    final isNumericSearch = normalizedQuery.isNotEmpty &&
        numericQuery.isNotEmpty &&
        RegExp(r'^[rp\s\.\,0-9]+$').hasMatch(normalizedQuery);

    // 1. Ambil transaksi (income / expense)
    final bool includeTx = type != 'transfer';
    final rawDetails = includeTx
        ? await getAllTransactionDetails(
            accountId: accountId,
            accountIds: accountIds,
            categoryId: categoryId,
            type: (type == 'expense' || type == 'income') ? type : null,
            startDate: startDate,
            endDate: endDate,
          )
        : <TransactionDetail>[];

    final allDetails = normalizedQuery.isEmpty
        ? rawDetails
        : rawDetails
            .where((item) => _matchesTransactionQuery(
                  item,
                  normalizedQuery,
                  numericQuery,
                  isNumericSearch,
                ))
            .toList();

    // 2. Ambil transfer jika filter 'Semua' atau 'transfer'
    final bool includeTransfers =
        (type == null || type == 'transfer') && categoryId == null;
    final transferRepo = TransferRepository();
    final rawTransfers = includeTransfers
        ? await transferRepo.getAllTransfers(
            accountId: accountId,
            accountIds: accountIds,
            startDate: startDate,
            endDate: endDate,
          )
        : <TransferDetail>[];

    final allTransfers = normalizedQuery.isEmpty
        ? rawTransfers
        : rawTransfers
            .where((tr) => _matchesTransferQuery(
                  tr,
                  normalizedQuery,
                  numericQuery,
                  isNumericSearch,
                ))
            .toList();

    final Map<String, List<TransactionDetail>> txGroupedMap = {};
    final Map<String, List<TransferDetail>> trGroupedMap = {};
    final Set<String> allDateKeys = {};

    for (final item in allDetails) {
      final d = item.date;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      allDateKeys.add(key);
      txGroupedMap.putIfAbsent(key, () => []).add(item);
    }

    for (final tr in allTransfers) {
      final d = tr.date;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      allDateKeys.add(key);
      trGroupedMap.putIfAbsent(key, () => []).add(tr);
    }

    final List<DailyTransactionsGroup> groups = [];

    for (final key in allDateKeys) {
      final txItems = txGroupedMap[key] ?? [];
      final trItems = trGroupedMap[key] ?? [];

      DateTime groupDate;
      if (txItems.isNotEmpty) {
        groupDate = txItems.first.date;
      } else {
        groupDate = trItems.first.date;
      }

      int income = 0;
      int expense = 0;

      for (final it in txItems) {
        if (it.isIncome) {
          income += it.amount;
        } else {
          expense += it.amount;
        }
      }

      groups.add(
        DailyTransactionsGroup(
          date: groupDate,
          items: txItems,
          transfers: trItems,
          totalIncome: income,
          totalExpense: expense,
        ),
      );
    }

    // Sort tanggal paling baru di atas
    groups.sort((a, b) => b.date.compareTo(a.date));
    return groups;
  }

  bool _matchesTransactionQuery(
    TransactionDetail item,
    String query,
    String numericQuery,
    bool isNumericSearch,
  ) {
    final noteMatch = (item.note ?? '').toLowerCase().contains(query);
    if (noteMatch) return true;

    final categoryMatch =
        (item.categoryName ?? '').toLowerCase().contains(query);
    if (categoryMatch) return true;

    final accountMatch = item.accountName.toLowerCase().contains(query);
    if (accountMatch) return true;

    if (isNumericSearch && item.amount.toString().contains(numericQuery)) {
      return true;
    }

    return false;
  }

  bool _matchesTransferQuery(
    TransferDetail tr,
    String query,
    String numericQuery,
    bool isNumericSearch,
  ) {
    final noteMatch = (tr.note ?? '').toLowerCase().contains(query);
    if (noteMatch) return true;

    if (query.length >= 3 && 'transfer saldo'.contains(query)) return true;

    if (tr.fromAccountName.toLowerCase().contains(query) ||
        tr.toAccountName.toLowerCase().contains(query)) {
      return true;
    }

    if (isNumericSearch && tr.amount.toString().contains(numericQuery)) {
      return true;
    }

    return false;
  }

  /// Ringkasan pemasukan dan pengeluaran hari ini
  Future<({int income, int expense})> getTodaySummary() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final nextDay = DateTime(now.year, now.month, now.day + 1).toIso8601String();
    final db = await AppDatabase.instance;
    final results = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as expense
      FROM transactions
      WHERE date >= ? AND date < ?
    ''', [startOfDay, nextDay]);
    if (results.isEmpty) return (income: 0, expense: 0);
    return (
      income: (results.first['income'] as num?)?.toInt() ?? 0,
      expense: (results.first['expense'] as num?)?.toInt() ?? 0,
    );
  }

  /// Mengambil daftar transaksi pada tanggal spesifik
  Future<List<TransactionDetail>> getTransactionsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final nextDay = DateTime(date.year, date.month, date.day + 1);
    return getAllTransactionDetails(
      startDate: startOfDay,
      endDate: nextDay,
    );
  }
}
