import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monetra/core/theme/app_theme.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/goal_repository.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:monetra/features/goals/providers/goal_providers.dart';
import 'package:monetra/features/home/providers/home_providers.dart';
import 'package:monetra/features/home/screens/home_screen.dart';
import 'package:monetra/features/onboarding/providers/onboarding_providers.dart';
import 'package:monetra/features/onboarding/screens/onboarding_screen.dart';
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
      'OnboardingScreen slides through feature cards, accepts user name, and displays personalized greeting on Home',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // 1. Render OnboardingScreen
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Slide 1: Pilih Fokus Finansialmu
    expect(find.text('Pilih Fokus Finansialmu'), findsOneWidget);
    expect(find.text('Keuangan Pribadi'), findsOneWidget);
    expect(find.text('Lanjut'), findsOneWidget);

    // Tap Lanjut -> Slide 2: Pilih Dompet & Bank Kamu
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Dompet & Bank Kamu'), findsOneWidget);
    expect(find.text('BCA'), findsOneWidget);

    // Tap Lanjut -> Slide 3: Nama Panggilan & Ringkasan
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Selamat Datang!'), findsOneWidget);
    expect(find.text('Nama Panggilan'), findsOneWidget);

    // Masukkan nama "Nala"
    await tester.enterText(find.byType(TextField), 'Nala');
    await tester.pump();
    expect(find.text('Mulai sebagai Nala 🚀'), findsOneWidget);

    // Tap Mulai
    await tester.tap(find.text('Mulai sebagai Nala 🚀'));
    await tester.pump(const Duration(milliseconds: 300));

    // Verifikasi tersimpan di database
    final savedName = await AppDatabase.getSetting('user_name');
    final isDone = await OnboardingService.isCompleted();
    expect(savedName, 'Nala');
    expect(isDone, true);
  });

  testWidgets(
      'HomeScreen displays personalized user name and allows editing via dialog',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await AppDatabase.setSetting('user_name', 'Nala');

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
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Harus menampilkan Halo! Nala ☀️
    expect(find.text('• Halo!'), findsOneWidget);
    expect(find.text('Nala ☀️'), findsOneWidget);

    // Tap sapaan nama untuk membuka modal edit nama
    await tester.tap(find.text('Nala ☀️'));
    await tester.pumpAndSettle();

    expect(find.text('Ubah Nama Panggilan'), findsOneWidget);

    // Ganti jadi "Rizky"
    await tester.enterText(find.byType(TextField), 'Rizky');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    // Verifikasi nama berubah menjadi Rizky ☀️
    expect(find.text('Rizky ☀️'), findsOneWidget);
    final updated = await AppDatabase.getSetting('user_name');
    expect(updated, 'Rizky');
  });
}
