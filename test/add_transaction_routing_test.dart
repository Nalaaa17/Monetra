import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monetra/app.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/account.dart';
import 'package:monetra/data/models/category.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/goal_repository.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:monetra/features/goals/providers/goal_providers.dart';
import 'package:monetra/features/home/providers/home_providers.dart';
import 'package:monetra/features/home/widgets/hero_sekilas_card.dart';
import 'package:monetra/features/transaction/providers/transaction_form_provider.dart';
import 'package:monetra/features/transaction/screens/add_transaction_screen.dart';
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

  testWidgets(
      'FloatingBottomBar + button opens Catat Pemasukan directly into Income mode without flashing Expense',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bca = Account(
      id: 1,
      name: 'BCA',
      type: 'bank',
      category: 'harian',
      colorHex: '0xFF0066AE',
      iconCodePoint: Icons.account_balance.codePoint,
      initialBalance: 1000000,
      createdAt: DateTime(2026, 1, 1),
    );

    final gajiCat = Category(
      id: 10,
      name: 'Gaji',
      type: 'income',
      iconCodePoint: Icons.work.codePoint,
      colorHex: '0xFF10B981',
    );

    await AppDatabase.setSetting('onboarding_completed', 'true');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          balanceSummaryProvider.overrideWith(
            (ref) async => const BalanceSummary(
              dailySpendingBalance: 1000000,
              savingsBalance: 0,
              totalNetWorth: 1000000,
            ),
          ),
          accountsWithBalanceProvider.overrideWith(
            (ref) async => [AccountWithBalance(account: bca, balance: 1000000)],
          ),
          recentTransactionsProvider.overrideWith(
            (ref) async => const <TransactionDetail>[],
          ),
          upcomingUrgentGoalsProvider.overrideWith(
            (ref) async => const <GoalDetail>[],
          ),
          categoriesByTypeProvider('income').overrideWith(
            (ref) async => [gajiCat],
          ),
        ],
        child: const MonetraApp(),
      ),
    );

    // 1. Splash screen animation to Home
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // 2. Verifikasi tombol '+' ada di bottom bar, lalu tap
    final addFab = find.byIcon(Icons.add_rounded);
    expect(addFab, findsOneWidget);
    await tester.tap(addFab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // 3. Modal aksi muncul dengan Catat Pengeluaran & Catat Pemasukan
    expect(find.text('Catat Pengeluaran'), findsOneWidget);
    expect(find.text('Catat Pemasukan'), findsOneWidget);

    // 4. Tap 'Catat Pemasukan'
    await tester.tap(find.text('Catat Pemasukan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    // 5. Harus langsung berada di AddTransactionScreen mode Pemasukan
    expect(find.byType(AddTransactionScreen), findsOneWidget);
    expect(find.text('Catat Pemasukan'), findsOneWidget);
    expect(find.text('Catat Pengeluaran'), findsNothing);
  });

  testWidgets(
      'HeroSekilasCard displays ultra-modern allocated cards for Target & Utang without emojis & no overflow at 320px',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const summary = BalanceSummary(
      totalNetWorth: 5000000,
      dailySpendingBalance: 3000000,
      savingsBalance: 2000000,
      savingsAccountNames: ['Tabungan Jenius'],
      allocatedInGoals: 1500000,
      allocatedInDebts: 800000,
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HeroSekilasCard(summary: summary),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verifikasi total aset = total net worth + total allocated (5jt + 1.5jt + 800rb = 7.3jt)
    expect(find.text('Rp 7.300.000'), findsOneWidget);

    // Verifikasi kartu modern untuk Target Tabungan dan Cicilan Utang
    expect(find.text('Target Tabungan'), findsOneWidget);
    expect(find.text('Rp 1.500.000'), findsOneWidget);
    expect(find.text('Cicilan Utang'), findsOneWidget);
    expect(find.text('Rp 800.000'), findsOneWidget);

    // Tidak ada emoji jadul
    expect(find.textContaining('🎯'), findsNothing);
    expect(find.textContaining('💳'), findsNothing);

    // Bebas overflow pada 320px
    expect(tester.takeException(), isNull);
  });
}
