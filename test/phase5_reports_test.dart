import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/transaction.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/category_repository.dart';
import 'package:monetra/data/repositories/report_repository.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:monetra/features/reports/screens/reports_screen.dart';
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
        const ProviderScope(
          child: MaterialApp(
            home: ReportsScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Laporan Finansial'), findsOneWidget);
    });
  });
}
