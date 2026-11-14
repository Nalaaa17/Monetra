import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monetra/app.dart';
import 'package:monetra/core/theme/app_theme.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/account.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/goal_repository.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:monetra/features/goals/providers/goal_providers.dart';
import 'package:monetra/features/home/providers/home_providers.dart';
import 'package:monetra/features/home/screens/home_screen.dart';
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

  testWidgets('Monetra app smoke test (Splash to Home)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          balanceSummaryProvider.overrideWith(
            (ref) async => const BalanceSummary(
              dailySpendingBalance: 0,
              savingsBalance: 0,
              totalNetWorth: 0,
            ),
          ),
          accountsWithBalanceProvider.overrideWith(
            (ref) async => const <AccountWithBalance>[],
          ),
          recentTransactionsProvider.overrideWith(
            (ref) async => const <TransactionDetail>[],
          ),
          upcomingUrgentGoalsProvider.overrideWith(
            (ref) async => const <GoalDetail>[],
          ),
        ],
        child: const MonetraApp(),
      ),
    );
    await tester.pump();

    // 1. Awal aplikasi menampilkan Splash Screen dengan Logo & Branding
    expect(find.text('Monetra'), findsOneWidget);
    expect(find.text('Pencatatan Keuangan Pribadi'), findsOneWidget);

    // 2. Animasi splash selesai (1.6 detik) dan otomatis berpindah ke Home Screen
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();

    // 3. Verifikasi Home Screen
    expect(find.text('• Halo!'), findsOneWidget);
    expect(find.text('Dompet & Rekening'), findsOneWidget);
  });

  testWidgets(
    'HomeScreen menampilkan rincian saldo tanpa overflow pada layar 320px',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dummyAccounts = [
        AccountWithBalance(
          account: Account(
            id: 1,
            name: 'Bank Central Asia (BCA)',
            type: 'bank',
            category: 'harian',
            colorHex: '0xFF10B981',
            iconCodePoint: Icons.account_balance.codePoint,
            initialBalance: 1500000,
            logoKey: 'bca',
            createdAt: DateTime(2026, 1, 1),
          ),
          balance: 1500000,
          allocatedInGoals: 500000,
        ),
        AccountWithBalance(
          account: Account(
            id: 2,
            name: 'SeaBank Tabungan',
            type: 'bank',
            category: 'tabungan',
            colorHex: '0xFFF97316',
            iconCodePoint: Icons.savings.codePoint,
            initialBalance: 8500000,
            logoKey: 'seabank',
            createdAt: DateTime(2026, 1, 1),
          ),
          balance: 8500000,
          allocatedInGoals: 2000000,
        ),
        AccountWithBalance(
          account: Account(
            id: 3,
            name: 'Dompet Tunai Harian',
            type: 'cash',
            category: 'harian',
            colorHex: '0xFF0EA5E9',
            iconCodePoint: Icons.wallet.codePoint,
            initialBalance: 500000,
            createdAt: DateTime(2026, 1, 1),
          ),
          balance: 500000,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            balanceSummaryProvider.overrideWith(
              (ref) async => const BalanceSummary(
                dailySpendingBalance: 2000000,
                savingsBalance: 8500000,
                totalNetWorth: 10500000,
                allocatedInGoals: 2500000,
                dailyAccountNames: ['BCA', 'GoPay', 'Dana'],
                savingsAccountNames: ['SeaBank'],
              ),
            ),
            accountsWithBalanceProvider.overrideWith(
              (ref) async => dummyAccounts,
            ),
            recentTransactionsProvider.overrideWith(
              (ref) async => const <TransactionDetail>[],
            ),
            upcomingUrgentGoalsProvider.overrideWith(
              (ref) async => const <GoalDetail>[],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final layoutException = tester.takeException();
      expect(layoutException, isNull, reason: layoutException?.toString());
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Menu Utama'), findsOneWidget);
      expect(find.text('Progres Pengeluaran'), findsOneWidget);
      expect(find.text('Aktivitas Bulan Ini'), findsOneWidget);
      expect(find.text('Dompet & Rekening'), findsOneWidget);
    },
  );
}
