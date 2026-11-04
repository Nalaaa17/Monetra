class Goal {
  final int? id;
  final String name;
  final int targetAmount;
  final int collectedAmount;
  final DateTime deadline;
  final bool repeatMonthly;
  final int sourceAccountId;
  final bool reminderEnabled;
  final String status; // 'active' | 'done' | 'missed'
  final DateTime createdAt;

  const Goal({
    this.id,
    required this.name,
    required this.targetAmount,
    this.collectedAmount = 0,
    required this.deadline,
    this.repeatMonthly = false,
    required this.sourceAccountId,
    this.reminderEnabled = true,
    this.status = 'active',
    required this.createdAt,
  });

  double get progressPercentage => targetAmount > 0
      ? (collectedAmount / targetAmount).clamp(0.0, 1.0) * 100
      : 0.0;

  int get remainingAmount => (targetAmount - collectedAmount) > 0
      ? (targetAmount - collectedAmount)
      : 0;

  bool get isDone => collectedAmount >= targetAmount || status == 'done';

  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(deadline.year, deadline.month, deadline.day);
    return target.difference(today).inDays;
  }

  bool get isUrgent => daysRemaining <= 3 && !isDone;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'collectedAmount': collectedAmount,
      'deadline': deadline.toIso8601String(),
      'repeatMonthly': repeatMonthly ? 1 : 0,
      'sourceAccountId': sourceAccountId,
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'] as int?,
      name: map['name'] as String,
      targetAmount: map['targetAmount'] as int,
      collectedAmount: map['collectedAmount'] as int? ?? 0,
      deadline: DateTime.parse(map['deadline'] as String),
      repeatMonthly: (map['repeatMonthly'] as int? ?? 0) == 1,
      sourceAccountId: map['sourceAccountId'] as int,
      reminderEnabled: (map['reminderEnabled'] as int? ?? 1) == 1,
      status: map['status'] as String? ?? 'active',
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Goal copyWith({
    int? id,
    String? name,
    int? targetAmount,
    int? collectedAmount,
    DateTime? deadline,
    bool? repeatMonthly,
    int? sourceAccountId,
    bool? reminderEnabled,
    String? status,
    DateTime? createdAt,
  }) {
    return Goal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      collectedAmount: collectedAmount ?? this.collectedAmount,
      deadline: deadline ?? this.deadline,
      repeatMonthly: repeatMonthly ?? this.repeatMonthly,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

