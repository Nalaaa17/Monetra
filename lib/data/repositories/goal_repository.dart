import '../database/app_database.dart';
import '../models/goal.dart';
import '../models/goal_contribution.dart';
import '../models/transaction.dart';
import '../services/notification_service.dart';

class GoalDetail {
  final Goal goal;
  final String sourceAccountName;
  final String sourceAccountColorHex;
  final int sourceAccountIconCodePoint;
  final String? sourceAccountLogoKey;
  final int lockedAmount;

  const GoalDetail({
    required this.goal,
    required this.sourceAccountName,
    required this.sourceAccountColorHex,
    required this.sourceAccountIconCodePoint,
    this.sourceAccountLogoKey,
    this.lockedAmount = 0,
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

class GoalContributionDetail {
  final GoalContribution contribution;
  final String accountName;
  final String accountColorHex;
  final int accountIconCodePoint;
  final String? accountLogoKey;

  const GoalContributionDetail({
    required this.contribution,
    required this.accountName,
    required this.accountColorHex,
    required this.accountIconCodePoint,
    this.accountLogoKey,
  });

  int get id => contribution.id!;
  int get amount => contribution.amount;
  DateTime get date => contribution.date;
  String? get note => contribution.note;
  bool get isRealized => contribution.isRealized;
}

class GoalRepository {
  static Future<int>? _inFlightSync;

  static int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  /// Memajukan tenggat tanggal ke siklus bulan berikutnya sambil menjaga hari target
  /// tetap valid di bulan lebih pendek (misal tanggal 31 -> 28/29 Feb -> 31 Mar).
  static DateTime advanceMonthlyDeadline(
    DateTime currentDeadline,
    DateTime referenceToday,
  ) {
    final targetDay = currentDeadline.day;
    var year = currentDeadline.year;
    var month = currentDeadline.month;

    var candidate = currentDeadline;
    while (DateTime(candidate.year, candidate.month, candidate.day)
        .isBefore(referenceToday)) {
      month += 1;
      if (month > 12) {
        month = 1;
        year += 1;
      }
      final clampedDay =
          targetDay.clamp(1, _daysInMonth(year, month));
      candidate = DateTime(
        year,
        month,
        clampedDay,
        currentDeadline.hour,
        currentDeadline.minute,
        currentDeadline.second,
      );
    }
    return candidate;
  }

  /// Mereset otomatis progres & tenggat target berulang bulanan (`repeatMonthly = true`)
  /// yang tanggal jatuh temponya telah terlewati, serta menandai `'missed'` pada target
  /// non-berulang aktif yang belum terpenuhi setelah lewat jatuh tempo.
  Future<int> syncRecurringGoals({DateTime? referenceDate}) {
    if (referenceDate == null && _inFlightSync != null) {
      return _inFlightSync!;
    }
    final future = _runSyncRecurringGoals(referenceDate: referenceDate);
    if (referenceDate == null) {
      _inFlightSync = future.whenComplete(() {
        _inFlightSync = null;
      });
      return _inFlightSync!;
    }
    return future;
  }

  Future<int> _runSyncRecurringGoals({DateTime? referenceDate}) async {
    final db = await AppDatabase.instance;
    final ref = referenceDate ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);

    // Pemeriksaan cepat baca-saja agar tidak membuka kunci transaksi tulis jika belum ada jadwal lewat
    final candidateRows = await db.query(
      'goals',
      columns: ['deadline'],
      where: "repeatMonthly = 1 OR status = 'active'",
    );
    final hasOverdueGoal = candidateRows.any((row) {
      final raw = row['deadline'] as String?;
      if (raw == null) return false;
      final d = DateTime.tryParse(raw);
      if (d == null) return false;
      return DateTime(d.year, d.month, d.day).isBefore(today);
    });
    if (!hasOverdueGoal) return 0;

    int resetCount = 0;
    final List<Goal> rescheduledReminders = [];

    await db.transaction((txn) async {
      final rows = await txn.query(
        'goals',
        where: "repeatMonthly = 1 OR status = 'active'",
      );

      for (final row in rows) {
        final goal = Goal.fromMap(row);
        if (goal.id == null) continue;

        final deadlineDay = DateTime(
          goal.deadline.year,
          goal.deadline.month,
          goal.deadline.day,
        );

        if (!deadlineDay.isBefore(today)) continue;

        if (goal.repeatMonthly) {
          final nextDeadline = advanceMonthlyDeadline(goal.deadline, today);

          // Lepas kunci setoran yang belum direalisasikan dari siklus bulan lalu
          await txn.delete(
            'goal_contributions',
            where: 'goalId = ? AND isRealized = 0',
            whereArgs: [goal.id],
          );

          await txn.update(
            'goals',
            {
              'collectedAmount': 0,
              'status': 'active',
              'deadline': nextDeadline.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [goal.id],
          );

          resetCount++;
          rescheduledReminders.add(
            goal.copyWith(
              collectedAmount: 0,
              status: 'active',
              deadline: nextDeadline,
            ),
          );
        } else if (goal.status == 'active') {
          final newStatus = goal.isDone ? 'done' : 'missed';
          await txn.update(
            'goals',
            {'status': newStatus},
            where: 'id = ?',
            whereArgs: [goal.id],
          );
        }
      }
    });

    for (final updatedGoal in rescheduledReminders) {
      if (updatedGoal.reminderEnabled) {
        await NotificationService.scheduleGoalReminder(
          goalId: updatedGoal.id!,
          goalName: updatedGoal.name,
          deadline: updatedGoal.deadline,
          remainingAmount: updatedGoal.remainingAmount,
        );
      } else {
        await NotificationService.cancelGoalReminder(updatedGoal.id!);
      }
    }

    return resetCount;
  }

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

  /// Memperbarui data Goal sekaligus menyinkronkan selisih collectedAmount ke goal_contributions
  /// agar saldo rekening sumber selalu konsisten dengan dana terkumpul di target.
  Future<int> updateGoalAndSyncContributions(
    Goal goal, {
    int? adjustmentAccountId,
  }) async {
    final db = await AppDatabase.instance;
    int res = 0;

    await db.transaction((txn) async {
      final oldGoalMaps = await txn.query(
        'goals',
        where: 'id = ?',
        whereArgs: [goal.id],
        limit: 1,
      );
      final oldGoal =
          oldGoalMaps.isNotEmpty ? Goal.fromMap(oldGoalMaps.first) : null;

      final sumRes = await txn.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) as total
        FROM goal_contributions
        WHERE goalId = ? AND isRealized = 0
      ''', [goal.id]);
      final currentLocked = (sumRes.first['total'] as num?)?.toInt() ?? 0;

      res = await txn.update(
        'goals',
        goal.toMap(),
        where: 'id = ?',
        whereArgs: [goal.id],
      );

      // Deteksi apakah siklus aktif ini memang sudah direalisasikan sebagai pengeluaran
      final isSettledCurrentCycle = oldGoal != null &&
          oldGoal.status == 'done' &&
          oldGoal.collectedAmount > 0 &&
          currentLocked == 0;

      final int delta;
      if (isSettledCurrentCycle) {
        delta = goal.collectedAmount > oldGoal.collectedAmount
            ? (goal.collectedAmount - oldGoal.collectedAmount)
            : 0;
      } else {
        delta = goal.collectedAmount - currentLocked;
      }

      if (delta > 0) {
        await txn.insert(
          'goal_contributions',
          GoalContribution(
            goalId: goal.id!,
            sourceAccountId: adjustmentAccountId ?? goal.sourceAccountId,
            amount: delta,
            date: DateTime.now(),
            note: 'Penyesuaian saldo target',
            isRealized: false,
          ).toMap(),
        );
      } else if (delta < 0) {
        // Kurangi dari setoran terbaru ke terlama agar alokasi per akun tidak negatif
        int remainingToTrim = -delta;
        final contribs = await txn.query(
          'goal_contributions',
          where: 'goalId = ? AND isRealized = 0',
          whereArgs: [goal.id],
          orderBy: 'date DESC, id DESC',
        );

        for (final row in contribs) {
          if (remainingToTrim <= 0) break;
          final c = GoalContribution.fromMap(row);
          if (c.amount <= remainingToTrim) {
            await txn.delete('goal_contributions',
                where: 'id = ?', whereArgs: [c.id]);
            remainingToTrim -= c.amount;
          } else {
            await txn.update(
              'goal_contributions',
              {'amount': c.amount - remainingToTrim},
              where: 'id = ?',
              whereArgs: [c.id],
            );
            remainingToTrim = 0;
          }
        }
      }
    });

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
    return await db.transaction((txn) async {
      await txn.delete('goal_contributions', where: 'goalId = ?', whereArgs: [id]);
      return await txn.delete('goals', where: 'id = ?', whereArgs: [id]);
    });
  }

  GoalDetail _mapRowToGoalDetail(Map<String, dynamic> row) {
    return GoalDetail(
      goal: Goal.fromMap(row),
      sourceAccountName: row['sourceAccountName'] as String,
      sourceAccountColorHex: row['sourceAccountColorHex'] as String,
      sourceAccountIconCodePoint: row['sourceAccountIconCodePoint'] as int,
      sourceAccountLogoKey: row['sourceAccountLogoKey'] as String?,
      lockedAmount: (row['lockedAmount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<GoalDetail?> getGoalById(int id) async {
    final db = await AppDatabase.instance;
    final results = await db.rawQuery('''
      SELECT 
        g.*,
        a.name as sourceAccountName,
        a.colorHex as sourceAccountColorHex,
        a.iconCodePoint as sourceAccountIconCodePoint,
        a.logoKey as sourceAccountLogoKey,
        COALESCE((
          SELECT SUM(gc.amount)
          FROM goal_contributions gc
          WHERE gc.goalId = g.id AND gc.isRealized = 0
        ), 0) as lockedAmount
      FROM goals g
      JOIN accounts a ON g.sourceAccountId = a.id
      WHERE g.id = ?
      LIMIT 1
    ''', [id]);

    if (results.isEmpty) return null;
    return _mapRowToGoalDetail(results.first);
  }

  Future<List<GoalDetail>> getAllGoals({String? status}) async {
    await syncRecurringGoals();
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
        a.iconCodePoint as sourceAccountIconCodePoint,
        a.logoKey as sourceAccountLogoKey,
        COALESCE((
          SELECT SUM(gc.amount)
          FROM goal_contributions gc
          WHERE gc.goalId = g.id AND gc.isRealized = 0
        ), 0) as lockedAmount
      FROM goals g
      JOIN accounts a ON g.sourceAccountId = a.id
      $whereSql
      ORDER BY g.status ASC, g.deadline ASC
    ''', whereArgs);

    return results.map(_mapRowToGoalDetail).toList();
  }

  /// Menampilkan target mendekati jatuh tempo (maks 2 untuk Home Screen PRD §6.4)
  Future<List<GoalDetail>> getUpcomingUrgentGoals({int limit = 2}) async {
    await syncRecurringGoals();
    final db = await AppDatabase.instance;
    final results = await db.rawQuery('''
      SELECT 
        g.*,
        a.name as sourceAccountName,
        a.colorHex as sourceAccountColorHex,
        a.iconCodePoint as sourceAccountIconCodePoint,
        a.logoKey as sourceAccountLogoKey,
        COALESCE((
          SELECT SUM(gc.amount)
          FROM goal_contributions gc
          WHERE gc.goalId = g.id AND gc.isRealized = 0
        ), 0) as lockedAmount
      FROM goals g
      JOIN accounts a ON g.sourceAccountId = a.id
      WHERE g.status IN ('active', 'missed')
      ORDER BY g.deadline ASC
      LIMIT ?
    ''', [limit]);

    return results.map(_mapRowToGoalDetail).toList();
  }

  /// Menambah pengisian / cicilan tabungan ke target dengan mencatat sumber rekeningnya
  Future<void> addContribution({
    required int goalId,
    int? sourceAccountId,
    required int amount,
    String? note,
    DateTime? date,
  }) async {
    final db = await AppDatabase.instance;
    final contribDate = date ?? DateTime.now();
    Goal? updatedGoalAfterContrib;

    await db.transaction((txn) async {
      final goalMaps = await txn.query(
        'goals',
        where: 'id = ?',
        whereArgs: [goalId],
      );
      if (goalMaps.isEmpty) return;

      final currentGoal = Goal.fromMap(goalMaps.first);
      final effectiveSourceId = sourceAccountId ?? currentGoal.sourceAccountId;

      // 1. Catat kontribusi lengkap dengan sourceAccountId
      await txn.insert(
        'goal_contributions',
        GoalContribution(
          goalId: goalId,
          sourceAccountId: effectiveSourceId,
          amount: amount,
          date: contribDate,
          note: note,
          isRealized: false,
        ).toMap(),
      );

      // 2. Update collectedAmount
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

      updatedGoalAfterContrib = currentGoal.copyWith(
        collectedAmount: newCollected,
        status: isNowDone ? 'done' : currentGoal.status,
      );
    });

    final g = updatedGoalAfterContrib;
    if (g != null && g.id != null) {
      if (g.reminderEnabled && !g.isDone) {
        await NotificationService.scheduleGoalReminder(
          goalId: g.id!,
          goalName: g.name,
          deadline: g.deadline,
          remainingAmount: g.remainingAmount,
        );
      } else {
        await NotificationService.cancelGoalReminder(g.id!);
      }
    }
  }

  /// Mengambil daftar kontribusi beserta detail rekening sumber untuk ditampilkan di UI
  Future<List<GoalContributionDetail>> getContributionDetailsForGoal(
      int goalId) async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery('''
      SELECT
        gc.*,
        a.name as accountName,
        a.colorHex as accountColorHex,
        a.iconCodePoint as accountIconCodePoint,
        a.logoKey as accountLogoKey
      FROM goal_contributions gc
      JOIN goals g ON gc.goalId = g.id
      JOIN accounts a ON COALESCE(gc.sourceAccountId, g.sourceAccountId) = a.id
      WHERE gc.goalId = ?
      ORDER BY gc.date DESC, gc.id DESC
    ''', [goalId]);

    return rows.map((row) {
      return GoalContributionDetail(
        contribution: GoalContribution.fromMap(row),
        accountName: row['accountName'] as String,
        accountColorHex: row['accountColorHex'] as String,
        accountIconCodePoint: row['accountIconCodePoint'] as int,
        accountLogoKey: row['accountLogoKey'] as String?,
      );
    }).toList();
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

  /// Merealisasikan target yang sudah terkumpul sebagai Pengeluaran nyata (sudah dibayar/dibeli).
  /// Pengeluaran dicatat di tabel transactions per rekening sumbernya dan dana dilepas dari lock
  /// sehingga tidak terjadi pemotongan ganda.
  Future<void> realizeGoalAsExpense(int goalId, {int? categoryId}) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now();

    await db.transaction((txn) async {
      final goalMaps =
          await txn.query('goals', where: 'id = ?', whereArgs: [goalId]);
      if (goalMaps.isEmpty) return;
      final goal = Goal.fromMap(goalMaps.first);

      // Cari kategori default ('Tagihan' / 'Lainnya') jika tidak ditentukan
      int? effectiveCatId = categoryId;
      if (effectiveCatId == null) {
        final cats = await txn.query(
          'categories',
          where: "type = 'expense' AND isActive = 1 AND (LOWER(name) = 'tagihan' OR LOWER(name) = 'lainnya')",
          orderBy: 'id ASC',
          limit: 1,
        );
        if (cats.isNotEmpty) {
          effectiveCatId = cats.first['id'] as int?;
        }
      }

      // Agregasi setoran yang belum direalisasikan per sourceAccountId
      final grouped = await txn.rawQuery('''
        SELECT
          COALESCE(sourceAccountId, ?) as accId,
          COALESCE(SUM(amount), 0) as totalAmount
        FROM goal_contributions
        WHERE goalId = ? AND isRealized = 0
        GROUP BY COALESCE(sourceAccountId, ?)
      ''', [goal.sourceAccountId, goalId, goal.sourceAccountId]);

      if (grouped.isEmpty && goal.collectedAmount > 0) {
        await txn.insert(
          'transactions',
          TransactionModel(
            type: 'expense',
            amount: goal.collectedAmount,
            accountId: goal.sourceAccountId,
            categoryId: effectiveCatId,
            note: 'Realisasi Target: ${goal.name}',
            date: now,
            createdAt: now,
          ).toMap(),
        );
      } else {
        for (final row in grouped) {
          final accId = row['accId'] as int;
          final amt = (row['totalAmount'] as num?)?.toInt() ?? 0;
          if (amt <= 0) continue;

          await txn.insert(
            'transactions',
            TransactionModel(
              type: 'expense',
              amount: amt,
              accountId: accId,
              categoryId: effectiveCatId,
              note: 'Realisasi Target: ${goal.name}',
              date: now,
              createdAt: now,
            ).toMap(),
          );
        }
      }

      // Tandai semua setoran target ini sudah direalisasikan (tidak lagi mengunci saldo bebas)
      await txn.update(
        'goal_contributions',
        {'isRealized': 1},
        where: 'goalId = ? AND isRealized = 0',
        whereArgs: [goalId],
      );

      await txn.update(
        'goals',
        {'status': 'done'},
        where: 'id = ?',
        whereArgs: [goalId],
      );
    });

    await NotificationService.cancelGoalReminder(goalId);
  }

  /// Melepas kembali dana terkumpul di target menjadi saldo bebas pakai (misal batal beli/pakai)
  Future<void> releaseGoalFunds(int goalId) async {
    final db = await AppDatabase.instance;
    Goal? releasedGoal;

    await db.transaction((txn) async {
      final goalMaps = await txn.query(
        'goals',
        where: 'id = ?',
        whereArgs: [goalId],
        limit: 1,
      );
      await txn.delete(
        'goal_contributions',
        where: 'goalId = ? AND isRealized = 0',
        whereArgs: [goalId],
      );

      if (goalMaps.isNotEmpty) {
        final current = Goal.fromMap(goalMaps.first);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final deadlineDay = DateTime(
          current.deadline.year,
          current.deadline.month,
          current.deadline.day,
        );
        final nextStatus = deadlineDay.isBefore(today) ? 'missed' : 'active';

        await txn.update(
          'goals',
          {'collectedAmount': 0, 'status': nextStatus},
          where: 'id = ?',
          whereArgs: [goalId],
        );

        releasedGoal = current.copyWith(
          collectedAmount: 0,
          status: nextStatus,
        );
      } else {
        await txn.update(
          'goals',
          {'collectedAmount': 0, 'status': 'active'},
          where: 'id = ?',
          whereArgs: [goalId],
        );
      }
    });

    final g = releasedGoal;
    if (g != null && g.id != null && g.reminderEnabled && g.status == 'active') {
      await NotificationService.scheduleGoalReminder(
        goalId: g.id!,
        goalName: g.name,
        deadline: g.deadline,
        remainingAmount: g.remainingAmount,
      );
    }
  }
}
