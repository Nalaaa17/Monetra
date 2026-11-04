class TransferModel {
  final int? id;
  final int fromAccountId;
  final int toAccountId;
  final int amount;
  final String? note;
  final DateTime date;
  final DateTime createdAt;

  const TransferModel({
    this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    this.note,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'fromAccountId': fromAccountId,
      'toAccountId': toAccountId,
      'amount': amount,
      'note': note,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TransferModel.fromMap(Map<String, dynamic> map) {
    return TransferModel(
      id: map['id'] as int?,
      fromAccountId: map['fromAccountId'] as int,
      toAccountId: map['toAccountId'] as int,
      amount: map['amount'] as int,
      note: map['note'] as String?,
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  TransferModel copyWith({
    int? id,
    int? fromAccountId,
    int? toAccountId,
    int? amount,
    String? note,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return TransferModel(
      id: id ?? this.id,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

