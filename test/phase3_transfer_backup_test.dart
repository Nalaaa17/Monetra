import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/transaction.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:monetra/data/repositories/transfer_repository.dart';
import 'package:monetra/data/services/backup_service.dart';
import 'package:monetra/features/transaction/providers/transfer_form_provider.dart';
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

  group('Fase 3: Transfer Antar Akun Tests', () {
    test('Transfer moves money between wallets without altering total net worth',
        () async {
      final container = ProviderContainer();
      final sub = container.listen(transferFormNotifierProvider, (_, _) {});

      final accountRepo = AccountRepository();
      final txRepo = TransactionRepository();
      final transferRepo = TransferRepository();

      final accounts = await accountRepo.getAllAccounts();
      final mandiri = accounts.firstWhere((a) => a.name == 'Mandiri');
      final cash = accounts.firstWhere((a) => a.name == 'Cash');
      final seabank = accounts.firstWhere((a) => a.name == 'Seabank');

      // 1. Berikan saldo awal ke Mandiri Rp 1.000.000
      await txRepo.insertTransaction(
        TransactionModel(
          type: 'income',
          amount: 1000000,
          accountId: mandiri.id!,
          note: 'Saldo Awal',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      );

      final initialSummary = await accountRepo.getBalanceSummary();
      expect(initialSummary.totalNetWorth, 1000000);
      expect(await accountRepo.calculateAccountBalance(mandiri.id!), 1000000);
      expect(await accountRepo.calculateAccountBalance(cash.id!), 0);

      // 2. Eksekusi Transfer: Tarik Tunai Mandiri -> Cash Rp 300.000 via TransferFormNotifier
      await Future.delayed(const Duration(milliseconds: 50));
      final notifier =
          container.read(transferFormNotifierProvider.notifier);

      notifier.setFromAccount(mandiri.id!);
      notifier.setToAccount(cash.id!);
      notifier.clearAmount();
      notifier.appendKey('3');
      notifier.appendKey('0');
      notifier.appendKey('0');
      notifier.appendKey('000'); // 300000
      notifier.setNote('Tarik Tunai ATM');

      final success = await notifier.submit();
      expect(success, isTrue);

      // 3. Verifikasi Saldo
      // Mandiri: 1.000.000 - 300.000 = 700.000
      // Cash: 0 + 300.000 = 300.000
      // Total Tetap: 1.000.000
      expect(await accountRepo.calculateAccountBalance(mandiri.id!), 700000);
      expect(await accountRepo.calculateAccountBalance(cash.id!), 300000);

      final summaryAfterTransfer = await accountRepo.getBalanceSummary();
      expect(summaryAfterTransfer.totalNetWorth, 1000000);
      expect(summaryAfterTransfer.dailySpendingBalance, 1000000); // Mandiri + Cash

      // 4. Transfer Mandiri -> Seabank Rp 500.000 (Nabung)
      notifier.setFromAccount(mandiri.id!);
      notifier.setToAccount(seabank.id!);
      notifier.clearAmount();
      notifier.appendKey('5');
      notifier.appendKey('0');
      notifier.appendKey('0');
      notifier.appendKey('000'); // 500000
      notifier.setNote('Simpan ke Seabank');

      final success2 = await notifier.submit();
      expect(success2, isTrue);

      // Mandiri: 200.000
      // Cash: 300.000
      // Seabank: 500.000
      // Uang Harian: Mandiri + Cash = 500.000
      // Tabungan: Seabank = 500.000
      // Total: 1.000.000
      final summaryFinal = await accountRepo.getBalanceSummary();
      expect(summaryFinal.dailySpendingBalance, 500000);
      expect(summaryFinal.savingsBalance, 500000);
      expect(summaryFinal.totalNetWorth, 1000000);

      // 5. Verifikasi Transfer Muncul di Riwayat Harian
      final groups = await txRepo.getGroupedTransactionsByDate();
      expect(groups.isNotEmpty, isTrue);
      expect(groups.first.transfers.length, 2);

      // 6. Test Delete Transfer (Hapus transfer nabung 500.000)
      final transfers = await transferRepo.getAllTransfers();
      final nabungTr =
          transfers.firstWhere((t) => t.amount == 500000);
      await transferRepo.deleteTransfer(nabungTr.id);

      // Saldo Mandiri harus kembali jadi 700.000
      expect(await accountRepo.calculateAccountBalance(mandiri.id!), 700000);
      expect(await accountRepo.calculateAccountBalance(seabank.id!), 0);

      sub.close();
      container.dispose();
    });
  });

  group('Fase 3: Auto-Backup & Restore JSON Tests', () {
    test('Export to JSON and Restore 100% recovers all data', () async {
      final accountRepo = AccountRepository();
      final txRepo = TransactionRepository();
      final accounts = await accountRepo.getAllAccounts();
      final cash = accounts.firstWhere((a) => a.name == 'Cash');

      // 1. Buat transaksi unik untuk ditest
      await txRepo.insertTransaction(
        TransactionModel(
          type: 'expense',
          amount: 75000,
          accountId: cash.id!,
          note: 'Catatan Backup Spesifik',
          date: DateTime(2026, 11, 25),
          createdAt: DateTime.now(),
        ),
      );

      // 2. Ekspor ke JSON String
      final jsonBackup = await BackupService.exportToJsonString();
      expect(jsonBackup, contains('Monetra'));
      expect(jsonBackup, contains('Catatan Backup Spesifik'));
      expect(jsonBackup, contains('75000'));

      // 3. Simulasikan data terhapus / reset
      final db = await AppDatabase.instance;
      await db.delete('transactions');
      final txAfterDelete = await txRepo.getAllTransactionDetails();
      expect(txAfterDelete.isEmpty, isTrue);

      // 4. Pulihkan data dari JSON String
      final restoreSuccess =
          await BackupService.restoreFromJsonString(jsonBackup);
      expect(restoreSuccess, isTrue);

      // 5. Verifikasi data berhasil kembali
      final txAfterRestore = await txRepo.getAllTransactionDetails();
      expect(txAfterRestore.length, 1);
      expect(txAfterRestore.first.note, 'Catatan Backup Spesifik');
      expect(txAfterRestore.first.amount, 75000);
    });
  });
}

