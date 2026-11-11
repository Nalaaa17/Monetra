/// Model jadwal transaksi berulang otomatis (pemasukan atau pengeluaran rutin).
class RecurringTransaction {
  final int? id;
  final String title;
  final String type; // 'income' | 'expense'
  final int amount;
  final int accountId;
  final int? categoryId;
  final String? note;
  final String frequency; // 'monthly' | 'weekly'
  final int dayOfMonth; // 1..31 (untuk bulanan; menjaga tanggal jangkar saat bulan pendek)
  final int dayOfWeek; // 1..7 (DateTime.monday..DateTime.sunday untuk mingguan)
  final DateTime nextRunDate;
  final DateTime? lastRunDate;
  final bool isActive;
  final DateTime createdAt;

  const RecurringTransaction({
    this.id,
    required this.title,
    required this.type,
    required this.amount,
    required this.accountId,
    this.categoryId,
    this.note,
    required this.frequency,
    this.dayOfMonth = 1,
    this.dayOfWeek = 1,
    required this.nextRunDate,
    this.lastRunDate,
    this.isActive = true,
    required this.createdAt,
  });

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  bool get isMonthly => frequency == 'monthly';
  bool get isWeekly => frequency == 'weekly';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'type': type,
      'amount': amount,
      'accountId': accountId,
      'categoryId': categoryId,
      'note': note,
      'frequency': frequency,
      'dayOfMonth': dayOfMonth,
      'dayOfWeek': dayOfWeek,
      'nextRunDate': DateTime(
        nextRunDate.year,
        nextRunDate.month,
        nextRunDate.day,
      ).toIso8601String(),
      'lastRunDate': lastRunDate != null
          ? DateTime(
              lastRunDate!.year,
              lastRunDate!.month,
              lastRunDate!.day,
            ).toIso8601String()
          : null,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    final parsedNext = DateTime.parse(map['nextRunDate'] as String);
    final rawLast = map['lastRunDate'] as String?;
    return RecurringTransaction(
      id: map['id'] as int?,
      title: map['title'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toInt(),
      accountId: (map['accountId'] as num).toInt(),
      categoryId: (map['categoryId'] as num?)?.toInt(),
      note: map['note'] as String?,
      frequency: map['frequency'] as String,
      dayOfMonth: (map['dayOfMonth'] as num?)?.toInt() ?? parsedNext.day,
      dayOfWeek: (map['dayOfWeek'] as num?)?.toInt() ?? parsedNext.weekday,
      nextRunDate: DateTime(parsedNext.year, parsedNext.month, parsedNext.day),
      lastRunDate: rawLast != null && rawLast.isNotEmpty
          ? (() {
              final d = DateTime.parse(rawLast);
              return DateTime(d.year, d.month, d.day);
            })()
          : null,
      isActive: ((map['isActive'] as num?)?.toInt() ?? 1) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  RecurringTransaction copyWith({
    int? id,
    String? title,
    String? type,
    int? amount,
    int? accountId,
    int? categoryId,
    bool clearCategoryId = false,
    String? note,
    bool clearNote = false,
    String? frequency,
    int? dayOfMonth,
    int? dayOfWeek,
    DateTime? nextRunDate,
    DateTime? lastRunDate,
    bool clearLastRunDate = false,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      accountId: accountId ?? this.accountId,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      note: clearNote ? null : (note ?? this.note),
      frequency: frequency ?? this.frequency,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      nextRunDate: nextRunDate ?? this.nextRunDate,
      lastRunDate:
          clearLastRunDate ? null : (lastRunDate ?? this.lastRunDate),
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

