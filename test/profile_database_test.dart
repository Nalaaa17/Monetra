import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/profile_model.dart';
import 'package:monetra/data/models/transaction.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/category_repository.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:monetra/data/services/backup_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('monetra_profile_test_');
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

  group('Fase A: Multi-Profile & Dynamic Database Infrastructure Tests', () {
    test('Inisialisasi awal menghasilkan profil default Pribadi', () async {
      final profiles = await AppDatabase.getAllProfiles();
      expect(profiles.length, 1);
      expect(profiles.first.key, AppDatabase.defaultProfileKey);
      expect(profiles.first.name, 'Pribadi');
      expect(profiles.first.isPersonal, isTrue);

      final activeKey = await AppDatabase.getActiveProfileKey();
      expect(activeKey, AppDatabase.defaultProfileKey);

      // Verifikasi tabel bawaan di profil Pribadi
      final accRepo = AccountRepository();
      final accounts = await accRepo.getAllAccounts();
      expect(accounts.isNotEmpty, isTrue);
      expect(accounts.any((a) => a.name == 'Cash' || a.name == 'Mandiri'), isTrue);
    });

    test('Routing pengaturan global vs profil berfungsi sempurna', () async {
      // 1. Setting global (theme_mode) disimpan di meta DB
      await AppDatabase.setSetting('theme_mode', 'dark');
      final savedGlobal = await AppDatabase.getSetting('theme_mode');
      expect(savedGlobal, 'dark');

      // 2. Setting profil (overall_monthly_budget) disimpan di DB profil aktif
      await AppDatabase.setSetting('overall_monthly_budget', '5000000');
      final savedBudget = await AppDatabase.getSetting('overall_monthly_budget');
      expect(savedBudget, '5000000');

      // Verifikasi di meta DB langsung bahwa overall_monthly_budget TIDAK ada di meta
      final metaDb = await AppDatabase.metaInstance;
      final metaRows = await metaDb.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['overall_monthly_budget'],
      );
      expect(metaRows.isEmpty, isTrue);

      // Dan theme_mode ADA di meta DB
      final metaTheme = await metaDb.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['theme_mode'],
      );
      expect(metaTheme.isNotEmpty, isTrue);
      expect(metaTheme.first['value'], 'dark');
    });

    test('Membuat profil Bisnis baru dan switchProfile mengisolasi data 100%', () async {
      final accRepo = AccountRepository();
      final txRepo = TransactionRepository();
      final catRepo = CategoryRepository();

      // Di profil Pribadi, ambil akun cash
      final personalAccounts = await accRepo.getAllAccounts();
      final personalCash = personalAccounts.firstWhere((a) => a.type == 'cash');

      // Catat transaksi di profil Pribadi
      await txRepo.insertTransaction(
        TransactionModel(
          type: 'expense',
          amount: 50000,
          accountId: personalCash.id!,
          date: DateTime.now(),
          createdAt: DateTime.now(),
          note: 'Makan siang pribadi',
        ),
      );

      final personalTxs = await txRepo.getRecentTransactionDetails();
      expect(personalTxs.length, 1);
      expect(personalTxs.first.note, 'Makan siang pribadi');

      // 1. Buat profil Bisnis
      const businessKey = 'toko_kopi';
      await AppDatabase.createProfile(
        ProfileModel(
          key: businessKey,
          name: 'Toko Kopi Senja',
          type: 'business',
          iconCodePoint: 0xe5e1, // Icons.storefront
          colorHex: '0xFF3B82F6',
          createdAt: DateTime.now(),
        ),
      );

      final allProfiles = await AppDatabase.getAllProfiles();
      expect(allProfiles.length, 2);
      expect(allProfiles.any((p) => p.key == businessKey && p.isBusiness), isTrue);

      // 2. Switch ke profil Bisnis
      await AppDatabase.switchProfile(businessKey);
      final activeKey = await AppDatabase.getActiveProfileKey();
      expect(activeKey, businessKey);

      // 3. Verifikasi seed data profil Bisnis
      final businessAccounts = await accRepo.getAllAccounts();
      expect(businessAccounts.any((a) => a.name == 'Kas Usaha'), isTrue);
      expect(businessAccounts.any((a) => a.name == 'Rekening Bisnis'), isTrue);
      expect(businessAccounts.any((a) => a.name == 'QRIS / Toko'), isTrue);

      final businessCategories = await catRepo.getAllCategories();
      expect(businessCategories.any((c) => c.name == 'Penjualan / Omzet'), isTrue);
      expect(businessCategories.any((c) => c.name == 'Bahan Baku / Kulakan'), isTrue);

      // 4. Verifikasi ISOLASI DATA: Transaksi pribadi TIDAK ADA di profil bisnis!
      final businessTxs = await txRepo.getRecentTransactionDetails();
      expect(businessTxs.isEmpty, isTrue);

      // Catat transaksi penjualan di profil Bisnis
      final kasUsaha = businessAccounts.firstWhere((a) => a.name == 'Kas Usaha');
      final catPenjualan = businessCategories.firstWhere((c) => c.name == 'Penjualan / Omzet');

      await txRepo.insertTransaction(
        TransactionModel(
          type: 'income',
          amount: 250000,
          accountId: kasUsaha.id!,
          categoryId: catPenjualan.id,
          date: DateTime.now(),
          createdAt: DateTime.now(),
          note: 'Omzet 10 cup kopi',
        ),
      );

      final newBusinessTxs = await txRepo.getRecentTransactionDetails();
      expect(newBusinessTxs.length, 1);
      expect(newBusinessTxs.first.note, 'Omzet 10 cup kopi');

      // 5. Switch kembali ke profil Pribadi
      await AppDatabase.switchProfile(AppDatabase.defaultProfileKey);
      final returnedKey = await AppDatabase.getActiveProfileKey();
      expect(returnedKey, AppDatabase.defaultProfileKey);

      // Verifikasi transaksi pribadi tetap 1 (tidak terpengaruh omzet toko kopi)
      final returnedPersonalTxs = await txRepo.getRecentTransactionDetails();
      expect(returnedPersonalTxs.length, 1);
      expect(returnedPersonalTxs.first.note, 'Makan siang pribadi');
    });

    test('Backup & Restore Multi-Profil berfungsi utuh', () async {
      // Buat profil bisnis kedua
      const cafeKey = 'cafe_test';
      await AppDatabase.createProfile(
        ProfileModel(
          key: cafeKey,
          name: 'Cafe Test',
          type: 'business',
          iconCodePoint: 0xe5e1,
          colorHex: '0xFFF59E0B',
          createdAt: DateTime.now(),
        ),
      );

      // Switch ke cafe_test dan inisialisasi DB-nya
      await AppDatabase.switchProfile(cafeKey);
      await AppDatabase.switchProfile(AppDatabase.defaultProfileKey);

      // Export JSON dump gabungan
      final jsonBackup = await BackupService.exportToJsonString();
      expect(jsonBackup.contains('profilesData'), isTrue);
      expect(jsonBackup.contains('Cafe Test'), isTrue);
      expect(jsonBackup.contains('Pribadi'), isTrue);

      // Hapus profil cafe_test
      await AppDatabase.deleteProfile(cafeKey);
      final profilesAfterDelete = await AppDatabase.getAllProfiles();
      expect(profilesAfterDelete.any((p) => p.key == cafeKey), isFalse);

      // Pulihkan dari JSON backup
      final restoreSuccess = await BackupService.restoreFromJsonString(jsonBackup);
      expect(restoreSuccess, isTrue);

      // Verifikasi cafe_test pulih kembali
      final restoredProfiles = await AppDatabase.getAllProfiles();
      expect(restoredProfiles.any((p) => p.key == cafeKey), isTrue);
    });

    test('Restore format legacy (v2) otomatis masuk ke profil Pribadi', () async {
      final legacyJson = '''
      {
        "app": "Monetra",
        "version": 2,
        "exportedAt": "2026-11-10T12:00:00.000",
        "data": {
          "accounts": [
            {
              "id": 1,
              "name": "BCA Warisan",
              "type": "bank",
              "category": "tabungan",
              "colorHex": "0xFF00529C",
              "iconCodePoint": 58356,
              "initialBalance": 10000000,
              "isArchived": 0,
              "createdAt": "2026-11-10T12:00:00.000"
            }
          ],
          "categories": [],
          "transactions": [],
          "transfers": [],
          "goals": [],
          "goal_contributions": [],
          "recurring_transactions": []
        }
      }
      ''';

      final success = await BackupService.restoreFromJsonString(legacyJson);
      expect(success, isTrue);

      final accRepo = AccountRepository();
      final accounts = await accRepo.getAllAccounts();
      expect(accounts.any((a) => a.name == 'BCA Warisan'), isTrue);
    });
  });
}
