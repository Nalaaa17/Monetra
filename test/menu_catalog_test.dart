import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/account.dart';
import 'package:monetra/data/models/menu_item.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/menu_repository.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('monetra_menu_test_');
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

  group('Fase C: Menu Catalog & Quick Sale Tests', () {
    test('MenuItem menghitung laba dan margin dengan benar', () {
      final item = MenuItem(
        name: 'Kopi Susu Aren',
        type: 'fnb',
        costPrice: 10000,
        sellingPrice: 20000,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(item.profit, 10000);
      expect(item.profitMargin, 50.0);
    });

    test('MenuRepository CRUD dan recordQuickSale mencatat omzet ke transaksi', () async {
      final menuRepo = MenuRepository();
      final accRepo = AccountRepository();
      final txRepo = TransactionRepository();

      // Buat akun kasir
      final kasirAccountId = await accRepo.insertAccount(
        Account(
          name: 'Kas Usaha Toko',
          type: 'cash',
          category: 'harian',
          colorHex: '0xFF10B981',
          iconCodePoint: 0xe491,
          initialBalance: 0,
          createdAt: DateTime.now(),
        ),
      );

      // 1. Simpan Menu baru
      final createdMenu = await menuRepo.insertMenu(
        MenuItem(
          name: 'Paket Ayam Geprek',
          type: 'fnb',
          costPrice: 12000,
          sellingPrice: 25000,
          createdAt: DateTime.now(),
        ),
      );

      expect(createdMenu.id, isNotNull);

      final allMenus = await menuRepo.getAllMenus();
      expect(allMenus.length, 1);
      expect(allMenus.first.name, 'Paket Ayam Geprek');

      // 2. Catat penjualan cepat (Quick Sale 3x porsi)
      final txId = await menuRepo.recordQuickSale(
        item: createdMenu,
        quantity: 3,
        accountId: kasirAccountId,
      );

      expect(txId, isPositive);

      // Verifikasi di transaksi: total amount = 25.000 x 3 = 75.000
      final transactions = await txRepo.getRecentTransactionDetails();
      expect(transactions.length, 1);
      expect(transactions.first.amount, 75000);
      expect(transactions.first.type, 'income');
      expect(transactions.first.note, contains('Paket Ayam Geprek (3x)'));

      // Verifikasi saldo kas toko bertambah 75.000
      final balance = await accRepo.calculateAccountBalance(kasirAccountId);
      expect(balance, 75000);
    });
  });
}
