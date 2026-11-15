import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monetra/core/theme/app_theme.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/transaction.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/category_repository.dart';
import 'package:monetra/data/repositories/report_repository.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:monetra/features/home/providers/home_providers.dart';
import 'package:monetra/features/reports/providers/report_providers.dart';
import 'package:monetra/features/reports/screens/reports_screen.dart';
import 'package:monetra/features/reports/widgets/six_month_trend_chart.dart';
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

  group('Fase 5: Laporan Bulanan & Visualisasi Tests', () {
    test('MonthlyReport aggregates income, expense, and category shares correctly',
        () async {
      final accountRepo = AccountRepository();
      final categoryRepo = CategoryRepository();
      final txRepo = TransactionRepository();
      final reportRepo = ReportRepository();

      final accounts = await accountRepo.getAllAccounts();
      final mandiri = accounts.firstWhere((a) => a.name == 'Mandiri');
      final cash = accounts.firstWhere((a) => a.name == 'Cash');

      final categories = await categoryRepo.getAllCategories();
      final bensin = categories.firstWhere((c) => c.name == 'Bensin');
      final makan = categories.firstWhere((c) => c.name == 'Makan');
      final tagihan = categories.firstWhere((c) => c.name == 'Tagihan');

      final novDate1 = DateTime(2026, 11, 5, 12, 0);
      final novDate2 = DateTime(2026, 11, 10, 14, 0);
      final novDate3 = DateTime(2026, 11, 20, 18, 0);
      final oktDate = DateTime(2026, 10, 25, 9, 0); // Bulan lain

      // 1. Pemasukan Nov 2026: Gaji Rp 3.000.000
      await txRepo.insertTransaction(
        TransactionModel(
          type: 'income',
          amount: 3000000,
          accountId: mandiri.id!,
          note: 'Gaji November',
          date: novDate1,
          createdAt: novDate1,
        ),
      );

      // 2. Pengeluaran Nov 2026:
      // Makan: Rp 500.000 (Cash)
      await txRepo.insertTransaction(
        TransactionModel(
          type: 'expense',
          amount: 500000,
          accountId: cash.id!,
          categoryId: makan.id,
          note: 'Makan',
          date: novDate1,
          createdAt: novDate1,
        ),
      );

      // Bensin: Rp 200.000 (Mandiri)
      await txRepo.insertTransaction(
        TransactionModel(
          type: 'expense',
          amount: 200000,
          accountId: mandiri.id!,
          categoryId: bensin.id,
          note: 'Bensin Motor',
          date: novDate2,
          createdAt: novDate2,
        ),
      );

      // Tagihan: Rp 300.000 (Mandiri)
      await txRepo.insertTransaction(
        TransactionModel(
          type: 'expense',
          amount: 300000,
          accountId: mandiri.id!,
          categoryId: tagihan.id,
          note: 'Listrik & Wifi',
          date: novDate3,
          createdAt: novDate3,
        ),
      );

      // 3. Transaksi di bulan lain (Okt 2026) -> tidak boleh masuk ke laporan Nov
      await txRepo.insertTransaction(
        TransactionModel(
          type: 'expense',
          amount: 800000,
          accountId: mandiri.id!,
          categoryId: makan.id,
          note: 'Belanja Oktober',
          date: oktDate,
          createdAt: oktDate,
        ),
      );

      // 4. Query Laporan November 2026
      final report = await reportRepo.getMonthlyReport(2026, 11);

      // Verifikasi Total
      expect(report.totalIncome, 3000000);
      expect(report.totalExpense, 1000000); // 500rb + 200rb + 300rb
      expect(report.netSavings, 2000000); // Surplus Rp 2.000.000

      // Verifikasi Kategori
      expect(report.categoryExpenses.length, 3);
      final topCat = report.topCategory;
      expect(topCat, isNotNull);
      expect(topCat!.categoryName, 'Makan');
      expect(topCat.totalAmount, 500000);
      expect(topCat.percentage, 50.0); // 500rb / 1jt = 50%

      // Verifikasi Akun Pengeluaran
      final cashShare =
          report.accountExpenses.firstWhere((a) => a.accountName == 'Cash');
      final mandiriShare =
          report.accountExpenses.firstWhere((a) => a.accountName == 'Mandiri');
      expect(cashShare.totalExpense, 500000);
      expect(mandiriShare.totalExpense, 500000); // 200rb + 300rb

      // Verifikasi Hari Terboros
      expect(report.highestExpenseAmount, 500000);

      // 5. Query Laporan Oktober 2026 (Harus hanya berisi 800.000)
      final oktReport = await reportRepo.getMonthlyReport(2026, 10);
      expect(oktReport.totalExpense, 800000);
      expect(oktReport.totalIncome, 0);
    });

    testWidgets('ReportsScreen smoke test', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            monthlyReportProvider.overrideWith(
              (ref) async => const MonthlyReportSummary(
                year: 2026,
                month: 11,
                totalIncome: 0,
                totalExpense: 0,
                netSavings: 0,
                dailyAverageExpense: 0,
                highestExpenseAmount: 0,
                categoryExpenses: [],
                accountExpenses: [],
              ),
            ),
            sixMonthTrendProvider.overrideWith(
              (ref) async => const <MonthlyCashflowPoint>[],
            ),
          ],
          child: const MaterialApp(
            home: ReportsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Laporan Finansial'), findsOneWidget);
    });

    test('getSixMonthTrend returns 6 chronological months with accurate income/expense totals',
        () async {
      final accountRepo = AccountRepository();
      final txRepo = TransactionRepository();
      final reportRepo = ReportRepository();

      final accounts = await accountRepo.getAllAccounts();
      final mandiri = accounts.firstWhere((a) => a.name == 'Mandiri');

      // Isi data pada Agustus, Oktober, dan November 2026 (Juni, Juli, Sept = 0)
      await txRepo.insertTransaction(TransactionModel(
        type: 'income',
        amount: 4000000,
        accountId: mandiri.id!,
        note: 'Gaji Agu',
        date: DateTime(2026, 8, 25),
        createdAt: DateTime(2026, 8, 25),
      ));
      await txRepo.insertTransaction(TransactionModel(
        type: 'expense',
        amount: 2500000,
        accountId: mandiri.id!,
        note: 'Pengeluaran Okt',
        date: DateTime(2026, 10, 12),
        createdAt: DateTime(2026, 10, 12),
      ));
      await txRepo.insertTransaction(TransactionModel(
        type: 'income',
        amount: 5000000,
        accountId: mandiri.id!,
        note: 'Gaji Nov',
        date: DateTime(2026, 11, 5),
        createdAt: DateTime(2026, 11, 5),
      ));
      await txRepo.insertTransaction(TransactionModel(
        type: 'expense',
        amount: 1500000,
        accountId: mandiri.id!,
        note: 'Belanja Nov',
        date: DateTime(2026, 11, 10),
        createdAt: DateTime(2026, 11, 10),
      ));

      final points = await reportRepo.getSixMonthTrend(2026, 11);
      expect(points.length, 6);
      expect(points.map((p) => p.label).toList(),
          ['Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov']);

      expect(points[0].totalIncome, 0);
      expect(points[2].totalIncome, 4000000);
      expect(points[4].totalExpense, 2500000);
      expect(points[5].totalIncome, 5000000);
      expect(points[5].totalExpense, 1500000);
      expect(points[5].net, 3500000);
    });

    testWidgets(
        'SixMonthTrendChart & ReportsScreen render 6-month trend without overflow at 320px and reset touched donut index on month change',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final trendPoints = const [
        MonthlyCashflowPoint(
            year: 2026,
            month: 6,
            label: 'Jun',
            totalIncome: 3000000,
            totalExpense: 2000000),
        MonthlyCashflowPoint(
            year: 2026,
            month: 7,
            label: 'Jul',
            totalIncome: 3200000,
            totalExpense: 2400000),
        MonthlyCashflowPoint(
            year: 2026,
            month: 8,
            label: 'Agu',
            totalIncome: 3100000,
            totalExpense: 1900000),
        MonthlyCashflowPoint(
            year: 2026,
            month: 9,
            label: 'Sep',
            totalIncome: 3500000,
            totalExpense: 2200000),
        MonthlyCashflowPoint(
            year: 2026,
            month: 10,
            label: 'Okt',
            totalIncome: 4000000,
            totalExpense: 2500000),
        MonthlyCashflowPoint(
            year: 2026,
            month: 11,
            label: 'Nov',
            totalIncome: 4500000,
            totalExpense: 1500000),
      ];

      final reportSummary = MonthlyReportSummary(
        year: 2026,
        month: 11,
        totalIncome: 4500000,
        totalExpense: 1500000,
        netSavings: 3000000,
        dailyAverageExpense: 136364,
        highestExpenseDay: '2026-11-10',
        highestExpenseAmount: 700000,
        categoryExpenses: [
          CategoryExpenseShare(
            categoryId: 1,
            categoryName: 'Makan & Minum Sehari-hari',
            colorHex: '0xFFEF4444',
            iconCodePoint: Icons.restaurant_rounded.codePoint,
            totalAmount: 1500000,
            percentage: 100.0,
          ),
        ],
        accountExpenses: const [
          AccountExpenseShare(
            accountId: 1,
            accountName: 'Mandiri',
            colorHex: '0xFFF59E0B',
            totalExpense: 1500000,
            totalIncome: 4500000,
          ),
        ],
      );

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedReportDateProvider
                .overrideWith((ref) => DateTime(2026, 11, 1)),
            monthlyReportProvider.overrideWith((ref) async => reportSummary),
            sixMonthTrendProvider.overrideWith((ref) async => trendPoints),
            touchedCategoryIndexProvider.overrideWith((ref) => 0),
            monthlyDailyActivityProvider.overrideWith(
                (ref) async => const <int, DailyActivityPoint>{}),
            spendingAllocationProvider.overrideWith(
              (ref) async => const SpendingAllocation(
                needsAmount: 0,
                needsPercentage: 0,
                needsStatus: 'aman',
                wantsAmount: 0,
                wantsPercentage: 0,
                wantsStatus: 'aman',
                savingsAmount: 0,
                savingsPercentage: 0,
                savingsStatus: 'aman',
                currentDay: 1,
                totalDaysInMonth: 30,
              ),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                theme: AppTheme.lightTheme,
                home: const ReportsScreen(),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi tanggal Hari Terboros tampil di bagian atas
      expect(find.text('10 Nov 2026'), findsOneWidget);

      // Scroll ke bawah agar SixMonthTrendChart yang lazy di ListView ikut dirender
      await tester.scrollUntilVisible(
        find.byType(SixMonthTrendChart),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Verifikasi SixMonthTrendChart tampil tanpa overflow di 320px
      expect(find.byType(SixMonthTrendChart), findsOneWidget);
      expect(find.text('Tren 6 Bulan Terakhir'), findsOneWidget);
      expect(
        find.text('Lebih hemat Rp 1.000.000 dibanding pengeluaran Okt.'),
        findsOneWidget,
      );

      // Pindah bulan -> touchedCategoryIndexProvider harus otomatis reset ke null
      container.read(touchedCategoryIndexProvider.notifier).state = 0;
      expect(container.read(touchedCategoryIndexProvider), 0);
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      expect(container.read(touchedCategoryIndexProvider), isNull);
    });
  });
}
