import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monetra/core/theme/app_theme.dart';
import 'package:monetra/core/utils/color_helper.dart';
import 'package:monetra/core/utils/icon_helper.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/account.dart';
import 'package:monetra/data/models/category.dart';
import 'package:monetra/data/models/goal.dart';
import 'package:monetra/data/models/transaction.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/category_repository.dart';
import 'package:monetra/data/repositories/goal_repository.dart';
import 'package:monetra/data/repositories/report_repository.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:monetra/data/services/backup_service.dart';
import 'package:monetra/data/services/notification_service.dart';
import 'package:monetra/features/history/providers/history_providers.dart';
import 'package:monetra/features/history/screens/history_screen.dart';
import 'package:monetra/features/home/providers/home_providers.dart';
import 'package:monetra/features/transaction/providers/transaction_form_provider.dart';
import 'package:monetra/features/transaction/providers/transfer_form_provider.dart';
import 'package:monetra/features/transaction/screens/edit_transaction_screen.dart';
import 'package:monetra/features/transaction/screens/transfer_screen.dart';
import 'package:monetra/features/transaction/widgets/custom_numeric_keypad.dart';
import 'package:monetra/shared/providers/repository_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/timezone.dart' as tz;

class _FakeAccountRepository extends AccountRepository {
  final Account account;
  final int currentBalance;

  _FakeAccountRepository({
    required this.account,
    required this.currentBalance,
  });

  @override
  Future<Account?> getAccountById(int id) async =>
      id == account.id ? account : null;

  @override
  Future<int> calculateAccountBalance(int accountId) async =>
      accountId == account.id ? currentBalance : 0;
}

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

  group('Bugfix Audit (B1-B6)', () {
    test('B1: ColorHelper.parseHex handles #RRGGBB, 0xFF, and invalid inputs safely', () {
      expect(ColorHelper.parseHex('#10B981'), const Color(0xFF10B981));
      expect(ColorHelper.parseHex('0xFF10B981'), const Color(0xFF10B981));
      expect(ColorHelper.parseHex('10B981'), const Color(0xFF10B981));
      expect(ColorHelper.parseHex('#80FFB800'), const Color(0x80FFB800));
      expect(ColorHelper.parseHex(''), const Color(0xFF00D09E));
      expect(ColorHelper.parseHex(null), const Color(0xFF00D09E));
      expect(ColorHelper.parseHex('bukan-warna'), const Color(0xFF00D09E));
    });

    testWidgets('B1: HistoryScreen renders legacy account with #RRGGBB colorHex without crashing',
        (WidgetTester tester) async {
      final legacyAccount = Account(
        id: 1,
        name: 'Akun Lama Legacy',
        type: 'bank',
        category: 'harian',
        colorHex: '#10B981',
        iconCodePoint: Icons.account_balance.codePoint,
        initialBalance: 500000,
        createdAt: DateTime(2026, 1, 1),
      );

      final legacyTx = TransactionModel(
        id: 10,
        type: 'expense',
        amount: 25000,
        accountId: 1,
        note: 'Kopi legacy',
        date: DateTime(2026, 11, 10, 9, 0),
        createdAt: DateTime(2026, 11, 10, 9, 0),
      );

      final legacyGroup = DailyTransactionsGroup(
        date: DateTime(2026, 11, 10),
        items: [
          TransactionDetail(
            transaction: legacyTx,
            accountName: legacyAccount.name,
            accountColorHex: legacyAccount.colorHex,
          ),
        ],
        totalIncome: 0,
        totalExpense: 25000,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountsWithBalanceProvider.overrideWith(
              (ref) async => [
                AccountWithBalance(account: legacyAccount, balance: 475000),
              ],
            ),
            groupedHistoryTransactionsProvider.overrideWith(
              (ref) async => [legacyGroup],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Akun Lama Legacy'), findsWidgets);
      expect(find.text('Kopi legacy'), findsOneWidget);
    });

    test('B6: AccountRepository.checkEditTransactionBalanceWarning detects negative projections', () async {
      final accountRepo = AccountRepository();
      final txRepo = TransactionRepository();
      final categoryRepo = CategoryRepository();

      final accId = await accountRepo.insertAccount(
        Account(
          name: 'Dompet Uji DB',
          type: 'bank',
          category: 'harian',
          colorHex: '#0EA5E9',
          iconCodePoint: Icons.account_balance.codePoint,
          initialBalance: 150000,
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      final categories = await categoryRepo.getAllCategories(type: 'expense');
      final catId = categories.first.id!;

      final txId = await txRepo.insertTransaction(
        TransactionModel(
          type: 'expense',
          amount: 50000,
          accountId: accId,
          categoryId: catId,
          note: 'Makan siang',
          date: DateTime(2026, 11, 10, 12, 0),
          createdAt: DateTime(2026, 11, 10, 12, 0),
        ),
      );

      // Saldo saat ini = 150.000 - 50.000 = 100.000
      final savedDetails = await txRepo.getAllTransactionDetails(accountId: accId);
      final targetDetail = savedDetails.firstWhere((d) => d.id == txId);

      // Naikkan ke 120.000 -> aman (sisa +30.000)
      final safeCheck = await accountRepo.checkEditTransactionBalanceWarning(
        original: targetDetail.transaction,
        newType: 'expense',
        newAmount: 120000,
        newAccountId: accId,
      );
      expect(safeCheck, isNull);

      // Naikkan ke 500.000 -> minus (-350.000) -> harus beri warning
      final warningCheck = await accountRepo.checkEditTransactionBalanceWarning(
        original: targetDetail.transaction,
        newType: 'expense',
        newAmount: 500000,
        newAccountId: accId,
      );
      expect(warningCheck, isNotNull);
      expect(warningCheck!.projectedBalance, -350000);
    });

    testWidgets('B2 & B6: EditTransactionScreen uses CustomNumericKeypad & checks minus balance warning',
        (WidgetTester tester) async {
      final account = Account(
        id: 1,
        name: 'Dompet Uji',
        type: 'bank',
        category: 'harian',
        colorHex: '#0EA5E9',
        iconCodePoint: Icons.account_balance.codePoint,
        initialBalance: 150000,
        createdAt: DateTime(2026, 1, 1),
      );

      final cat = Category(
        id: 1,
        name: 'Makan',
        iconCodePoint: Icons.restaurant.codePoint,
        colorHex: '#EF4444',
        type: 'expense',
      );

      final tx = TransactionModel(
        id: 1,
        type: 'expense',
        amount: 50000,
        accountId: 1,
        categoryId: 1,
        note: 'Makan siang',
        date: DateTime(2026, 11, 10, 12, 0),
        createdAt: DateTime(2026, 11, 10, 12, 0),
      );

      final detail = TransactionDetail(
        transaction: tx,
        accountName: account.name,
        accountColorHex: account.colorHex,
        categoryName: cat.name,
        categoryIconCodePoint: cat.iconCodePoint,
        categoryColorHex: cat.colorHex,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountRepositoryProvider.overrideWithValue(
              _FakeAccountRepository(account: account, currentBalance: 100000),
            ),
            accountsWithBalanceProvider.overrideWith(
              (ref) async => [
                AccountWithBalance(account: account, balance: 100000),
              ],
            ),
            categoriesByTypeProvider('expense').overrideWith(
              (ref) async => [cat],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: EditTransactionScreen(detail: detail),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifikasi memakai CustomNumericKeypad
      expect(find.byType(CustomNumericKeypad), findsOneWidget);
      expect(find.text('Rp 50.000'), findsOneWidget);

      // Tap tombol '0' pada CustomNumericKeypad => Rp 50.000 menjadi Rp 500.000
      await tester.tap(find.text('0').last);
      await tester.pump();
      expect(find.text('Rp 500.000'), findsOneWidget);

      // Tap Simpan Perubahan => dialog Peringatan Saldo muncul karena proyeksi minus
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Peringatan Saldo'), findsOneWidget);

      // Tap Batal => dialog menutup dan form kembali aktif (tidak terkunci loading)
      await tester.tap(find.text('Batal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Peringatan Saldo'), findsNothing);
      expect(find.text('Simpan Perubahan'), findsOneWidget);
    });

    test('B3: TransactionFormNotifier resets amount & note cleanly right after submit success', () async {
      final container = ProviderContainer();
      final sub = container.listen(transactionFormNotifierProvider, (_, _) {});

      await Future.delayed(const Duration(milliseconds: 50));
      final notifier =
          container.read(transactionFormNotifierProvider.notifier);

      notifier.appendKey('7');
      notifier.appendKey('5');
      notifier.appendKey('000');
      notifier.setNote('Sarapan pagi');

      expect(container.read(transactionFormNotifierProvider).amount, 75000);
      expect(container.read(transactionFormNotifierProvider).note, 'Sarapan pagi');

      final success = await notifier.submit();
      expect(success, isTrue);

      final afterState = container.read(transactionFormNotifierProvider);
      expect(afterState.rawAmount, '0');
      expect(afterState.amount, 0);
      expect(afterState.note, '');
      expect(afterState.isSubmitting, isFalse);

      sub.close();
      container.dispose();
    });

    test('B4: GoalRepository auto-resets expired repeatMonthly goals & releases unrealized locks', () async {
      final accountRepo = AccountRepository();
      final goalRepo = GoalRepository();

      final accounts = await accountRepo.getAllAccounts();
      final mandiri = accounts.firstWhere((a) => a.name == 'Mandiri');

      // Isi saldo Mandiri Rp 1.000.000 agar terlihat lock & release-nya
      await accountRepo.updateAccount(mandiri.copyWith(initialBalance: 1000000));

      final pastDeadline = DateTime(2026, 10, 23);
      final recurringId = await goalRepo.insertGoal(
        Goal(
          name: 'Bayar Ressa Bulanan',
          targetAmount: 710000,
          deadline: pastDeadline,
          repeatMonthly: true,
          sourceAccountId: mandiri.id!,
          status: 'done',
          createdAt: DateTime(2026, 10, 1),
        ),
      );

      // Tambah kontribusi Rp 710.000 (belum realized -> mengunci saldo Mandiri)
      await goalRepo.addContribution(
        goalId: recurringId,
        sourceAccountId: mandiri.id!,
        amount: 710000,
        date: DateTime(2026, 10, 20),
      );

      // Goal non-berulang yang juga lewat tenggat dan belum selesai -> menjadi 'missed'
      final missedId = await goalRepo.insertGoal(
        Goal(
          name: 'Target Sekali Pakai Lewat',
          targetAmount: 300000,
          deadline: DateTime(2026, 10, 15),
          repeatMonthly: false,
          sourceAccountId: mandiri.id!,
          status: 'active',
          createdAt: DateTime(2026, 10, 1),
        ),
      );

      // Sebelum reset, saldo bebas Mandiri terpotong 710.000 -> sisa 290.000
      expect(await accountRepo.calculateAccountBalance(mandiri.id!), 290000);

      // Jalankan sync pada tanggal 2026-11-11
      final resetCount = await goalRepo.syncRecurringGoals(
        referenceDate: DateTime(2026, 11, 11),
      );
      expect(resetCount, 1);

      final updatedRecurring = await goalRepo.getGoalById(recurringId);
      expect(updatedRecurring, isNotNull);
      expect(updatedRecurring!.collectedAmount, 0);
      expect(updatedRecurring.lockedAmount, 0);
      expect(updatedRecurring.status, 'active');
      expect(updatedRecurring.deadline.year, 2026);
      expect(updatedRecurring.deadline.month, 11);
      expect(updatedRecurring.deadline.day, 23);

      // Saldo bebas Mandiri otomatis kembali normal Rp 1.000.000
      expect(await accountRepo.calculateAccountBalance(mandiri.id!), 1000000);

      // Verifikasi goal non-berulang lewat deadline ditandai 'missed'
      final missedGoal = await goalRepo.getGoalById(missedId);
      expect(missedGoal!.status, 'missed');

      // Verifikasi clamping tanggal akhir bulan (31 Jan -> 28 Feb non-kabisat)
      final clamped = GoalRepository.advanceMonthlyDeadline(
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 1),
      );
      expect(clamped, DateTime(2026, 2, 28));
    });

    test('B5: NotificationService explicitly sets local Indonesian timezones instead of defaulting to UTC', () {
      final wib = NotificationService.resolveAndSetLocalTimezone(
        offsetOverride: const Duration(hours: 7),
      );
      expect(wib, 'Asia/Jakarta');
      expect(tz.local.name, 'Asia/Jakarta');

      final wita = NotificationService.resolveAndSetLocalTimezone(
        offsetOverride: const Duration(hours: 8),
      );
      expect(wita, 'Asia/Makassar');
      expect(tz.local.name, 'Asia/Makassar');

      final wit = NotificationService.resolveAndSetLocalTimezone(
        offsetOverride: const Duration(hours: 9),
      );
      expect(wit, 'Asia/Jayapura');
      expect(tz.local.name, 'Asia/Jayapura');
    });
  });

  group('Bugfix Audit Round 2 (B7-B12 + UI/Report)', () {
    testWidgets('B7: TransferScreen handles 0 accounts safely & hides keypad when keyboard opens',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountsWithBalanceProvider.overrideWith((ref) async => const []),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(viewInsets: const EdgeInsets.only(bottom: 240)),
                child: child!,
              );
            },
            home: const TransferScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Minimal diperlukan 2 dompet'),
        findsNothing,
      );
      expect(
        find.textContaining('Belum ada dompet atau rekening terdaftar'),
        findsOneWidget,
      );
      // Keypad disembunyikan saat viewInsets.bottom > 0
      expect(find.byType(CustomNumericKeypad), findsNothing);
    });

    test('B7: TransferFormNotifier enforces digit limit and resets form after submit', () async {
      final accountRepo = AccountRepository();
      final accounts = await accountRepo.getAllAccounts();
      final mandiri = accounts.firstWhere((a) => a.name == 'Mandiri');
      final cash = accounts.firstWhere((a) => a.name == 'Cash');

      final container = ProviderContainer();
      final sub = container.listen(transferFormNotifierProvider, (_, _) {});
      await Future.delayed(const Duration(milliseconds: 50));

      final notifier = container.read(transferFormNotifierProvider.notifier);
      notifier.setFromAccount(mandiri.id!);
      notifier.setToAccount(cash.id!);

      // Uji batas maxLength=10 dengan tombol 000
      for (int i = 0; i < 9; i++) {
        notifier.appendKey('1');
      }
      notifier.appendKey('000'); // 9 + 3 > 10 harus ditolak
      expect(
        container.read(transferFormNotifierProvider).rawAmount.length,
        lessThanOrEqualTo(10),
      );

      notifier.clearAmount();
      notifier.appendKey('5');
      notifier.appendKey('0');
      notifier.appendKey('000');
      notifier.setNote('Transfer ke dompet');

      final ok = await notifier.submit();
      expect(ok, isTrue);

      final afterState = container.read(transferFormNotifierProvider);
      expect(afterState.rawAmount, '0');
      expect(afterState.note, '');
      expect(afterState.isSubmitting, isFalse);

      sub.close();
      container.dispose();
    });

    test('B8: TransactionFormNotifier avoids category race condition on immediate setType(income)', () async {
      final categoryRepo = CategoryRepository();
      final incomeCats = await categoryRepo.getAllCategories(type: 'income');
      final incomeCatIds = incomeCats.map((c) => c.id).toSet();

      final container = ProviderContainer();
      final sub = container.listen(transactionFormNotifierProvider, (_, _) {});
      final notifier =
          container.read(transactionFormNotifierProvider.notifier);

      // Langsung pindah ke income sebelum _initDefaults selesai (simulasi /add?type=income)
      notifier.setType('income');
      await Future.delayed(const Duration(milliseconds: 80));

      final state = container.read(transactionFormNotifierProvider);
      expect(state.type, 'income');
      expect(incomeCatIds.contains(state.selectedCategoryId), isTrue);

      // Pastikan clearCategory benar-benar menghapus kategori
      final cleared = state.copyWith(clearCategory: true);
      expect(cleared.selectedCategoryId, isNull);

      sub.close();
      container.dispose();
    });

    test('B9: deleteAccount cleans up cross-account goal_contributions and updates goal totals', () async {
      final accountRepo = AccountRepository();
      final goalRepo = GoalRepository();

      final accounts = await accountRepo.getAllAccounts();
      final mandiri = accounts.firstWhere((a) => a.name == 'Mandiri');
      final cash = accounts.firstWhere((a) => a.name == 'Cash');

      final goalId = await goalRepo.insertGoal(
        Goal(
          name: 'Dana Darurat Gabungan',
          targetAmount: 500000,
          deadline: DateTime.now().add(const Duration(days: 15)),
          sourceAccountId: mandiri.id!,
          createdAt: DateTime.now(),
        ),
      );

      // Isi Rp 200rb dari Mandiri dan Rp 300rb dari Cash (goal menjadi done 500rb)
      await goalRepo.addContribution(
        goalId: goalId,
        sourceAccountId: mandiri.id!,
        amount: 200000,
      );
      await goalRepo.addContribution(
        goalId: goalId,
        sourceAccountId: cash.id!,
        amount: 300000,
      );

      // Hapus akun Cash
      await accountRepo.deleteAccount(cash.id!);

      // Target Mandiri tidak terhapus, tetapi kontribusi yatim dari Cash hilang & saldo disesuaikan
      final updatedGoal = await goalRepo.getGoalById(goalId);
      expect(updatedGoal, isNotNull);
      expect(updatedGoal!.collectedAmount, 200000);
      expect(updatedGoal.lockedAmount, 200000);
      expect(updatedGoal.status, 'active');

      final summary = await accountRepo.getBalanceSummary();
      expect(summary.allocatedInGoals, 200000);
    });

    test('B10: updateGoalAndSyncContributions locks funds on Cycle 2 after Cycle 1 repeatMonthly realization', () async {
      final accountRepo = AccountRepository();
      final goalRepo = GoalRepository();

      final accounts = await accountRepo.getAllAccounts();
      final mandiri = accounts.firstWhere((a) => a.name == 'Mandiri');
      await accountRepo.updateAccount(mandiri.copyWith(initialBalance: 1000000));

      final pastDeadline = DateTime(2026, 10, 23);
      final goalId = await goalRepo.insertGoal(
        Goal(
          name: 'Tagihan Bulanan',
          targetAmount: 500000,
          deadline: pastDeadline,
          repeatMonthly: true,
          sourceAccountId: mandiri.id!,
          createdAt: DateTime(2026, 10, 1),
        ),
      );

      // Siklus 1: setor 500rb lalu realisasikan sebagai pengeluaran (isRealized = 1)
      await goalRepo.addContribution(
        goalId: goalId,
        sourceAccountId: mandiri.id!,
        amount: 500000,
        date: DateTime(2026, 10, 20),
      );
      await goalRepo.realizeGoalAsExpense(goalId);

      // Siklus 2: lewat deadline -> syncRecurringGoals reset collectedAmount = 0
      await goalRepo.syncRecurringGoals(referenceDate: DateTime(2026, 11, 1));
      final cycle2Start = await goalRepo.getGoalById(goalId);
      expect(cycle2Start!.collectedAmount, 0);
      expect(cycle2Start.status, 'active');

      // Saldo bebas Mandiri sekarang 1.000.000 - 500.000 (expense siklus 1) = 500.000
      expect(await accountRepo.calculateAccountBalance(mandiri.id!), 500000);

      // User edit target di Siklus 2 dengan menyisihkan 100.000
      await goalRepo.updateGoalAndSyncContributions(
        cycle2Start.goal.copyWith(collectedAmount: 100000),
        adjustmentAccountId: mandiri.id!,
      );

      final cycle2Edited = await goalRepo.getGoalById(goalId);
      expect(cycle2Edited!.lockedAmount, 100000);
      expect(await accountRepo.calculateAccountBalance(mandiri.id!), 400000);
    });

    test('B12 & Minor: BackupService stats/restore backfill, IconHelper defaults, & Report LEFT JOIN', () async {
      // 1. IconHelper mengenali ikon Hiburan & Lainnya default
      expect(
        IconHelper.getIcon(Icons.sports_esports_rounded.codePoint),
        Icons.sports_esports_rounded,
      );
      expect(
        IconHelper.getIcon(Icons.inventory_2_rounded.codePoint),
        Icons.inventory_2_rounded,
      );

      // 2. ReportRepository LEFT JOIN ikut menghitung pengeluaran tanpa kategori
      final accountRepo = AccountRepository();
      final txRepo = TransactionRepository();
      final reportRepo = ReportRepository();
      final goalRepo = GoalRepository();

      final accounts = await accountRepo.getAllAccounts();
      final cash = accounts.firstWhere((a) => a.name == 'Cash');

      await txRepo.insertTransaction(
        TransactionModel(
          type: 'expense',
          amount: 45000,
          accountId: cash.id!,
          categoryId: null,
          note: 'Pengeluaran tanpa kategori',
          date: DateTime(2026, 11, 10),
          createdAt: DateTime(2026, 11, 10),
        ),
      );

      final report = await reportRepo.getMonthlyReport(2026, 11);
      expect(report.totalExpense, 45000);
      expect(report.categoryExpenses.length, 1);
      expect(report.categoryExpenses.first.categoryName, 'Tanpa Kategori');
      expect(report.categoryExpenses.first.totalAmount, 45000);

      // 3. BackupService stats & legacy null sourceAccountId backfill saat restore
      final gId = await goalRepo.insertGoal(
        Goal(
          name: 'Target Backup',
          targetAmount: 200000,
          collectedAmount: 0,
          deadline: DateTime(2026, 12, 1),
          sourceAccountId: cash.id!,
          createdAt: DateTime(2026, 11, 1),
        ),
      );
      await goalRepo.addContribution(
        goalId: gId,
        sourceAccountId: cash.id!,
        amount: 50000,
      );

      final stats = await BackupService.getCurrentStats();
      expect(stats.goalsCount, 1);

      final exported = await BackupService.exportToJsonString();
      final decoded = jsonDecode(exported) as Map<String, dynamic>;
      final contribs = (decoded['data']['goal_contributions'] as List)
          .cast<Map<String, dynamic>>();
      for (final c in contribs) {
        c['sourceAccountId'] = null;
      }

      final restored = await BackupService.restoreFromJsonString(
        jsonEncode(decoded),
      );
      expect(restored, isTrue);
      expect(await accountRepo.calculateGoalAllocatedForAccount(cash.id!), 50000);
    });
  });
}
