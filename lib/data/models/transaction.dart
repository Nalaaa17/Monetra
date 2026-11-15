class TransactionModel {
  final int? id;
  final String type; // 'income' | 'expense'
  final int amount; // Positif
  final int accountId;
  final int? categoryId;
  final String? note;
  final DateTime date;
  final DateTime createdAt;
  final String? imagePath;

  const TransactionModel({
    this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    this.categoryId,
    this.note,
    required this.date,
    required this.createdAt,
    this.imagePath,
  });

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  bool get hasReceipt => imagePath != null && imagePath!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type,
      'amount': amount,
      'accountId': accountId,
      'categoryId': categoryId,
      'note': note,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'imagePath': imagePath,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      type: map['type'] as String,
      amount: map['amount'] as int,
      accountId: map['accountId'] as int,
      categoryId: map['categoryId'] as int?,
      note: map['note'] as String?,
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      imagePath: map['imagePath'] as String?,
    );
  }

  TransactionModel copyWith({
    int? id,
    String? type,
    int? amount,
    int? accountId,
    int? categoryId,
    String? note,
    DateTime? date,
    DateTime? createdAt,
    String? imagePath,
    bool clearImage = false,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
    );
  }
}
