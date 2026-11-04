import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/goal.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/goal_repository.dart';
import 'package:monetra/features/goals/screens/goals_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppDatabase.testDbPath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await AppDatabase.close();
  });

  group('Fase 4: Goal / Target & Pengingat Jatuh Tempo Tests', () {
    test('Goal CRUD, progress, and automatic done status calculation', () async {
      final accountRepo = AccountRepository();
      final goalRepo = GoalRepository();

      final accounts = await accountRepo.getAllAccounts();
      final mandiri = accounts.firstWhere((a) => a.name == 'Mandiri');

      // 1. Buat Target baru: "Bayar Ressa tiap tgl 23", target Rp 710.000
      final deadline2Days = DateTime.now().add(const Duration(days: 2));
      final goal = Goal(
        name: 'Bayar Ressa tiap tgl 23',
        targetAmount: 710000,
        collectedAmount: 0,
        deadline: deadline2Days,
        repeatMonthly: true,
        sourceAccountId: mandiri.id!,
        reminderEnabled: true,
        status: 'active',
        createdAt: DateTime.now(),
      );

      final goalId = await goalRepo.insertGoal(goal);
      expect(goalId, greaterThan(0));

      // 2. Baca detail goal
      final detail = await goalRepo.getGoalById(goalId);
      expect(detail, isNotNull);
      expect(detail!.name, 'Bayar Ressa tiap tgl 23');
      expect(detail.targetAmount, 710000);
      expect(detail.collectedAmount, 0);
      expect(detail.remainingAmount, 710000);
      expect(detail.progressPercentage, 0.0);
      expect(detail.isDone, false);
      expect(detail.isUrgent, true); // <= 3 hari
      expect(detail.sourceAccountName, 'Mandiri');

      // 3. Tambah cicilan/setoran pertama: Rp 250.000
      await goalRepo.addContribution(
        goalId: goalId,
        amount: 250000,
        note: 'Sisihkan dari gaji',
      );

      final detailAfterContrib1 = await goalRepo.getGoalById(goalId);
      expect(detailAfterContrib1!.collectedAmount, 250000);
      expect(detailAfterContrib1.remainingAmount, 460000); // 710.000 - 250.000 = 460.000 (sesuai PRD §4.4)
      expect(detailAfterContrib1.isDone, false);
      expect(detailAfterContrib1.status, 'active');

      final contributions = await goalRepo.getContributionsForGoal(goalId);
      expect(contributions.length, 1);
      expect(contributions.first.amount, 250000);
      expect(contributions.first.note, 'Sisihkan dari gaji');

      // 4. Tambah cicilan kedua pelunasan: Rp 460.000
      await goalRepo.addContribution(
        goalId: goalId,
        amount: 460000,
        note: 'Pelunasan',
      );

      final detailAfterDone = await goalRepo.getGoalById(goalId);
      expect(detailAfterDone!.collectedAmount, 710000);
      expect(detailAfterDone.remainingAmount, 0);
      expect(detailAfterDone.progressPercentage, 100.0);
      expect(detailAfterDone.isDone, true);
      expect(detailAfterDone.status, 'done');

      // 5. Verifikasi list all goals filter status
      final doneGoals = await goalRepo.getAllGoals(status: 'done');
      expect(doneGoals.any((g) => g.id == goalId), true);
    });

    test('getUpcomingUrgentGoals returns active urgent goals', () async {
      final accountRepo = AccountRepository();
      final goalRepo = GoalRepository();

      final accounts = await accountRepo.getAllAccounts();
      final cash = accounts.firstWhere((a) => a.name == 'Cash');

      // Target 1: Urgent (1 hari lagi)
      await goalRepo.insertGoal(
        Goal(
          name: 'Liquid + Coil',
          targetAmount: 180000,
          deadline: DateTime.now().add(const Duration(days: 1)),
          sourceAccountId: cash.id!,
          createdAt: DateTime.now(),
        ),
      );

      // Target 2: Jauh (30 hari lagi)
      await goalRepo.insertGoal(
        Goal(
          name: 'Liburan Akhir Tahun',
          targetAmount: 2500000,
          deadline: DateTime.now().add(const Duration(days: 30)),
          sourceAccountId: cash.id!,
          createdAt: DateTime.now(),
        ),
      );

      final upcoming = await goalRepo.getUpcomingUrgentGoals(limit: 2);
      expect(upcoming.isNotEmpty, true);
      expect(upcoming.first.name, 'Liquid + Coil');
      expect(upcoming.first.targetAmount, 180000);
      expect(upcoming.first.isUrgent, true);
    });

    testWidgets('GoalsScreen renders tabs and opens Add Goal modal',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: GoalsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Pastikan AppBar dan Tabs ada
      expect(find.text('Target & Tabungan'), findsOneWidget);
      expect(find.text('🎯 Berjalan'), findsOneWidget);
      expect(find.text('🎉 Tercapai'), findsOneWidget);

      // Pastikan tombol FAB "Target Baru" ada
      final fabFinder = find.widgetWithText(FloatingActionButton, 'Target Baru');
      expect(fabFinder, findsOneWidget);

      // Tap FAB untuk membuka modal
      await tester.tap(fabFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Pastikan modal bottom sheet muncul dengan field input yang diperlukan
      expect(find.text('Buat Target Baru'), findsOneWidget);
      expect(find.text('Nama Target / Keperluan'), findsOneWidget);
      expect(find.text('Target Nominal (Rp)'), findsOneWidget);
      expect(find.text('Pengingat H-3 Jatuh Tempo'), findsOneWidget);
      expect(find.text('Target Berulang Tiap Bulan'), findsOneWidget);
      expect(find.text('Simpan Target'), findsOneWidget);
    });
  });
}
