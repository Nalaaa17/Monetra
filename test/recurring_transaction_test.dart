import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monetra/core/theme/app_theme.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/account.dart';
import 'package:monetra/data/models/category.dart';
import 'package:monetra/data/models/goal.dart';
import 'package:monetra/data/models/recurring_transaction.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/category_repository.dart';
import 'package:monetra/data/repositories/goal_repository.dart';
import 'package:monetra/data/repositories/recurring_transaction_repository.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:monetra/data/services/backup_service.dart';
import 'package:monetra/features/accounts/screens/manage_accounts_screen.dart';
import 'package:monetra/features/goals/providers/goal_providers.dart';
import 'package:monetra/features/goals/widgets/goal_contribution_modal.dart';
import 'package:monetra/features/goals/widgets/home_goal_preview_section.dart';
import 'package:monetra/features/recurring/providers/recurring_providers.dart';
import 'package:monetra/features/home/providers/home_providers.dart';
import 'package:monetra/features/recurring/screens/recurring_transactions_screen.dart';
import 'package:monetra/features/transaction/providers/transaction_form_provider.dart';
import 'package:monetra/features/transaction/screens/add_transaction_screen.dart';
import 'package:monetra/features/transaction/screens/transfer_screen.dart';
import 'package:monetra/shared/providers/repository_providers.dart';
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

  group('Transaksi Berulang Otomatis (Recurring Transaction)', () {
    test('Date helper preserves day 31 anchor across Feb/Apr & handles leap year',
        () {
      // Non-leap year: 31 Jan 2026 -> 28 Feb -> 31 Mar -> 30 Apr -> 31 May
      final jan31 = DateTime(2026, 1, 31);
      final feb = RecurringTransactionRepository.nextMonthlyDate(jan31, 31);
      expect(feb, DateTime(2026, 2, 28));

      final mar = RecurringTransactionRepository.nextMonthlyDate(feb, 31);
      expect(mar, DateTime(2026, 3, 31));

      final apr = RecurringTransactionRepository.nextMonthlyDate(mar, 31);
      expect(apr, DateTime(2026, 4, 30));

      final may = RecurringTransactionRepository.nextMonthlyDate(apr, 31);
      expect(may, DateTime(2026, 5, 31));

      // Leap year: 31 Jan 2024 -> 29 Feb 2024
      final leapFeb = RecurringTransactionRepository.nextMonthlyDate(
        DateTime(2024, 1, 31),
        31,
      );
      expect(leapFeb, DateTime(2024, 2, 29));

      // computeFirstDueDate dengan includeToday = true vs false
      expect(
        RecurringTransactionRepository.computeFirstDueDate(
          frequency: 'monthly',
          dayOfMonth: 11,
          dayOfWeek: 1,
          referenceDate: DateTime(2026, 11, 11),
          includeToday: true,
        ),
        DateTime(2026, 11, 11),
      );
      expect(
        RecurringTransactionRepository.computeFirstDueDate(
          frequency: 'monthly',
          dayOfMonth: 11,
          dayOfWeek: 1,
          referenceDate: DateTime(2026, 11, 11),
          includeToday: false,
        ),
        DateTime(2026, 12, 11),
      );
    });

    test(
        'syncRecurringTransactions executes missed cycles accurately without double-recording',
        () async {
      final accountRepo = AccountRepository();
      final categoryRepo = CategoryRepository();
      final txRepo = TransactionRepository();
      final recurringRepo = RecurringTransactionRepository();

      final accounts = await accountRepo.getAllAccounts();
      final mandiri = accounts.firstWhere((a) => a.name == 'Mandiri');
      final expenseCats = await categoryRepo.getAllCategories(type: 'expense');
      final billCat = expenseCats.firstWhere((c) => c.name == 'Tagihan');
      final incomeCats = await categoryRepo.getAllCategories(type: 'income');
      final salaryCat = incomeCats.firstWhere((c) => c.name == 'Gaji');

      // Jadwal 1: Gaji bulanan tanggal 25, jatuh tempo sejak 25 Okt 2026
      await recurringRepo.insertRecurring(
        RecurringTransaction(
          title: 'Gaji Bulanan',
          type: 'income',
          amount: 5000000,
          accountId: mandiri.id!,
          categoryId: salaryCat.id,
          frequency: 'monthly',
          dayOfMonth: 25,
          dayOfWeek: 1,
          nextRunDate: DateTime(2026, 10, 25),
          createdAt: DateTime(2026, 10, 1),
        ),
      );

      // Jadwal 2: Wi-Fi bulanan tanggal 10, jatuh tempo 10 Nov 2026
      await recurringRepo.insertRecurring(
        RecurringTransaction(
          title: 'Wi-Fi Rumah',
          type: 'expense',
          amount: 350000,
          accountId: mandiri.id!,
          categoryId: billCat.id,
          note: 'Biznet',
          frequency: 'monthly',
          dayOfMonth: 10,
          dayOfWeek: 1,
          nextRunDate: DateTime(2026, 11, 10),
          createdAt: DateTime(2026, 10, 15),
        ),
      );

      // Sinkronisasi pada 11 Nov 2026 -> Gaji Okt 25 (1x) + Wi-Fi Nov 10 (1x)
      final sync1 = await recurringRepo.syncRecurringTransactions(
        referenceDate: DateTime(2026, 11, 11, 14, 0),
      );
      expect(sync1.createdCount, 2);
      expect(sync1.createdTitles, containsAll(['Gaji Bulanan', 'Wi-Fi Rumah']));

      // Saldo Mandiri: +5.000.000 - 350.000 = 4.650.000
      expect(await accountRepo.calculateAccountBalance(mandiri.id!), 4650000);

      // Panggil sync lagi di tanggal sama -> harus idempotent (0 transaksi baru)
      final sync2 = await recurringRepo.syncRecurringTransactions(
        referenceDate: DateTime(2026, 11, 11, 20, 0),
      );
      expect(sync2.createdCount, 0);

      // Panggil sync lagi pada 26 Nov 2026 -> Gaji Nov 25 harus tercatat (1x)
      final sync3 = await recurringRepo.syncRecurringTransactions(
        referenceDate: DateTime(2026, 11, 26, 8, 0),
      );
      expect(sync3.createdCount, 1);
      expect(sync3.createdTitles, ['Gaji Bulanan']);
      expect(await accountRepo.calculateAccountBalance(mandiri.id!), 9650000);

      final allTx = await txRepo.getAllTransactionDetails();
      expect(allTx.length, 3);
      final wifiTx = allTx.firstWhere((t) => t.note!.contains('Wi-Fi Rumah'));
      expect(wifiTx.note, 'Wi-Fi Rumah • Biznet (Rutin)');
      expect(wifiTx.date.month, 11);
      expect(wifiTx.date.day, 10);

      // Verifikasi nextRunDate tersimpan dengan benar (25 Des & 10 Des)
      final rules = await recurringRepo.getAllRecurringDetails();
      final gajiRule = rules.firstWhere((r) => r.title == 'Gaji Bulanan');
      final wifiRule = rules.firstWhere((r) => r.title == 'Wi-Fi Rumah');
      expect(gajiRule.nextRunDate, DateTime(2026, 12, 25));
      expect(wifiRule.nextRunDate, DateTime(2026, 12, 10));
    });

    test('Weekly catch-up, pause/resume, manual record, and backup roundtrip',
        () async {
      final accountRepo = AccountRepository();
      final recurringRepo = RecurringTransactionRepository();
      final txRepo = TransactionRepository();

      final accounts = await accountRepo.getAllAccounts();
      final cash = accounts.firstWhere((a) => a.name == 'Cash');

      // 1. Mingguan tiap Rabu mulai 28 Okt 2026; sync pada 11 Nov 2026 -> 3 kali (28 Okt, 4 Nov, 11 Nov)
      final weeklyId = await recurringRepo.insertRecurring(
        RecurringTransaction(
          title: 'Jajan Kopi Mingguan',
          type: 'expense',
          amount: 25000,
          accountId: cash.id!,
          frequency: 'weekly',
          dayOfMonth: 28,
          dayOfWeek: DateTime.wednesday,
          nextRunDate: DateTime(2026, 10, 28),
          createdAt: DateTime(2026, 10, 20),
        ),
      );

      final weeklySync = await recurringRepo.syncRecurringTransactions(
        referenceDate: DateTime(2026, 11, 11),
      );
      expect(weeklySync.createdCount, 3);
      expect(await accountRepo.calculateAccountBalance(cash.id!), -75000);

      // 2. Manual recordOccurrenceNow pada 12 Nov -> nextRunDate sebelumnya 18 Nov digeser ke 25 Nov
      final nextAfterManual = await recurringRepo.recordOccurrenceNow(
        weeklyId,
        referenceDate: DateTime(2026, 11, 12, 10, 0),
      );
      expect(nextAfterManual, DateTime(2026, 11, 25));
      expect(await accountRepo.calculateAccountBalance(cash.id!), -100000);

      // 3. Jadwal dijeda saat lewat tenggat, lalu diaktifkan kembali tidak back-fill masa jeda
      final pausedId = await recurringRepo.insertRecurring(
        RecurringTransaction(
          title: 'Langganan Musik',
          type: 'expense',
          amount: 55000,
          accountId: cash.id!,
          frequency: 'monthly',
          dayOfMonth: 5,
          dayOfWeek: 1,
          nextRunDate: DateTime(2026, 9, 5),
          isActive: false,
          createdAt: DateTime(2026, 9, 1),
        ),
      );
      await recurringRepo.toggleActive(
        pausedId,
        true,
        referenceDate: DateTime(2026, 11, 11),
      );
      final afterResumeSync = await recurringRepo.syncRecurringTransactions(
        referenceDate: DateTime(2026, 11, 11),
      );
      expect(afterResumeSync.createdCount, 0);

      final rulesBeforeBackup = await recurringRepo.getAllRecurringDetails();
      final musikRule =
          rulesBeforeBackup.firstWhere((r) => r.id == pausedId);
      expect(musikRule.nextRunDate, DateTime(2026, 12, 5));

      // 4. Backup & Restore preserves recurring_transactions
      final stats = await BackupService.getCurrentStats();
      expect(stats.recurringCount, 2);

      final jsonBackup = await BackupService.exportToJsonString();
      expect(jsonBackup, contains('Jajan Kopi Mingguan'));
      expect(jsonBackup, contains('Langganan Musik'));

      final db = await AppDatabase.instance;
      await db.delete('recurring_transactions');
      expect((await recurringRepo.getAllRecurringDetails()).isEmpty, isTrue);

      final restored = await BackupService.restoreFromJsonString(jsonBackup);
      expect(restored, isTrue);
      final restoredRules = await recurringRepo.getAllRecurringDetails();
      expect(restoredRules.length, 2);
      expect(
        restoredRules.map((r) => r.title),
        containsAll(['Jajan Kopi Mingguan', 'Langganan Musik']),
      );
      expect((await txRepo.getAllTransactionDetails()).length, 4);
    });

    test('Deleting an account cascades delete to its recurring rules', () async {
      final accountRepo = AccountRepository();
      final recurringRepo = RecurringTransactionRepository();
      final accounts = await accountRepo.getAllAccounts();
      final mandiri = accounts.firstWhere((a) => a.name == 'Mandiri');

      await recurringRepo.insertRecurring(
        RecurringTransaction(
          title: 'Cicilan Tes',
          type: 'expense',
          amount: 400000,
          accountId: mandiri.id!,
          frequency: 'monthly',
          dayOfMonth: 15,
          nextRunDate: DateTime(2026, 12, 15),
          createdAt: DateTime(2026, 11, 1),
        ),
      );

      expect((await recurringRepo.getAllRecurringDetails()).length, 1);
      await accountRepo.deleteAccount(mandiri.id!);
      expect((await recurringRepo.getAllRecurringDetails()).isEmpty, isTrue);
    });

    testWidgets(
        'RecurringTransactionsScreen & Form render cleanly without overflow at 320px and save new rule',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mandiriAccount = AccountWithBalance(
        account: Account(
          id: 1,
          name: 'Mandiri',
          type: 'bank',
          category: 'harian',
          colorHex: '0xFFF59E0B',
          iconCodePoint: Icons.credit_card_rounded.codePoint,
          initialBalance: 5000000,
          createdAt: DateTime(2026, 1, 1),
        ),
        balance: 5000000,
      );

      final billCat = Category(
        id: 10,
        name: 'Tagihan',
        iconCodePoint: Icons.receipt_long_rounded.codePoint,
        colorHex: '0xFF3B82F6',
        type: 'expense',
      );

      final fakeRepo = _InMemoryRecurringRepo([
        RecurringTransactionDetail(
          rule: RecurringTransaction(
            id: 1,
            title: 'Wi-Fi Indihome Rumah Super Panjang',
            type: 'expense',
            amount: 385000,
            accountId: 1,
            categoryId: 10,
            frequency: 'monthly',
            dayOfMonth: 20,
            nextRunDate: DateTime(2099, 12, 20),
            createdAt: DateTime(2026, 11, 1),
          ),
          accountName: 'Mandiri',
          accountColorHex: '0xFFF59E0B',
          categoryName: 'Tagihan',
          categoryIconCodePoint: billCat.iconCodePoint,
          categoryColorHex: billCat.colorHex,
        ),
        RecurringTransactionDetail(
          rule: RecurringTransaction(
            id: 2,
            title: 'Gaji Bulanan',
            type: 'income',
            amount: 6500000,
            accountId: 1,
            frequency: 'monthly',
            dayOfMonth: 25,
            nextRunDate: DateTime(2099, 12, 25),
            isActive: false,
            createdAt: DateTime(2026, 11, 1),
          ),
          accountName: 'Mandiri',
          accountColorHex: '0xFFF59E0B',
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recurringTransactionRepositoryProvider.overrideWithValue(fakeRepo),
            recurringTransactionsListProvider.overrideWith((ref) async {
              ref.watch(homeRefreshTriggerProvider);
              return await fakeRepo.getAllRecurringDetails();
            }),
            accountsWithBalanceProvider.overrideWith(
              (ref) async => [mandiriAccount],
            ),
            categoriesByTypeProvider('expense').overrideWith(
              (ref) async => [billCat],
            ),
            categoriesByTypeProvider('income').overrideWith(
              (ref) async => const <Category>[],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const RecurringTransactionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transaksi Berulang'), findsOneWidget);
      expect(find.text('Estimasi Rutin / Bulan'), findsOneWidget);
      expect(
        find.text('Wi-Fi Indihome Rumah Super Panjang'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // Buka modal Buat Jadwal via FAB
      await tester.tap(find.text('Buat Jadwal'));
      await tester.pumpAndSettle();

      expect(find.text('Buat Transaksi Berulang'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Isi form dan simpan jadwal baru
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Kuota Bulanan');
      await tester.enterText(fields.at(1), '100000');
      await tester.pump();

      final saveBtn = find.text('Simpan Jadwal Rutin');
      await tester.ensureVisible(saveBtn);
      await tester.pump();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final allRules = await fakeRepo.getAllRecurringDetails();
      expect(allRules.any((r) => r.title == 'Kuota Bulanan'), isTrue);
      expect(find.text('Kuota Bulanan'), findsOneWidget);
    });

    test(
        'categoriesByTypeProvider refreshes immediately when categories change',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialExpense =
          await container.read(categoriesByTypeProvider('expense').future);
      final initialCount = initialExpense.length;

      final catRepo = CategoryRepository();
      await catRepo.insertCategory(
        Category(
          name: 'Langganan Cloud',
          iconCodePoint: Icons.cloud_outlined.codePoint,
          colorHex: '0xFF3B82F6',
          type: 'expense',
        ),
      );
      container.read(homeRefreshTriggerProvider.notifier).state++;

      final updatedExpense =
          await container.read(categoriesByTypeProvider('expense').future);
      expect(updatedExpense.length, initialCount + 1);
      expect(
        updatedExpense.any((c) => c.name == 'Langganan Cloud'),
        isTrue,
      );
    });

    testWidgets(
        'ManageAccountsScreen, HomeGoalPreviewSection, GoalContributionModal & AddTransactionScreen handle 320px without overflow',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bigAccount = AccountWithBalance(
        account: Account(
          id: 1,
          name: 'Rekening Operasional Utama',
          type: 'bank',
          category: 'harian',
          colorHex: '0xFFF59E0B',
          iconCodePoint: Icons.account_balance_rounded.codePoint,
          initialBalance: 15000000,
          createdAt: DateTime(2026, 1, 1),
        ),
        balance: 12500000,
        allocatedInGoals: 2500000,
      );

      final sampleGoal = GoalDetail(
        goal: Goal(
          id: 5,
          name: 'Dana Darurat Panjang',
          targetAmount: 50000000,
          collectedAmount: 12500000,
          deadline: DateTime(2026, 12, 31),
          sourceAccountId: 1,
          createdAt: DateTime(2026, 1, 1),
        ),
        sourceAccountName: 'Rekening Operasional Utama',
        sourceAccountColorHex: '0xFFF59E0B',
        sourceAccountIconCodePoint: Icons.account_balance_rounded.codePoint,
        lockedAmount: 2500000,
      );

      final sampleCat = Category(
        id: 1,
        name: 'Tagihan',
        iconCodePoint: Icons.receipt_long_rounded.codePoint,
        colorHex: '0xFF3B82F6',
        type: 'expense',
      );

      // 1. ManageAccountsScreen
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            accountsWithBalanceProvider.overrideWith((ref) async => [bigAccount]),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ManageAccountsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 2. HomeGoalPreviewSection + GoalContributionModal (validates empty input with SnackBar)
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            accountsWithBalanceProvider.overrideWith((ref) async => [bigAccount]),
            upcomingUrgentGoalsProvider.overrideWith((ref) async => [sampleGoal]),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => SingleChildScrollView(
                  child: Column(
                    children: [
                      const HomeGoalPreviewSection(),
                      ElevatedButton(
                        onPressed: () =>
                            showAddContributionModal(context, ref, sampleGoal),
                        child: const Text('Buka Setoran'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Buka Setoran'));
      await tester.pumpAndSettle();

      // Submit kosong harus muncul pesan error validasi (bukan diam saja)
      final submitContrib = find.text('Sisihkan ke Target');
      await tester.ensureVisible(submitContrib);
      await tester.tap(submitContrib);
      await tester.pumpAndSettle();
      expect(
        find.text('Masukkan nominal setoran lebih dari Rp 0.'),
        findsOneWidget,
      );

      // 3. AddTransactionScreen
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            accountRepositoryProvider.overrideWithValue(
              _FakeAccountRepo([bigAccount.account]),
            ),
            categoryRepositoryProvider.overrideWithValue(
              _FakeCategoryRepo([sampleCat]),
            ),
            accountsWithBalanceProvider.overrideWith((ref) async => [bigAccount]),
            categoriesByTypeProvider('expense')
                .overrideWith((ref) async => [sampleCat]),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AddTransactionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 4. TransferScreen with huge balances at 320px
      final hugeSavingsAccount = AccountWithBalance(
        account: Account(
          id: 2,
          name: 'Tabungan SeaBank Utama',
          type: 'bank',
          category: 'tabungan',
          colorHex: '0xFF059669',
          iconCodePoint: Icons.savings_rounded.codePoint,
          initialBalance: 150000000,
          createdAt: DateTime(2026, 1, 1),
        ),
        balance: 150000000,
      );
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            accountRepositoryProvider.overrideWithValue(
              _FakeAccountRepo([bigAccount.account, hugeSavingsAccount.account]),
            ),
            accountsWithBalanceProvider.overrideWith(
              (ref) async => [bigAccount, hugeSavingsAccount],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const TransferScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    });

    test('Legacy backup JSON without recurring_transactions restores cleanly',
        () async {
      final exported = await BackupService.exportToJsonString();
      final legacyMap = jsonDecode(exported) as Map<String, dynamic>;
      (legacyMap['data'] as Map<String, dynamic>)
          .remove('recurring_transactions');
      final legacyJson = jsonEncode(legacyMap);

      final ok = await BackupService.restoreFromJsonString(legacyJson);
      expect(ok, isTrue);
    });
  });
}

class _InMemoryRecurringRepo extends RecurringTransactionRepository {
  final List<RecurringTransactionDetail> _items;
  int _nextId = 100;

  _InMemoryRecurringRepo(List<RecurringTransactionDetail> initial)
      : _items = List.of(initial);

  @override
  Future<RecurringSyncResult> syncRecurringTransactions({
    DateTime? referenceDate,
  }) async {
    return const RecurringSyncResult(createdCount: 0);
  }

  @override
  Future<List<RecurringTransactionDetail>> getAllRecurringDetails() async {
    return List.unmodifiable(_items);
  }

  @override
  Future<int> insertRecurring(RecurringTransaction rule) async {
    final assignedId = _nextId++;
    _items.insert(
      0,
      RecurringTransactionDetail(
        rule: rule.copyWith(id: assignedId),
        accountName: 'Mandiri',
        accountColorHex: '0xFFF59E0B',
      ),
    );
    return assignedId;
  }
}

class _FakeAccountRepo extends AccountRepository {
  final List<Account> _accounts;
  _FakeAccountRepo(this._accounts);

  @override
  Future<List<Account>> getAllAccounts({bool includeArchived = false}) async {
    return _accounts;
  }
}

class _FakeCategoryRepo extends CategoryRepository {
  final List<Category> _categories;
  _FakeCategoryRepo(this._categories);

  @override
  Future<List<Category>> getAllCategories({
    String? type,
    bool onlyActive = true,
  }) async {
    if (type == null) return _categories;
    return _categories.where((c) => c.type == type).toList();
  }
}

