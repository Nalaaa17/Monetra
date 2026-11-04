class GoalContribution {
  final int? id;
  final int goalId;
  final int amount;
  final DateTime date;
  final String? note;

  const GoalContribution({
    this.id,
    required this.goalId,
    required this.amount,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'goalId': goalId,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory GoalContribution.fromMap(Map<String, dynamic> map) {
    return GoalContribution(
      id: map['id'] as int?,
      goalId: map['goalId'] as int,
      amount: map['amount'] as int,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
    );
  }
}

