import '../database/app_database.dart';
import '../models/goal.dart';
import '../models/goal_contribution.dart';
import '../services/notification_service.dart';

class GoalDetail {
  final Goal goal;
  final String sourceAccountName;
  final String sourceAccountColorHex;
  final int sourceAccountIconCodePoint;

  const GoalDetail({
    required this.goal,
    required this.sourceAccountName,
    required this.sourceAccountColorHex,
    required this.sourceAccountIconCodePoint,
  });

  int get id => goal.id!;
  String get name => goal.name;
  int get targetAmount => goal.targetAmount;
  int get collectedAmount => goal.collectedAmount;
  DateTime get deadline => goal.deadline;
  bool get repeatMonthly => goal.repeatMonthly;
  int get sourceAccountId => goal.sourceAccountId;
  bool get reminderEnabled => goal.reminderEnabled;
  String get status => goal.status;
  double get progressPercentage => goal.progressPercentage;
  int get remainingAmount => goal.remainingAmount;
  bool get isDone => goal.isDone;
  int get daysRemaining => goal.daysRemaining;
  bool get isUrgent => goal.isUrgent;
}

class GoalRepository {
  Future<int> insertGoal(Goal goal) async {
    final db = await AppDatabase.instance;
    final id = await db.insert('goals', goal.toMap());

    // Jadwalkan pengingat notifikasi H-3 jika reminder aktif
    if (goal.reminderEnabled) {
      await NotificationService.scheduleGoalReminder(
        goalId: id,
        goalName: goal.name,
        deadline: goal.deadline,
        remainingAmount: goal.remainingAmount,
      );
    }

    return id;
  }

  Future<int> updateGoal(Goal goal) async {
    final db = await AppDatabase.instance;
    final res = await db.update(
      'goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );

    if (goal.reminderEnabled && !goal.isDone) {
      await NotificationService.scheduleGoalReminder(
        goalId: goal.id!,
        goalName: goal.name,
        deadline: goal.deadline,
        remainingAmount: goal.remainingAmount,
      );
    } else {
      await NotificationService.cancelGoalReminder(goal.id!);
    }

    return res;
  }

  Future<int> deleteGoal(int id) async {
    final db = await AppDatabase.instance;
    await NotificationService.cancelGoalReminder(id);
    return await db.delete(
      'goals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<GoalDetail?> getGoalById(int id) async {
    final db = await AppDatabase.instance;
    final results = await db.rawQuery('''
      SELECT 
        g.*,
        a.name as sourceAccountName,
        a.colorHex as sourceAccountColorHex,
        a.iconCodePoint as sourceAccountIconCodePoint
      FROM goals g
      JOIN accounts a ON g.sourceAccountId = a.id
      WHERE g.id = ?
      LIMIT 1
    ''', [id]);

    if (results.isEmpty) return null;
    final row = results.first;
    return GoalDetail(
      goal: Goal.fromMap(row),
      sourceAccountName: row['sourceAccountName'] as String,
      sourceAccountColorHex: row['sourceAccountColorHex'] as String,
      sourceAccountIconCodePoint: row['sourceAccountIconCodePoint'] as int,
    );
  }

  Future<List<GoalDetail>> getAllGoals({String? status}) async {
    final db = await AppDatabase.instance;
    String whereSql = '';
    List<dynamic> whereArgs = [];

    if (status != null) {
      whereSql = 'WHERE g.status = ?';
      whereArgs = [status];
    }

    final results = await db.rawQuery('''
      SELECT 
        g.*,
        a.name as sourceAccountName,
        a.colorHex as sourceAccountColorHex,
        a.iconCodePoint as sourceAccountIconCodePoint
      FROM goals g
      JOIN accounts a ON g.sourceAccountId = a.id
      $whereSql
      ORDER BY g.status ASC, g.deadline ASC
    ''', whereArgs);

    return results.map((row) {
      return GoalDetail(
        goal: Goal.fromMap(row),
        sourceAccountName: row['sourceAccountName'] as String,
        sourceAccountColorHex: row['sourceAccountColorHex'] as String,
        sourceAccountIconCodePoint: row['sourceAccountIconCodePoint'] as int,
      );
    }).toList();
  }

  /// Menampilkan target mendekati jatuh tempo (maks 2 untuk Home Screen PRD §6.4)
  Future<List<GoalDetail>> getUpcomingUrgentGoals({int limit = 2}) async {
    final db = await AppDatabase.instance;
    final results = await db.rawQuery('''
      SELECT 
        g.*,
        a.name as sourceAccountName,
        a.colorHex as sourceAccountColorHex,
        a.iconCodePoint as sourceAccountIconCodePoint
      FROM goals g
      JOIN accounts a ON g.sourceAccountId = a.id
      WHERE g.status = 'active'
      ORDER BY g.deadline ASC
      LIMIT ?
    ''', [limit]);

    return results.map((row) {
      return GoalDetail(
        goal: Goal.fromMap(row),
        sourceAccountName: row['sourceAccountName'] as String,
        sourceAccountColorHex: row['sourceAccountColorHex'] as String,
        sourceAccountIconCodePoint: row['sourceAccountIconCodePoint'] as int,
      );
    }).toList();
  }

  /// Menambah pengisian / cicilan tabungan ke target
  Future<void> addContribution({
    required int goalId,
    required int amount,
    String? note,
    DateTime? date,
  }) async {
    final db = await AppDatabase.instance;
    final contribDate = date ?? DateTime.now();

    await db.transaction((txn) async {
      // 1. Catat kontribusi
      await txn.insert(
        'goal_contributions',
        GoalContribution(
          goalId: goalId,
          amount: amount,
          date: contribDate,
          note: note,
        ).toMap(),
      );

      // 2. Ambil collectedAmount saat ini
      final goalMaps = await txn.query(
        'goals',
        where: 'id = ?',
        whereArgs: [goalId],
      );
      if (goalMaps.isEmpty) return;

      final currentGoal = Goal.fromMap(goalMaps.first);
      final newCollected = currentGoal.collectedAmount + amount;
      final isNowDone = newCollected >= currentGoal.targetAmount;

      await txn.update(
        'goals',
        {
          'collectedAmount': newCollected,
          if (isNowDone) 'status': 'done',
        },
        where: 'id = ?',
        whereArgs: [goalId],
      );
    });
  }

  Future<List<GoalContribution>> getContributionsForGoal(int goalId) async {
    final db = await AppDatabase.instance;
    final maps = await db.query(
      'goal_contributions',
      where: 'goalId = ?',
      whereArgs: [goalId],
      orderBy: 'date DESC, id DESC',
    );
    return maps.map((e) => GoalContribution.fromMap(e)).toList();
  }
}

