import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/app_database.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../services/notification_service.dart';

/// Gabungan jadwal transaksi berulang beserta informasi dompet dan kategori.
class RecurringTransactionDetail {
  final RecurringTransaction rule;
  final String accountName;
  final String accountColorHex;
  final String? accountLogoKey;
  final bool accountIsArchived;
  final String? categoryName;
  final int? categoryIconCodePoint;
  final String? categoryColorHex;

  const RecurringTransactionDetail({
    required this.rule,
    required this.accountName,
    required this.accountColorHex,
    this.accountLogoKey,
    this.accountIsArchived = false,
    this.categoryName,
    this.categoryIconCodePoint,
    this.categoryColorHex,
  });

  int get id => rule.id!;
  String get title => rule.title;
  String get type => rule.type;
  int get amount => rule.amount;
  int get accountId => rule.accountId;
  int? get categoryId => rule.categoryId;
  String? get note => rule.note;
  String get frequency => rule.frequency;
  int get dayOfMonth => rule.dayOfMonth;
  int get dayOfWeek => rule.dayOfWeek;
  DateTime get nextRunDate => rule.nextRunDate;
  DateTime? get lastRunDate => rule.lastRunDate;
  bool get isActive => rule.isActive;
  bool get isIncome => rule.isIncome;
  bool get isExpense => rule.isExpense;
  bool get isMonthly => rule.isMonthly;
  bool get isWeekly => rule.isWeekly;

  /// Label ringkas frekuensi jadwal dalam Bahasa Indonesia.
  String get scheduleLabel {
    if (isWeekly) {
      return 'Tiap hari ${RecurringTransactionRepository.weekdayName(dayOfWeek)}';
    }
    return 'Tiap tanggal $dayOfMonth';
  }
}

/// Hasil eksekusi sinkronisasi transaksi berulang yang jatuh tempo.
class RecurringSyncResult {
  final int createdCount;
  final List<String> createdTitles;

  const RecurringSyncResult({
    required this.createdCount,
    this.createdTitles = const [],
  });
}

/// Ringkasan estimasi arus kas rutin bulanan dari jadwal yang aktif.
class RecurringMonthlySummary {
  final int activeCount;
  final int pausedCount;
  final int monthlyExpenseEstimate;
  final int monthlyIncomeEstimate;
  final bool hasWeeklyRule;

  const RecurringMonthlySummary({
    required this.activeCount,
    required this.pausedCount,
    required this.monthlyExpenseEstimate,
    required this.monthlyIncomeEstimate,
    this.hasWeeklyRule = false,
  });

  int get netMonthlyEstimate => monthlyIncomeEstimate - monthlyExpenseEstimate;
}

class RecurringTransactionRepository {
  static Future<RecurringSyncResult>? _inFlightSync;
  static const int _maxCatchUpCyclesPerRule = 36;

  static DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  static String weekdayName(int dayOfWeek) {
    const names = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    final idx = (dayOfWeek - 1).clamp(0, 6);
    return names[idx];
  }

  static String shortWeekdayName(int dayOfWeek) {
    const names = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final idx = (dayOfWeek - 1).clamp(0, 6);
    return names[idx];
  }

  /// Menghitung tanggal siklus bulan berikutnya dengan mempertahankan `anchorDay`
  /// agar tanggal 31 tetap kembali ke 31 pada bulan panjang setelah bulan Feb/Apr.
  static DateTime nextMonthlyDate(DateTime currentDate, int anchorDay) {
    var year = currentDate.year;
    var month = currentDate.month + 1;
    if (month > 12) {
      month = 1;
      year += 1;
    }
    final clampedDay = anchorDay.clamp(1, daysInMonth(year, month));
    return DateTime(year, month, clampedDay);
  }

  /// Menghitung jadwal eksekusi berikutnya setelah [afterDate].
  static DateTime computeNextRunDate({
    required String frequency,
    required DateTime afterDate,
    required int dayOfMonth,
    required int dayOfWeek,
  }) {
    final base = dateOnly(afterDate);
    if (frequency == 'weekly') {
      return base.add(const Duration(days: 7));
    }
    return nextMonthlyDate(base, dayOfMonth);
  }

  /// Menghitung tanggal jatuh tempo pertama/berikutnya relatif terhadap [referenceDate].
  static DateTime computeFirstDueDate({
    required String frequency,
    required int dayOfMonth,
    required int dayOfWeek,
    DateTime? referenceDate,
    bool includeToday = true,
  }) {
    final today = dateOnly(referenceDate ?? DateTime.now());
    if (frequency == 'weekly') {
      final targetWeekday = dayOfWeek.clamp(DateTime.monday, DateTime.sunday);
      var delta = (targetWeekday - today.weekday) % 7;
      if (!includeToday && delta == 0) {
        delta = 7;
      }
      return today.add(Duration(days: delta));
    }

    final thisMonthDay = dayOfMonth.clamp(1, daysInMonth(today.year, today.month));
    final thisMonthCandidate = DateTime(today.year, today.month, thisMonthDay);
    if (thisMonthCandidate.isBefore(today) ||
        (!includeToday && thisMonthCandidate == today)) {
      return nextMonthlyDate(
        DateTime(today.year, today.month, 1),
        dayOfMonth,
      );
    }
    return thisMonthCandidate;
  }

  Future<int> insertRecurring(RecurringTransaction rule) async {
    final db = await AppDatabase.instance;
    return await db.insert('recurring_transactions', rule.toMap());
  }

  Future<int> updateRecurring(RecurringTransaction rule) async {
    final db = await AppDatabase.instance;
    return await db.update(
      'recurring_transactions',
      rule.toMap(),
      where: 'id = ?',
      whereArgs: [rule.id],
    );
  }

  Future<int> deleteRecurring(int id) async {
    final db = await AppDatabase.instance;
    return await db.delete(
      'recurring_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mengaktifkan atau menjeda jadwal rutin; saat diaktifkan kembali dengan tanggal
  /// kedaluwarsa, jadwal otomatis digeser ke siklus mendatang agar bulan terlewati
  /// selama masa jeda tidak ikut tercatat mendadak.
  Future<int> toggleActive(
    int id,
    bool isActive, {
    DateTime? referenceDate,
  }) async {
    final db = await AppDatabase.instance;
    if (!isActive) {
      return await db.update(
        'recurring_transactions',
        {'isActive': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    final rows = await db.query(
      'recurring_transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return 0;

    final rule = RecurringTransaction.fromMap(rows.first);
    final today = dateOnly(referenceDate ?? DateTime.now());
    var nextRun = dateOnly(rule.nextRunDate);
    if (nextRun.isBefore(today)) {
      nextRun = computeFirstDueDate(
        frequency: rule.frequency,
        dayOfMonth: rule.dayOfMonth,
        dayOfWeek: rule.dayOfWeek,
        referenceDate: today,
        includeToday: true,
      );
    }

    return await db.update(
      'recurring_transactions',
      {
        'isActive': 1,
        'nextRunDate': nextRun.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<RecurringTransactionDetail>> getAllRecurringDetails() async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery('''
      SELECT
        r.*,
        a.name as accountName,
        a.colorHex as accountColorHex,
        a.logoKey as accountLogoKey,
        a.isArchived as accountIsArchived,
        c.name as categoryName,
        c.iconCodePoint as categoryIconCodePoint,
        c.colorHex as categoryColorHex
      FROM recurring_transactions r
      JOIN accounts a ON r.accountId = a.id
      LEFT JOIN categories c ON r.categoryId = c.id
      ORDER BY r.isActive DESC, r.nextRunDate ASC, r.id DESC
    ''');

    return rows.map((row) {
      final rule = RecurringTransaction.fromMap(row);
      return RecurringTransactionDetail(
        rule: rule,
        accountName: row['accountName'] as String,
        accountColorHex: row['accountColorHex'] as String,
        accountLogoKey: row['accountLogoKey'] as String?,
        accountIsArchived: ((row['accountIsArchived'] as num?)?.toInt() ?? 0) == 1,
        categoryName: row['categoryName'] as String?,
        categoryIconCodePoint: (row['categoryIconCodePoint'] as num?)?.toInt(),
        categoryColorHex: row['categoryColorHex'] as String?,
      );
    }).toList();
  }

  static RecurringMonthlySummary summarizeRules(
    List<RecurringTransactionDetail> items,
  ) {
    int active = 0;
    int paused = 0;
    int expense = 0;
    int income = 0;
    bool hasWeekly = false;

    for (final item in items) {
      if (!item.isActive) {
        paused++;
        continue;
      }
      active++;
      if (item.isWeekly) hasWeekly = true;
      final monthlyAmount = item.isWeekly ? item.amount * 4 : item.amount;
      if (item.isIncome) {
        income += monthlyAmount;
      } else {
        expense += monthlyAmount;
      }
    }

    return RecurringMonthlySummary(
      activeCount: active,
      pausedCount: paused,
      monthlyExpenseEstimate: expense,
      monthlyIncomeEstimate: income,
      hasWeeklyRule: hasWeekly,
    );
  }

  /// Menjalankan semua transaksi berulang aktif yang telah jatuh tempo (`<= hari ini`).
  /// Menggunakan deduplikasi in-flight saat dipanggil tanpa [referenceDate].
  Future<RecurringSyncResult> syncRecurringTransactions({
    DateTime? referenceDate,
  }) {
    if (referenceDate == null && _inFlightSync != null) {
      return _inFlightSync!;
    }
    final future = _runSyncRecurringTransactions(referenceDate: referenceDate);
    if (referenceDate == null) {
      _inFlightSync = future.whenComplete(() {
        _inFlightSync = null;
      });
      return _inFlightSync!;
    }
    return future;
  }

  Future<RecurringSyncResult> _runSyncRecurringTransactions({
    DateTime? referenceDate,
  }) async {
    final db = await AppDatabase.instance;
    final ref = referenceDate ?? DateTime.now();
    final today = dateOnly(ref);

    // Pemeriksaan cepat baca-saja agar tidak membuka kunci transaksi tulis jika belum ada jadwal jatuh tempo
    final candidateRows = await db.query(
      'recurring_transactions',
      columns: ['nextRunDate'],
      where: 'isActive = 1',
    );
    final hasDueRule = candidateRows.any((row) {
      final raw = row['nextRunDate'] as String?;
      if (raw == null) return false;
      final d = DateTime.tryParse(raw);
      if (d == null) return false;
      return !dateOnly(d).isAfter(today);
    });
    if (!hasDueRule) {
      return const RecurringSyncResult(createdCount: 0);
    }

    final List<String> createdTitles = [];

    await db.transaction((txn) async {
      final rows = await txn.query(
        'recurring_transactions',
        where: 'isActive = 1',
      );

      for (final row in rows) {
        final rule = RecurringTransaction.fromMap(row);
        if (rule.id == null) continue;

        var dueDay = dateOnly(rule.nextRunDate);
        if (dueDay.isAfter(today)) continue;

        final validAccount = await _accountExists(txn, rule.accountId);
        if (!validAccount) continue;
        final validCategoryId = await _validateCategoryId(txn, rule.categoryId);

        DateTime? lastExecuted;
        int cycles = 0;

        while (!dueDay.isAfter(today) && cycles < _maxCatchUpCyclesPerRule) {
          final txDate = DateTime(dueDay.year, dueDay.month, dueDay.day, 9, 0);
          await _insertTransactionFromRule(
            txn: txn,
            rule: rule,
            validatedCategoryId: validCategoryId,
            txDate: txDate,
            createdAt: ref,
          );
          createdTitles.add(rule.title);
          lastExecuted = dueDay;
          dueDay = computeNextRunDate(
            frequency: rule.frequency,
            afterDate: dueDay,
            dayOfMonth: rule.dayOfMonth,
            dayOfWeek: rule.dayOfWeek,
          );
          cycles++;
        }

        // Jika masih tertinggal > maxCatchUpCycles, lompat maju agar tidak loop berulang
        while (!dueDay.isAfter(today)) {
          dueDay = computeNextRunDate(
            frequency: rule.frequency,
            afterDate: dueDay,
            dayOfMonth: rule.dayOfMonth,
            dayOfWeek: rule.dayOfWeek,
          );
        }

        if (lastExecuted != null) {
          await txn.update(
            'recurring_transactions',
            {
              'nextRunDate': dueDay.toIso8601String(),
              'lastRunDate': lastExecuted.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [rule.id],
          );
        }
      }
    });

    if (createdTitles.isNotEmpty) {
      await NotificationService.showRecurringRecordedNotification(
        count: createdTitles.length,
        titles: createdTitles,
      );
    }

    return RecurringSyncResult(
      createdCount: createdTitles.length,
      createdTitles: createdTitles,
    );
  }

  /// Menghitung jadwal berikutnya sesudah eksekusi manual [recordOccurrenceNow].
  static DateTime previewNextRunAfterManualRecord(
    RecurringTransaction rule, {
    DateTime? referenceDate,
  }) {
    final today = dateOnly(referenceDate ?? DateTime.now());
    final anchorNext = computeNextRunDate(
      frequency: rule.frequency,
      afterDate: rule.nextRunDate.isAfter(today) ? rule.nextRunDate : today,
      dayOfMonth: rule.dayOfMonth,
      dayOfWeek: rule.dayOfWeek,
    );
    final minFutureNext = computeFirstDueDate(
      frequency: rule.frequency,
      dayOfMonth: rule.dayOfMonth,
      dayOfWeek: rule.dayOfWeek,
      referenceDate: today,
      includeToday: false,
    );
    return anchorNext.isAfter(minFutureNext) ? anchorNext : minFutureNext;
  }

  /// Mencatat 1 transaksi rutin secara langsung hari ini dan memajukan jadwal berikutnya
  /// ke siklus sesudahnya agar tidak tercatat ganda saat tanggal jatuh tempo tiba.
  Future<DateTime?> recordOccurrenceNow(
    int recurringId, {
    DateTime? referenceDate,
  }) async {
    final db = await AppDatabase.instance;
    final ref = referenceDate ?? DateTime.now();
    final today = dateOnly(ref);
    DateTime? updatedNextRun;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'recurring_transactions',
        where: 'id = ?',
        whereArgs: [recurringId],
        limit: 1,
      );
      if (rows.isEmpty) return;

      final rule = RecurringTransaction.fromMap(rows.first);
      final validAccount = await _accountExists(txn, rule.accountId);
      if (!validAccount) return;
      final validCategoryId = await _validateCategoryId(txn, rule.categoryId);

      await _insertTransactionFromRule(
        txn: txn,
        rule: rule,
        validatedCategoryId: validCategoryId,
        txDate: ref,
        createdAt: ref,
      );

      updatedNextRun = previewNextRunAfterManualRecord(rule, referenceDate: ref);

      await txn.update(
        'recurring_transactions',
        {
          'nextRunDate': updatedNextRun!.toIso8601String(),
          'lastRunDate': today.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [recurringId],
      );
    });

    return updatedNextRun;
  }

  Future<bool> _accountExists(DatabaseExecutor txn, int accountId) async {
    final rows = await txn.query(
      'accounts',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int?> _validateCategoryId(
    DatabaseExecutor txn,
    int? categoryId,
  ) async {
    if (categoryId == null) return null;
    final rows = await txn.query(
      'categories',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [categoryId],
      limit: 1,
    );
    return rows.isNotEmpty ? categoryId : null;
  }

  Future<void> _insertTransactionFromRule({
    required DatabaseExecutor txn,
    required RecurringTransaction rule,
    required int? validatedCategoryId,
    required DateTime txDate,
    required DateTime createdAt,
  }) async {
    final extraNote = rule.note?.trim();
    final formattedNote = (extraNote != null && extraNote.isNotEmpty)
        ? '${rule.title} • $extraNote (Rutin)'
        : '${rule.title} (Rutin)';

    final tx = TransactionModel(
      type: rule.type,
      amount: rule.amount,
      accountId: rule.accountId,
      categoryId: validatedCategoryId,
      note: formattedNote,
      date: txDate,
      createdAt: createdAt,
    );
    await txn.insert('transactions', tx.toMap());
  }
}
