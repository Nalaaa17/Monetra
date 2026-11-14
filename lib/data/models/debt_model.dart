class DebtModel {
  final int? id;
  final String title;
  final String personName;
  final String type; // 'debt' (utang) atau 'receivable' (piutang)
  final int totalAmount;
  final int paidAmount;
  final DateTime? dueDate;
  final String? note;
  final bool isSettled;
  final DateTime createdAt;

  const DebtModel({
    this.id,
    required this.title,
    required this.personName,
    required this.type,
    required this.totalAmount,
    this.paidAmount = 0,
    this.dueDate,
    this.note,
    this.isSettled = false,
    required this.createdAt,
  });

  bool get isDebt => type == 'debt';
  bool get isReceivable => type == 'receivable';
  int get remainingAmount =>
      (totalAmount - paidAmount).clamp(0, totalAmount).toInt();
  double get progress =>
      totalAmount > 0 ? (paidAmount / totalAmount).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'personName': personName,
      'type': type,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'dueDate': dueDate?.toIso8601String(),
      'note': note,
      'isSettled': isSettled ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DebtModel.fromMap(Map<String, dynamic> map) {
    return DebtModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      personName: (map['personName'] as String?) ?? '',
      type: map['type'] as String,
      totalAmount: (map['totalAmount'] as num).toInt(),
      paidAmount: (map['paidAmount'] as num?)?.toInt() ?? 0,
      dueDate: map['dueDate'] != null
          ? DateTime.tryParse(map['dueDate'] as String)
          : null,
      note: map['note'] as String?,
      isSettled: ((map['isSettled'] as num?)?.toInt() ?? 0) == 1,
      createdAt: DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now(),
    );
  }
}

