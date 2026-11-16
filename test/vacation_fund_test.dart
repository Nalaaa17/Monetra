import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/account.dart';
import 'package:monetra/data/models/vacation.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:monetra/data/repositories/vacation_repository.dart';
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

  test(
      'Vacation Fund: Allocating money reduces spendable balance on Home, recording vacation expense tags transactions with vacationName, and completing trip returns unspent funds',
      () async {
    final accRepo = AccountRepository();
    final vacRepo = VacationRepository();
    final txRepo = TransactionRepository();

    // 1. Setup Akun BCA (Saldo awal 5.000.000) dan Cash (Saldo awal 1.000.000)
    final bcaId = await accRepo.insertAccount(Account(
      name: 'BCA',
      type: 'bank',
      category: 'harian',
      colorHex: '0xFF005E9E',
      iconCodePoint: Icons.account_balance_rounded.codePoint,
      initialBalance: 5000000,
      createdAt: DateTime.now(),
    ));

    final cashId = await accRepo.insertAccount(Account(
      name: 'Cash',
      type: 'cash',
      category: 'harian',
      colorHex: '0xFF10B981',
      iconCodePoint: Icons.payments_rounded.codePoint,
      initialBalance: 1000000,
      createdAt: DateTime.now(),
    ));

    // Verifikasi saldo bebas awal di Home
    final initialBcaBal = await accRepo.calculateAccountBalance(bcaId);
    final initialCashBal = await accRepo.calculateAccountBalance(cashId);
    expect(initialBcaBal, 5000000);
    expect(initialCashBal, 1000000);

    // 2. User membuat Trip "Liburan ke Bali" 🌴
    // Alokasi: Ambil 2.000.000 dari BCA dan 300.000 dari Cash (Total 2.300.000)
    final vacation = VacationModel(
      name: 'Liburan ke Bali 🌴',
      destination: 'Bali',
      targetBudget: 2300000,
      status: 'active',
      startDate: DateTime.now(),
      createdAt: DateTime.now(),
    );

    final vacationId = await vacRepo.createVacation(
      vacation: vacation,
      accountAllocations: {
        bcaId: 2000000,
        cashId: 300000,
      },
    );

    // 3. Verifikasi saldo bebas di Home TERPOTONG sesuai alokasi liburan
    final afterAllocBca = await accRepo.calculateAccountBalance(bcaId);
    final afterAllocCash = await accRepo.calculateAccountBalance(cashId);
    expect(afterAllocBca, 3000000); // 5jt - 2jt disisihkan ke liburan
    expect(afterAllocCash, 700000); // 1jt - 300rb disisihkan ke liburan

    final balanceSummary = await accRepo.getBalanceSummary();
    expect(balanceSummary.allocatedInVacation, 2300000);
    expect(balanceSummary.dailySpendingBalance, 3700000); // 3jt + 700rb
    expect(balanceSummary.totalPhysicalNetWorth, 6000000); // Aset fisik tetap 6jt

    // 4. Verifikasi detail di dalam Halaman Liburan
    final vacDetail = await vacRepo.getVacationDetail(vacationId);
    expect(vacDetail, isNotNull);
    expect(vacDetail!.totalAllocated, 2300000);
    expect(vacDetail.remainingBudget, 2300000);
    expect(vacDetail.totalSpent, 0);
    expect(vacDetail.accounts.length, 2);

    // 5. Catat pengeluaran liburan: Beli Seafood Jimbaran 500.000 pakai BCA
    await vacRepo.recordVacationExpense(
      vacationId: vacationId,
      accountId: bcaId,
      amount: 500000,
      note: 'Makan Seafood Jimbaran',
      date: DateTime.now(),
    );

    // 6. Verifikasi detail liburan setelah pengeluaran
    final updatedVacDetail = await vacRepo.getVacationDetail(vacationId);
    expect(updatedVacDetail!.totalSpent, 500000);
    expect(updatedVacDetail.remainingBudget, 1800000); // 2.3jt - 500rb

    final bcaVacAccount =
        updatedVacDetail.accounts.firstWhere((a) => a.accountId == bcaId);
    expect(bcaVacAccount.allocatedAmount, 2000000);
    expect(bcaVacAccount.spentAmount, 500000);
    expect(bcaVacAccount.remainingAmount, 1500000); // Sisa BCA di liburan = 1.5jt

    // 7. Verifikasi transaksi muncul di Riwayat Transaksi dengan tanda/badge Liburan
    final detailedTxs = await txRepo.getTransactionsDetailed();
    expect(detailedTxs.length, 1);
    expect(detailedTxs.first.vacationName, 'Liburan ke Bali 🌴');
    expect(detailedTxs.first.isVacation, true);
    expect(detailedTxs.first.note, 'Makan Seafood Jimbaran');

    // 8. Selesaikan Liburan (Tutup trip dan kembalikan sisa dana)
    await vacRepo.completeVacation(vacationId);

    // Sisa alokasi BCA (1.5jt) dan Cash (300rb) otomatis dilepaskan kembali ke saldo bebas Home
    final finalBcaBal = await accRepo.calculateAccountBalance(bcaId);
    final finalCashBal = await accRepo.calculateAccountBalance(cashId);
    expect(finalBcaBal, 4500000); // 5jt - 500rb (yang benar-benar terpakai)
    expect(finalCashBal, 1000000); // 1jt (karena uang cash tidak dipakai sama sekali)

    final finalSummary = await accRepo.getBalanceSummary();
    expect(finalSummary.allocatedInVacation, 0); // Sudah tidak ada dana terkunci liburan
    expect(finalSummary.totalNetWorth, 5500000); // 4.5jt + 1jt
  });
}
