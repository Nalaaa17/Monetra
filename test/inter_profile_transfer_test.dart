import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/account.dart';
import 'package:monetra/data/models/profile_model.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:monetra/data/repositories/transfer_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('monetra_bridge_test_');
    AppDatabase.testDbPath = p.join(tempDir.path, 'monetra.db');
    AppDatabase.testMetaDbPath = p.join(tempDir.path, 'monetra_meta.db');
    await AppDatabase.close();
  });

  tearDown(() async {
    await AppDatabase.close();
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
    AppDatabase.testDbPath = null;
    AppDatabase.testMetaDbPath = null;
  });

  group('Jembatan Transfer Antar Profil (Pribadi <-> Bisnis)', () {
    test('Prive: Penarikan gaji owner dari Bisnis ke Pribadi tercatat di kedua pembukuan', () async {
      final transferRepo = TransferRepository();
      final accRepo = AccountRepository();
      final txRepo = TransactionRepository();

      // 1. Profil Default (Pribadi) - buat akun BCA Tabungan
      final bcaPribadiId = await accRepo.insertAccount(
        Account(
          name: 'BCA Pribadi',
          type: 'bank',
          category: 'tabungan',
          colorHex: '0xFF00529C',
          iconCodePoint: 0xe491,
          initialBalance: 500000,
          createdAt: DateTime.now(),
        ),
      );

      // 2. Buat Profil Bisnis 'toko_kopi'
      const businessKey = 'toko_kopi';
      await AppDatabase.createProfile(
        ProfileModel(
          key: businessKey,
          name: 'Toko Kopi Senja',
          type: 'business',
          iconCodePoint: 0xe5e1,
          colorHex: '0xFF3B82F6',
          createdAt: DateTime.now(),
        ),
      );

      // Buka profil bisnis dan tambahkan saldo awal di Kas Usaha
      await AppDatabase.switchProfile(businessKey);
      final businessAccounts = await accRepo.getAllAccounts();
      final kasUsaha = businessAccounts.firstWhere((a) => a.name == 'Kas Usaha');

      // Set saldo awal kas usaha = 5.000.000
      await accRepo.updateAccount(kasUsaha.copyWith(initialBalance: 5000000));
      final initialKas = await accRepo.calculateAccountBalance(kasUsaha.id!);
      expect(initialKas, 5000000);

      // 3. Eksekusi Jembatan Transfer: Bisnis (Kas Usaha) -> Pribadi (BCA Pribadi) Rp 2.000.000 (Prive)
      await transferRepo.executeInterProfileTransfer(
        fromProfileKey: businessKey,
        fromProfileName: 'Toko Kopi Senja',
        isFromBusiness: true,
        fromAccountId: kasUsaha.id!,
        fromAccountName: 'Kas Usaha',
        toProfileKey: AppDatabase.defaultProfileKey,
        toProfileName: 'Pribadi',
        isToBusiness: false,
        toAccountId: bcaPribadiId,
        toAccountName: 'BCA Pribadi',
        amount: 2000000,
        note: 'Gaji Owner Bulan November',
      );

      // 4. Verifikasi di sisi Bisnis:
      // Saldo kas usaha berkurang dari 5.000.000 menjadi 3.000.000
      final updatedKas = await accRepo.calculateAccountBalance(kasUsaha.id!);
      expect(updatedKas, 3000000);

      final businessTxs = await txRepo.getRecentTransactionDetails();
      expect(businessTxs.any((t) => t.type == 'expense' && t.amount == 2000000), isTrue);

      // 5. Verifikasi di sisi Pribadi:
      await AppDatabase.switchProfile(AppDatabase.defaultProfileKey);
      // Saldo BCA bertambah dari 500.000 menjadi 2.500.000
      final updatedBca = await accRepo.calculateAccountBalance(bcaPribadiId);
      expect(updatedBca, 2500000);

      final personalTxs = await txRepo.getRecentTransactionDetails();
      expect(personalTxs.any((t) => t.type == 'income' && t.amount == 2000000), isTrue);
    });

    test('Suntik Modal: Setor modal pribadi ke rekening usaha', () async {
      final transferRepo = TransferRepository();
      final accRepo = AccountRepository();

      // Profil Pribadi - akun Mandiri saldo 3.000.000
      final mandiriPribadiId = await accRepo.insertAccount(
        Account(
          name: 'Mandiri Pribadi',
          type: 'bank',
          category: 'harian',
          colorHex: '0xFFF59E0B',
          iconCodePoint: 0xe491,
          initialBalance: 3000000,
          createdAt: DateTime.now(),
        ),
      );

      // Buat profil bisnis 'bengkel'
      const bengkelKey = 'bengkel_motor';
      await AppDatabase.createProfile(
        ProfileModel(
          key: bengkelKey,
          name: 'Bengkel Motor',
          type: 'business',
          iconCodePoint: 0xe5e1,
          colorHex: '0xFFEF4444',
          createdAt: DateTime.now(),
        ),
      );

      await AppDatabase.switchProfile(bengkelKey);
      final bengkelAccounts = await accRepo.getAllAccounts();
      final kasBengkel = bengkelAccounts.firstWhere((a) => a.name == 'Kas Usaha');

      // Suntik modal 1.000.000 dari Mandiri Pribadi ke Kas Bengkel
      await transferRepo.executeInterProfileTransfer(
        fromProfileKey: AppDatabase.defaultProfileKey,
        fromProfileName: 'Pribadi',
        isFromBusiness: false,
        fromAccountId: mandiriPribadiId,
        fromAccountName: 'Mandiri Pribadi',
        toProfileKey: bengkelKey,
        toProfileName: 'Bengkel Motor',
        isToBusiness: true,
        toAccountId: kasBengkel.id!,
        toAccountName: 'Kas Usaha',
        amount: 1000000,
      );

      // Saldo kas bengkel bertambah 1.000.000
      final bengkelBalance = await accRepo.calculateAccountBalance(kasBengkel.id!);
      expect(bengkelBalance, 1000000);

      // Saldo Mandiri pribadi berkurang 1.000.000 (menjadi 2.000.000)
      await AppDatabase.switchProfile(AppDatabase.defaultProfileKey);
      final mandiriBalance = await accRepo.calculateAccountBalance(mandiriPribadiId);
      expect(mandiriBalance, 2000000);

      // Verifikasi getAccountsWithBalancesForProfile membaca saldo tanpa switch aktif
      final bengkelAccs = await accRepo.getAccountsWithBalancesForProfile(bengkelKey);
      final kasFromMethod = bengkelAccs.firstWhere((a) => a.id == kasBengkel.id);
      expect(kasFromMethod.balance, 1000000);

      final pribadiAccs = await accRepo.getAccountsWithBalancesForProfile(AppDatabase.defaultProfileKey);
      final mandiriFromMethod = pribadiAccs.firstWhere((a) => a.id == mandiriPribadiId);
      expect(mandiriFromMethod.balance, 2000000);
    });
  });
}
