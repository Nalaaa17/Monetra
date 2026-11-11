import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/goal.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/goal_repository.dart';
import 'package:monetra/features/goals/providers/goal_providers.dart';
import 'package:monetra/features/goals/screens/goals_screen.dart';
import 'package:monetra/features/goals/widgets/goal_card.dart';
import 'package:monetra/features/home/providers/home_providers.dart';
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

    test('GoalRepository can update an existing goal successfully', () async {
      final accountRepo = AccountRepository();
      final goalRepo = GoalRepository();
      final accounts = await accountRepo.getAllAccounts();
      final account = accounts.first;

      final goalId = await goalRepo.insertGoal(Goal(
        name: 'Target Awal',
        targetAmount: 500000,
        deadline: DateTime.now().add(const Duration(days: 10)),
        sourceAccountId: account.id!,
        createdAt: DateTime.now(),
      ));

      final created = await goalRepo.getGoalById(goalId);
      expect(created, isNotNull);

      final updated = created!.goal.copyWith(
        name: 'Target Diperbarui',
        targetAmount: 999000,
        collectedAmount: 150000,
      );

      final rowsAffected = await goalRepo.updateGoal(updated);
      expect(rowsAffected, 1);

      final fetched = await goalRepo.getGoalById(goalId);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Target Diperbarui');
      expect(fetched.targetAmount, 999000);
      expect(fetched.collectedAmount, 150000);
    });

    test(
        'Goal contributions deduct available balance from selected source accounts without double-counting on realization',
        () async {
      final accountRepo = AccountRepository();
      final goalRepo = GoalRepository();

      final accounts = await accountRepo.getAllAccounts();
      final mandiri = accounts.firstWhere((a) => a.name == 'Mandiri');
      final cash = accounts.firstWhere((a) => a.name == 'Cash');

      // Beri saldo awal Mandiri 1.000.000 & Cash 300.000
      await accountRepo.updateAccount(mandiri.copyWith(initialBalance: 1000000));
      await accountRepo.updateAccount(cash.copyWith(initialBalance: 300000));

      final goalId = await goalRepo.insertGoal(Goal(
        name: 'Bayar Ressa',
        targetAmount: 400000,
        deadline: DateTime.now().add(const Duration(days: 5)),
        sourceAccountId: mandiri.id!,
        createdAt: DateTime.now(),
      ));

      // Setor 250.000 dari Mandiri dan 150.000 dari Cash
      await goalRepo.addContribution(
        goalId: goalId,
        sourceAccountId: mandiri.id!,
        amount: 250000,
        note: 'Dari Mandiri',
      );
      await goalRepo.addContribution(
        goalId: goalId,
        sourceAccountId: cash.id!,
        amount: 150000,
        note: 'Dari Cash',
      );

      // Verifikasi saldo bebas per akun langsung terpotong
      expect(await accountRepo.calculateAccountBalance(mandiri.id!), 750000);
      expect(await accountRepo.calculateAccountBalance(cash.id!), 150000);

      final summary = await accountRepo.getBalanceSummary();
      expect(summary.totalNetWorth, 900000); // 1.300.000 - 400.000
      expect(summary.allocatedInGoals, 400000);
      expect(summary.totalPhysicalNetWorth, 1300000);

      // Verifikasi riwayat kontribusi memuat nama akun masing-masing
      final details = await goalRepo.getContributionDetailsForGoal(goalId);
      expect(details.length, 2);
      expect(details.any((d) => d.accountName == 'Mandiri' && d.amount == 250000),
          isTrue);
      expect(details.any((d) => d.accountName == 'Cash' && d.amount == 150000),
          isTrue);

      // Uji koreksi collectedAmount saat edit target turun 400.000 -> 300.000
      final goalBeforeEdit = (await goalRepo.getGoalById(goalId))!;
      await goalRepo.updateGoalAndSyncContributions(
        goalBeforeEdit.goal.copyWith(collectedAmount: 300000, status: 'active'),
      );
      // Setoran terbaru (Cash 150rb) dipotong 100rb -> Cash kembali punya 250rb bebas!
      expect(await accountRepo.calculateAccountBalance(cash.id!), 250000);
      expect((await accountRepo.getBalanceSummary()).allocatedInGoals, 300000);

      // Realisasi sisa 300.000 sebagai Pengeluaran nyata -> tidak memotong dua kali!
      await goalRepo.realizeGoalAsExpense(goalId);
      final afterRealizeSummary = await accountRepo.getBalanceSummary();
      expect(afterRealizeSummary.allocatedInGoals, 0);
      expect(await accountRepo.calculateAccountBalance(mandiri.id!), 750000);
      expect(await accountRepo.calculateAccountBalance(cash.id!), 250000);
      expect(afterRealizeSummary.totalNetWorth, 1000000);
      expect(afterRealizeSummary.totalPhysicalNetWorth, 1000000);
    });

    testWidgets('GoalsScreen renders tabs and opens Add Goal modal',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            goalsListProvider.overrideWith((ref) async => const <GoalDetail>[]),
            accountsWithBalanceProvider.overrideWith(
              (ref) async => const <AccountWithBalance>[],
            ),
          ],
          child: const MaterialApp(
            home: GoalsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Pastikan AppBar dan Tabs ada
      expect(find.text('Target & Tabungan'), findsOneWidget);
      expect(find.text('🎯 Berjalan'), findsOneWidget);
      expect(find.text('🎉 Tercapai'), findsOneWidget);

      // Pastikan tombol "Target Baru" ada
      final fabFinder = find.widgetWithText(ElevatedButton, 'Target Baru');
      expect(fabFinder, findsWidgets);

      // Tap untuk membuka modal
      await tester.tap(fabFinder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Pastikan modal bottom sheet muncul dengan field input yang diperlukan
      expect(find.text('Buat Target Baru'), findsOneWidget);
      expect(find.text('Nama Target / Keperluan'), findsOneWidget);
      expect(find.text('Target Nominal (Rp)'), findsOneWidget);
      expect(find.text('Pengingat H-3 Jatuh Tempo'), findsOneWidget);
      expect(find.text('Target Berulang Tiap Bulan'), findsOneWidget);
      expect(find.text('Simpan Target'), findsOneWidget);

      // Tutup modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets(
        'GoalCard fits cleanly without overflow on narrow 320px screens with all action buttons',
        (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final activeDetail = GoalDetail(
        goal: Goal(
          id: 1,
          name: 'Tabungan Belanja Liburan Panjang',
          targetAmount: 5000000,
          collectedAmount: 1500000,
          deadline: DateTime.now().add(const Duration(days: 10)),
          sourceAccountId: 1,
          createdAt: DateTime.now(),
        ),
        sourceAccountName: 'Bank Mandiri',
        sourceAccountColorHex: '0xFF003D79',
        sourceAccountIconCodePoint: Icons.account_balance_rounded.codePoint,
        sourceAccountLogoKey: 'mandiri',
        lockedAmount: 1500000,
      );

      final doneDetail = GoalDetail(
        goal: Goal(
          id: 2,
          name: 'Bayar Ressa',
          targetAmount: 710000,
          collectedAmount: 710000,
          deadline: DateTime.now().add(const Duration(days: 2)),
          sourceAccountId: 1,
          status: 'done',
          createdAt: DateTime.now(),
        ),
        sourceAccountName: 'SeaBank',
        sourceAccountColorHex: '0xFFFF5500',
        sourceAccountIconCodePoint: Icons.account_balance_rounded.codePoint,
        sourceAccountLogoKey: 'seabank',
        lockedAmount: 710000,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    GoalCard(detail: activeDetail),
                    GoalCard(detail: doneDetail),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('Isi Tabungan'), findsOneWidget);
      expect(find.text('Pakai / Bayar'), findsOneWidget);
      expect(find.text('Riwayat'), findsNWidgets(2));
      expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(2));
    });
  });
}
