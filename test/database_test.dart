import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/transaction.dart';
import 'package:monetra/data/models/transfer.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/category_repository.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:monetra/data/repositories/transfer_repository.dart';
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

  test('Fase 1: Database Seed Data & Saldo Calculation Logic Test', () async {
    final accountRepo = AccountRepository();
    final categoryRepo = CategoryRepository();
    final transactionRepo = TransactionRepository();
    final transferRepo = TransferRepository();

    // 1. Cek Akun Default (Seabank, Mandiri, Cash)
    final accounts = await accountRepo.getAllAccounts();
    expect(accounts.length, 3);
    final accountNames = accounts.map((a) => a.name).toList();
    expect(accountNames, containsAll(['Seabank', 'Mandiri', 'Cash']));

    // 2. Cek Kategori Default
    final categories = await categoryRepo.getAllCategories();
    expect(categories.length, greaterThanOrEqualTo(8));
    final catNames = categories.map((c) => c.name).toList();
    expect(catNames, contains('Bensin'));
    expect(catNames, contains('Makan'));
    expect(catNames, contains('Gaji'));

    final mandiri = accounts.firstWhere((a) => a.name == 'Mandiri');
    final cash = accounts.firstWhere((a) => a.name == 'Cash');
    final seabank = accounts.firstWhere((a) => a.name == 'Seabank');

    // 3. Tambah Pemasukan ke Mandiri: Rp 2.000.000
    await transactionRepo.insertTransaction(
      TransactionModel(
        type: 'income',
        amount: 2000000,
        accountId: mandiri.id!,
        note: 'Gaji Bulanan',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );

    // Saldo Mandiri harus 2.000.000
    expect(await accountRepo.calculateAccountBalance(mandiri.id!), 2000000);

    // 4. Tambah Pengeluaran dari Mandiri: Rp 300.000
    await transactionRepo.insertTransaction(
      TransactionModel(
        type: 'expense',
        amount: 300000,
        accountId: mandiri.id!,
        note: 'Bayar Cicilan',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );

    // Saldo Mandiri harus 1.700.000
    expect(await accountRepo.calculateAccountBalance(mandiri.id!), 1700000);

    // 5. Transfer dari Mandiri ke Cash: Rp 200.000 (Tarik Tunai)
    await transferRepo.insertTransfer(
      TransferModel(
        fromAccountId: mandiri.id!,
        toAccountId: cash.id!,
        amount: 200000,
        note: 'Tarik Tunai ATM',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );

    // Saldo Mandiri: 1.500.000
    // Saldo Cash: 200.000
    expect(await accountRepo.calculateAccountBalance(mandiri.id!), 1500000);
    expect(await accountRepo.calculateAccountBalance(cash.id!), 200000);

    // 6. Transfer dari Mandiri ke Seabank: Rp 500.000 (Nabung)
    await transferRepo.insertTransfer(
      TransferModel(
        fromAccountId: mandiri.id!,
        toAccountId: seabank.id!,
        amount: 500000,
        note: 'Simpan ke tabungan',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );

    // Saldo Mandiri: 1.000.000
    // Saldo Seabank: 500.000
    expect(await accountRepo.calculateAccountBalance(mandiri.id!), 1000000);
    expect(await accountRepo.calculateAccountBalance(seabank.id!), 500000);

    // 7. Cek Agregasi PRD §5.3
    // Uang Harian = Mandiri (1.000.000) + Cash (200.000) = 1.200.000
    // Tabungan = Seabank (500.000)
    // Total Kekayaan = 1.700.000
    final summary = await accountRepo.getBalanceSummary();
    expect(summary.dailySpendingBalance, 1200000);
    expect(summary.savingsBalance, 500000);
    expect(summary.totalNetWorth, 1700000);
  });
}
