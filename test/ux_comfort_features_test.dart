import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monetra/core/theme/app_theme.dart';
import 'package:monetra/core/theme/theme_provider.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/account.dart';
import 'package:monetra/data/models/transaction.dart';
import 'package:monetra/data/models/transfer.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/category_repository.dart';
import 'package:monetra/data/repositories/goal_repository.dart';
import 'package:monetra/data/repositories/report_repository.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:monetra/data/repositories/transfer_repository.dart';
import 'package:monetra/data/services/backup_service.dart';
import 'package:monetra/features/goals/providers/goal_providers.dart';
import 'package:monetra/features/history/providers/history_providers.dart';
import 'package:monetra/features/home/providers/home_providers.dart';
import 'package:monetra/features/home/screens/home_screen.dart';
import 'package:monetra/features/reports/providers/report_providers.dart';
import 'package:monetra/features/reports/screens/reports_screen.dart';
import 'package:monetra/features/transaction/screens/add_transaction_screen.dart';
import 'package:monetra/features/transaction/screens/edit_transfer_screen.dart';
import 'package:monetra/features/transaction/widgets/custom_numeric_keypad.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppDatabase.testDbPath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await AppDatabase.close();
  });

  group('UX Comfort Features (1-6)', () {
    testWidgets(
        '1. Tapping Uang Harian, Tabungan, and Account cards on HomeScreen sets HistoryFilter and opens History',
        (WidgetTester tester) async {
      final visitedRoutes = <String>[];
      late ProviderContainer container;

      final bca = AccountWithBalance(
        account: Account(
          id: 42,
          name: 'BCA',
          type: 'bank',
          category: 'harian',
          colorHex: '0xFF0060AF',
          iconCodePoint: Icons.account_balance.codePoint,
          initialBalance: 1000000,
          logoKey: 'bca',
          createdAt: DateTime(2026, 1, 1),
        ),
        balance: 1000000,
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const HomeScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (_, _) {
              visitedRoutes.add('/history');
              return const Scaffold(body: Text('Filtered History Page'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            balanceSummaryProvider.overrideWith(
              (ref) async => const BalanceSummary(
                dailySpendingBalance: 1000000,
                savingsBalance: 2000000,
                totalNetWorth: 3000000,
                dailyAccountNames: ['BCA'],
                savingsAccountNames: ['SeaBank'],
              ),
            ),
            accountsWithBalanceProvider.overrideWith((ref) async => [bca]),
            recentTransactionsProvider
                .overrideWith((ref) async => const <TransactionDetail>[]),
            upcomingUrgentGoalsProvider
                .overrideWith((ref) async => const <GoalDetail>[]),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              container = ProviderScope.containerOf(context);
              return MaterialApp.router(
                theme: AppTheme.lightTheme,
                routerConfig: router,
              );
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Scroll sampai section Dompet & Rekening terlihat lalu tap kartu akun BCA
      await tester.scrollUntilVisible(
        find.text('Dompet & Rekening'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('BCA').last);
      await tester.pumpAndSettle();
      expect(visitedRoutes.last, '/history');
      expect(container.read(historyFilterProvider).accountId, 42);
    });

    test('2. ThemeModeController persists dark/light choice into local SQLite settings',
        () async {
      await AppDatabase.instance;

      final container = ProviderContainer();
      expect(container.read(themeModeProvider), ThemeMode.light);

      container.read(themeModeProvider.notifier).state = ThemeMode.dark;
      await Future.delayed(const Duration(milliseconds: 50));

      final restored = await ThemeModeController.readSavedThemeMode();
      expect(restored, ThemeMode.dark);

      container.read(themeModeProvider.notifier).state = ThemeMode.light;
      await Future.delayed(const Duration(milliseconds: 50));

      final restoredLight = await ThemeModeController.readSavedThemeMode();
      expect(restoredLight, ThemeMode.light);

      container.dispose();
    });

    test('3. TransactionRepository filters by categoryId, date range, and account group IDs',
        () async {
      final accountRepo = AccountRepository();
      final catRepo = CategoryRepository();
      final txRepo = TransactionRepository();
      final trRepo = TransferRepository();

      final accounts = await accountRepo.getAllAccounts();
      final mandiri = accounts.firstWhere((a) => a.name == 'Mandiri');
      final seabank = accounts.firstWhere((a) => a.name == 'Seabank');
      final cats = await catRepo.getAllCategories(type: 'expense');
      final bensin = cats.firstWhere((c) => c.name == 'Bensin');
      final makan = cats.firstWhere((c) => c.name == 'Makan');

      await txRepo.insertTransaction(TransactionModel(
        type: 'expense',
        amount: 40000,
        accountId: mandiri.id!,
        categoryId: bensin.id,
        note: 'Bensin Nov 1',
        date: DateTime(2026, 11, 1, 10, 0),
        createdAt: DateTime(2026, 11, 1),
      ));
      await txRepo.insertTransaction(TransactionModel(
        type: 'expense',
        amount: 25000,
        accountId: mandiri.id!,
        categoryId: makan.id,
        note: 'Makan Nov 10',
        date: DateTime(2026, 11, 10, 12, 0),
        createdAt: DateTime(2026, 11, 10),
      ));
      await trRepo.insertTransfer(TransferModel(
        fromAccountId: mandiri.id!,
        toAccountId: seabank.id!,
        amount: 300000,
        note: 'Nabung Nov 10',
        date: DateTime(2026, 11, 10, 15, 0),
        createdAt: DateTime(2026, 11, 10),
      ));

      // Filter per kategori Bensin
      final onlyBensin = await txRepo.getGroupedTransactionsByDate(
        categoryId: bensin.id,
      );
      expect(onlyBensin.length, 1);
      expect(onlyBensin.first.items.single.note, 'Bensin Nov 1');
      expect(onlyBensin.first.transfers, isEmpty);

      // Filter rentang tanggal 5-15 Nov
      final rangeGroups = await txRepo.getGroupedTransactionsByDate(
        startDate: DateTime(2026, 11, 5),
        endDate: DateTime(2026, 11, 15),
      );
      expect(rangeGroups.length, 1);
      expect(rangeGroups.first.items.single.note, 'Makan Nov 10');
      expect(rangeGroups.first.transfers.single.note, 'Nabung Nov 10');

      // Filter accountIds (hanya Seabank -> melihat transfer masuk, tanpa tx Mandiri)
      final savingsOnly = await txRepo.getGroupedTransactionsByDate(
        accountIds: [seabank.id!],
      );
      expect(savingsOnly.length, 1);
      expect(savingsOnly.first.items, isEmpty);
      expect(savingsOnly.first.transfers.single.note, 'Nabung Nov 10');
    });

    test('4. checkEditTransferBalanceWarning catches minus projection & EditTransferScreen updates transfer',
        () async {
      final accountRepo = AccountRepository();
      final trRepo = TransferRepository();

      final accounts = await accountRepo.getAllAccounts();
      final mandiri = accounts.firstWhere((a) => a.name == 'Mandiri');
      final cash = accounts.firstWhere((a) => a.name == 'Cash');

      await accountRepo.updateAccount(mandiri.copyWith(initialBalance: 500000));
      final trId = await trRepo.insertTransfer(TransferModel(
        fromAccountId: mandiri.id!,
        toAccountId: cash.id!,
        amount: 200000,
        note: 'Tarik ATM',
        date: DateTime(2026, 11, 11),
        createdAt: DateTime(2026, 11, 11),
      ));

      // Saldo Mandiri kini 300rb, Cash 200rb. Naikkan transfer ke 600rb -> Mandiri jadi -100rb
      final warning = await accountRepo.checkEditTransferBalanceWarning(
        oldFromAccountId: mandiri.id!,
        oldToAccountId: cash.id!,
        oldAmount: 200000,
        newFromAccountId: mandiri.id!,
        newToAccountId: cash.id!,
        newAmount: 600000,
      );
      expect(warning, isNotNull);
      expect(warning!.projectedBalance, -100000);

      // Update transfer ke 350rb (valid: 500rb - 350rb = 150rb)
      final safeCheck = await accountRepo.checkEditTransferBalanceWarning(
        oldFromAccountId: mandiri.id!,
        oldToAccountId: cash.id!,
        oldAmount: 200000,
        newFromAccountId: mandiri.id!,
        newToAccountId: cash.id!,
        newAmount: 350000,
      );
      expect(safeCheck, isNull);

      final orig = (await trRepo.getTransferById(trId))!;
      await trRepo.updateTransfer(orig.copyWith(amount: 350000));
      expect(await accountRepo.calculateAccountBalance(mandiri.id!), 150000);
      expect(await accountRepo.calculateAccountBalance(cash.id!), 350000);
    });

    testWidgets('4. EditTransferScreen renders with CustomNumericKeypad',
        (WidgetTester tester) async {
      final mandiri = Account(
        id: 1,
        name: 'Mandiri',
        type: 'bank',
        category: 'harian',
        colorHex: '0xFFF59E0B',
        iconCodePoint: Icons.account_balance.codePoint,
        initialBalance: 500000,
        createdAt: DateTime(2026, 1, 1),
      );
      final cash = Account(
        id: 2,
        name: 'Cash',
        type: 'cash',
        category: 'harian',
        colorHex: '0xFF10B981',
        iconCodePoint: Icons.wallet.codePoint,
        initialBalance: 0,
        createdAt: DateTime(2026, 1, 1),
      );
      final detail = TransferDetail(
        transfer: TransferModel(
          id: 7,
          fromAccountId: 1,
          toAccountId: 2,
          amount: 150000,
          note: 'Tarik Tunai',
          date: DateTime(2026, 11, 11),
          createdAt: DateTime(2026, 11, 11),
        ),
        fromAccountName: 'Mandiri',
        fromAccountColorHex: '0xFFF59E0B',
        toAccountName: 'Cash',
        toAccountColorHex: '0xFF10B981',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountsWithBalanceProvider.overrideWith((ref) async => [
                  AccountWithBalance(account: mandiri, balance: 350000),
                  AccountWithBalance(account: cash, balance: 150000),
                ]),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: EditTransferScreen(detail: detail),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ubah Transfer'), findsOneWidget);
      expect(find.byType(CustomNumericKeypad), findsOneWidget);
      expect(find.text('Rp 150.000'), findsWidgets);
    });

    test('5. BackupService.runDailyAutoBackupIfNeeded runs once daily, respects toggle, and prunes old auto backups',
        () async {
      await AppDatabase.instance;
      final tempDir =
          await Directory.systemTemp.createTemp('monetra_autobackup_test_');
      try {
        // Buat 1 manual backup yang tidak boleh terhapus saat pruning
        final manual =
            File('${tempDir.path}${Platform.pathSeparator}monetra_backup_20261001_100000.json');
        await manual.writeAsString('{"app":"Monetra","data":{}}');

        // Run hari 1 -> membuat file autobackup
        final createdDay1 = await BackupService.runDailyAutoBackupIfNeeded(
          nowOverride: DateTime(2026, 11, 10, 9, 0),
          directoryOverride: tempDir,
        );
        expect(createdDay1, isNotNull);
        expect(BackupService.isAutoBackupFile(createdDay1!), isTrue);

        // Run kedua di hari yang sama -> skip (null)
        final secondAttemptSameDay =
            await BackupService.runDailyAutoBackupIfNeeded(
          nowOverride: DateTime(2026, 11, 10, 20, 0),
          directoryOverride: tempDir,
        );
        expect(secondAttemptSameDay, isNull);

        // Simulasikan 16 hari berikutnya agar melebihi batas 14 auto-backup
        for (int i = 1; i <= 16; i++) {
          await BackupService.runDailyAutoBackupIfNeeded(
            nowOverride: DateTime(2026, 11, 10 + i, 9, 0),
            directoryOverride: tempDir,
          );
        }

        final files = await BackupService.listBackupFiles(
          directoryOverride: tempDir,
        );
        final autoFiles =
            files.where(BackupService.isAutoBackupFile).toList();
        expect(autoFiles.length, BackupService.maxRetainedAutoBackups);
        expect(await manual.exists(), isTrue);

        // Nonaktifkan auto-backup -> tidak membuat file baru di hari berikutnya
        await BackupService.setAutoBackupEnabled(false);
        final disabledRun = await BackupService.runDailyAutoBackupIfNeeded(
          nowOverride: DateTime(2026, 12, 1, 9, 0),
          directoryOverride: tempDir,
        );
        expect(disabledRun, isNull);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    testWidgets(
        '6a. AddTransactionScreen confirms discard on back when unsaved changes exist',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountsWithBalanceProvider.overrideWith((ref) async => const []),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AddTransactionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ketik nominal 5000 pada CustomNumericKeypad
      await tester.tap(find.text('5'));
      await tester.tap(find.text('000'));
      await tester.pump();
      expect(find.text('Rp 5.000'), findsOneWidget);

      // Coba Back (Navigator.maybePop) -> dialog konfirmasi muncul
      final navigatorState = tester.state<NavigatorState>(find.byType(Navigator));
      navigatorState.maybePop();
      await tester.pumpAndSettle();

      expect(find.text('Keluar Tanpa Menyimpan?'), findsOneWidget);
      await tester.tap(find.text('Lanjut Isi'));
      await tester.pumpAndSettle();
      expect(find.text('Keluar Tanpa Menyimpan?'), findsNothing);
    });

    testWidgets(
        '6b. ReportsScreen supports horizontal swipe left/right to change month',
        (WidgetTester tester) async {
      late ProviderContainer reportContainer;
      const emptySummary = MonthlyReportSummary(
        year: 2026,
        month: 11,
        totalIncome: 0,
        totalExpense: 0,
        netSavings: 0,
        dailyAverageExpense: 0,
        highestExpenseAmount: 0,
        categoryExpenses: [],
        accountExpenses: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedReportDateProvider.overrideWith((ref) => DateTime(2026, 11, 1)),
            monthlyReportProvider.overrideWith((ref) async => emptySummary),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              reportContainer = ProviderScope.containerOf(context);
              return MaterialApp(
                theme: AppTheme.lightTheme,
                home: const ReportsScreen(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);

      // Fling ke kiri (velocity negatif) -> Desember 2026
      await tester.fling(
        find.byType(ReportsScreen),
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(reportContainer.read(selectedReportDateProvider).month, 12);
      expect(find.text('Desember 2026'), findsOneWidget);

      // Fling ke kanan (velocity positif) -> kembali ke November 2026
      await tester.fling(
        find.byType(ReportsScreen),
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(reportContainer.read(selectedReportDateProvider).month, 11);
    });
  });
}
