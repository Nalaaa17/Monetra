class GoalContribution {
  final int? id;
  final int goalId;
  final int? sourceAccountId;
  final int amount;
  final DateTime date;
  final String? note;
  final bool isRealized;

  const GoalContribution({
    this.id,
    required this.goalId,
    this.sourceAccountId,
    required this.amount,
    required this.date,
    this.note,
    this.isRealized = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'goalId': goalId,
      if (sourceAccountId != null) 'sourceAccountId': sourceAccountId,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'isRealized': isRealized ? 1 : 0,
    };
  }

  factory GoalContribution.fromMap(Map<String, dynamic> map) {
    return GoalContribution(
      id: map['id'] as int?,
      goalId: map['goalId'] as int,
      sourceAccountId: map['sourceAccountId'] as int?,
      amount: map['amount'] as int,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      isRealized: (map['isRealized'] as int? ?? 0) == 1,
    );
  }
}
