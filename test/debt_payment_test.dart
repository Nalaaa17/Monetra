import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/account.dart';
import 'package:monetra/data/models/debt_model.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/debt_repository.dart';
import 'package:monetra/features/debts/providers/debt_providers.dart';
import 'package:monetra/features/debts/screens/debt_screen.dart';
import 'package:monetra/features/home/providers/home_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppDatabase.testDbPath = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await AppDatabase.close();
  });

  group('Debt & Payment Features Test', () {
    test('recordPayment updates paidAmount, settles debt, and logs transaction from selected account', () async {
      final accountRepo = AccountRepository();
      final debtRepo = DebtRepository();

      // Buat akun BCA
      final accId = await accountRepo.insertAccount(
        Account(
          name: 'BCA',
          type: 'bank',
          category: 'harian',
          colorHex: '0xFF003D79',
          iconCodePoint: 1234,
          initialBalance: 2000000,
          createdAt: DateTime.now(),
        ),
      );

      // Buat data Utang: Pinjaman Motor Rp 1.500.000
      final debtId = await debtRepo.insertDebt(
        DebtModel(
          title: 'Pinjaman Motor',
          personName: 'BCA Finance',
          type: 'debt',
          totalAmount: 1500000,
          paidAmount: 0,
          dueDate: DateTime(2026, 12, 1),
          createdAt: DateTime.now(),
        ),
      );

      // Bayar cicilan 500.000 dari akun BCA
      await debtRepo.recordPayment(
        debtId,
        500000,
        accountId: accId,
        note: 'Cicilan 1',
      );

      final debts = await debtRepo.getAllDebts();
      expect(debts.first.paidAmount, 500000);
      expect(debts.first.remainingAmount, 1000000);
      expect(debts.first.isSettled, false);

      // Verifikasi alokasi utang tidak memotong total aset, melainkan mengunci saldo siap pakai
      final balance = await accountRepo.calculateAccountBalance(accId);
      expect(
        balance,
        1500000,
      ); // Saldo siap pakai berkurang 500.000 agar tidak bisa dipakai belanja

      final summary = await accountRepo.getBalanceSummary();
      expect(
        summary.totalPhysicalNetWorth,
        2000000,
      ); // Total aset fisik TIDAK terpotong!
      expect(
        summary.allocatedInDebts,
        500000,
      ); // Dana terkunci di anggaran utang
      expect(summary.totalNetWorth, 1500000); // Saldo bebas siap pakai

      // Bayar sisa 1.000.000 -> status lunas
      await debtRepo.recordPayment(debtId, 1000000, accountId: accId);

      final settledDebts = await debtRepo.getAllDebts();
      expect(settledDebts.first.paidAmount, 1500000);
      expect(settledDebts.first.remainingAmount, 0);
      expect(settledDebts.first.isSettled, true);
    });

    testWidgets(
      'DebtScreen opens payment sheet and shows account selection chips',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              debtsListProvider('debt').overrideWith(
                (ref) async => [
                  DebtModel(
                    id: 1,
                    title: 'Tagihan Kartu',
                    personName: 'Bank Mandiri',
                    type: 'debt',
                    totalAmount: 1000000,
                    paidAmount: 200000,
                    dueDate: DateTime(2026, 11, 20),
                    createdAt: DateTime.now(),
                  ),
                ],
              ),
              accountsWithBalanceProvider.overrideWith(
                (ref) async => [
                  AccountWithBalance(
                    account: Account(
                      id: 1,
                      name: 'Mandiri',
                      type: 'bank',
                      category: 'harian',
                      colorHex: '0xFF003D79',
                      iconCodePoint: 1234,
                      initialBalance: 3000000,
                      createdAt: DateTime.now(),
                    ),
                    balance: 3000000,
                  ),
                ],
              ),
              debtOverallSummaryProvider.overrideWith(
                (ref) async => const DebtOverallSummary(
                  totalDebtRemaining: 800000,
                  totalReceivableRemaining: 0,
                  activeDebtCount: 1,
                  activeReceivableCount: 0,
                ),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'sans-serif'),
              home: const DebtScreen(),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Tagihan Kartu'), findsOneWidget);
        expect(find.text('Bayar Cicilan'), findsOneWidget);

        // Tap Bayar Cicilan
        await tester.tap(find.text('Bayar Cicilan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Sheet muncul dengan pilihan rekening Mandiri
        expect(
          find.textContaining('Sisihkan / Bayar: Tagihan Kartu'),
          findsOneWidget,
        );
        expect(find.textContaining('Mandiri (Rp 3.000.000)'), findsOneWidget);
        expect(find.text('Lunasi Semua'), findsOneWidget);

        // Tap Lunasi Semua
        await tester.tap(find.text('Lunasi Semua'));
        await tester.pump();

        // Tutup sheet
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });
}
