import '../database/app_database.dart';
import '../models/transaction.dart';
import 'transfer_repository.dart';

class TransactionDetail {
  final TransactionModel transaction;
  final String accountName;
  final String accountColorHex;
  final String? categoryName;
  final int? categoryIconCodePoint;
  final String? categoryColorHex;

  const TransactionDetail({
    required this.transaction,
    required this.accountName,
    required this.accountColorHex,
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
        categoryName: row['categoryName'] as String?,
        categoryIconCodePoint: row['categoryIconCodePoint'] as int?,
        categoryColorHex: row['categoryColorHex'] as String?,
      );
    }).toList();
  }

  Future<List<TransactionDetail>> getAllTransactionDetails({
    int? accountId,
    int? categoryId,
    String? type,
  }) async {
    final db = await AppDatabase.instance;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (accountId != null) {
      whereClauses.add('t.accountId = ?');
      whereArgs.add(accountId);
    }
    if (categoryId != null) {
      whereClauses.add('t.categoryId = ?');
      whereArgs.add(categoryId);
    }
    if (type != null) {
      whereClauses.add('t.type = ?');
      whereArgs.add(type);
    }

    final whereSql =
        whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final results = await db.rawQuery('''
      SELECT 
        t.*,
        a.name as accountName,
        a.colorHex as accountColorHex,
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
    int? categoryId,
    String? type,
  }) async {
    // 1. Ambil transaksi (income / expense)
    final bool includeTx = type != 'transfer';
    final allDetails = includeTx
        ? await getAllTransactionDetails(
            accountId: accountId,
            categoryId: categoryId,
            type: (type == 'expense' || type == 'income') ? type : null,
          )
        : <TransactionDetail>[];

    // 2. Ambil transfer jika filter 'Semua' atau 'transfer'
    final bool includeTransfers = (type == null || type == 'transfer') && categoryId == null;
    final transferRepo = TransferRepository();
    final allTransfers = includeTransfers
        ? await transferRepo.getAllTransfers(accountId: accountId)
        : <TransferDetail>[];

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
}
