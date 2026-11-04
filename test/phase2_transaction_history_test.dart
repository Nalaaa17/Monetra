import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/transaction.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/category_repository.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:monetra/features/transaction/providers/transaction_form_provider.dart';
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

  group('Fase 2: Transaksi Inti & Form Keypad Tests', () {
    test('Keypad typing: 5 + 0 + 000 yields 50000', () async {
      final container = ProviderContainer();
      final sub = container.listen(transactionFormNotifierProvider, (_, _) {});
      final notifier =
          container.read(transactionFormNotifierProvider.notifier);

      notifier.appendKey('5');
      notifier.appendKey('0');
      notifier.appendKey('000');

      expect(container.read(transactionFormNotifierProvider).rawAmount, '50000');
      expect(container.read(transactionFormNotifierProvider).amount, 50000);

      // Test backspace: 50000 -> 5000
      notifier.backspace();
      expect(container.read(transactionFormNotifierProvider).amount, 5000);

      // Test clear: -> 0
      notifier.clearAmount();
      expect(container.read(transactionFormNotifierProvider).amount, 0);

      sub.close();
      container.dispose();
    });

    test('Submit form updates database and account balance', () async {
      final container = ProviderContainer();
      final sub = container.listen(transactionFormNotifierProvider, (_, _) {});

      final accountRepo = AccountRepository();
      final accounts = await accountRepo.getAllAccounts();
      final mandiri = accounts.firstWhere((a) => a.name == 'Mandiri');

      final notifier =
          container.read(transactionFormNotifierProvider.notifier);

      // Tunggu inisialisasi default form selesai
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. Simpan Pemasukan: Rp 1.550.000 (sesuai contoh di Notes HP pengguna)
      notifier.setType('income');
      notifier.clearAmount();
      notifier.appendKey('1');
      notifier.appendKey('5');
      notifier.appendKey('5');
      notifier.appendKey('0000'); // 1550000
      notifier.setAccount(mandiri.id!);
      notifier.setNote('Uang Di tanggal 21');

      final successIncome = await notifier.submit();
      expect(successIncome, isTrue);

      // Verifikasi saldo Mandiri
      final balanceAfterIncome =
          await accountRepo.calculateAccountBalance(mandiri.id!);
      expect(balanceAfterIncome, 1550000);

      // 2. Simpan Pengeluaran: Bensin Rp 50.000
      notifier.setType('expense');
      notifier.clearAmount();
      notifier.appendKey('5');
      notifier.appendKey('0');
      notifier.appendKey('000'); // 50000
      notifier.setAccount(mandiri.id!);
      notifier.setNote('Bensin');

      final successExpense1 = await notifier.submit();
      expect(successExpense1, isTrue);

      // 3. Simpan Pengeluaran: Bahan Masakan Rp 38.000
      notifier.clearAmount();
      notifier.appendKey('3');
      notifier.appendKey('8');
      notifier.appendKey('000'); // 38000
      notifier.setAccount(mandiri.id!);
      notifier.setNote('Bahan masakan');

      final successExpense2 = await notifier.submit();
      expect(successExpense2, isTrue);

      // Saldo akhir: 1.550.000 - 50.000 - 38.000 = 1.462.000 (Persis Notes pengguna!)
      final finalBalance =
          await accountRepo.calculateAccountBalance(mandiri.id!);
      expect(finalBalance, 1462000);

      sub.close();
      container.dispose();
    });
  });

  group('Fase 2: Riwayat Harian Ala Notes HP Tests', () {
    test('Transactions grouped by date with correct totals', () async {
      final txRepo = TransactionRepository();
      final accountRepo = AccountRepository();
      final categoryRepo = CategoryRepository();

      final accounts = await accountRepo.getAllAccounts();
      final cash = accounts.firstWhere((a) => a.name == 'Cash');
      final categories = await categoryRepo.getAllCategories();
      final bensin = categories.firstWhere((c) => c.name == 'Bensin');

      final date1 = DateTime(2026, 11, 21, 10, 0);
      final date2 = DateTime(2026, 11, 22, 14, 0);

      // Tanggal 21: Keluar Rp 50.000 & Rp 38.000 -> Total Keluar Rp 88.000
      await txRepo.insertTransaction(
        TransactionModel(
          type: 'expense',
          amount: 50000,
          accountId: cash.id!,
          categoryId: bensin.id,
          note: 'Bensin',
          date: date1,
          createdAt: date1,
        ),
      );

      await txRepo.insertTransaction(
        TransactionModel(
          type: 'expense',
          amount: 38000,
          accountId: cash.id!,
          categoryId: bensin.id,
          note: 'Bahan masakan',
          date: date1,
          createdAt: date1,
        ),
      );

      // Tanggal 22: Masuk Rp 200.000
      await txRepo.insertTransaction(
        TransactionModel(
          type: 'income',
          amount: 200000,
          accountId: cash.id!,
          note: 'Tambahan Uang',
          date: date2,
          createdAt: date2,
        ),
      );

      final groups = await txRepo.getGroupedTransactionsByDate();

      // Harus ada 2 grup tanggal (Tanggal 22 & Tanggal 21)
      expect(groups.length, greaterThanOrEqualTo(2));

      // Grup terbaru (Tanggal 22)
      final group22 = groups.firstWhere((g) => g.date.day == 22);
      expect(group22.totalIncome, 200000);
      expect(group22.totalExpense, 0);

      // Grup Tanggal 21
      final group21 = groups.firstWhere((g) => g.date.day == 21);
      expect(group21.totalExpense, 88000);
      expect(group21.items.length, 2);

      // Test Edit Transaksi: Ubah Bensin dari 50.000 jadi 60.000
      final bensinTx =
          group21.items.firstWhere((it) => it.note == 'Bensin');
      final updatedTx =
          bensinTx.transaction.copyWith(amount: 60000);
      await txRepo.updateTransaction(updatedTx);

      final groupsAfterEdit = await txRepo.getGroupedTransactionsByDate();
      final group21AfterEdit =
          groupsAfterEdit.firstWhere((g) => g.date.day == 21);
      expect(group21AfterEdit.totalExpense, 98000); // 60.000 + 38.000

      // Test Hapus Transaksi: Hapus Bahan masakan (38.000)
      final masakanTx =
          group21AfterEdit.items.firstWhere((it) => it.note == 'Bahan masakan');
      await txRepo.deleteTransaction(masakanTx.id);

      final groupsAfterDelete = await txRepo.getGroupedTransactionsByDate();
      final group21AfterDelete =
          groupsAfterDelete.firstWhere((g) => g.date.day == 21);
      expect(group21AfterDelete.totalExpense, 60000);
      expect(group21AfterDelete.items.length, 1);
    });
  });
}
