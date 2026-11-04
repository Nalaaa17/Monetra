import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/core/theme/theme_provider.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/account.dart';
import 'package:monetra/data/models/category.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/category_repository.dart';
import 'package:monetra/shared/widgets/animated_currency.dart';
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

  group('Fase 6: Polish, Animasi & Dark Mode Tests', () {
    testWidgets('AnimatedCurrency renders and animates number changes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedCurrency(
              amount: 1500000,
              style: TextStyle(fontSize: 24),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Rp 1.500.000'), findsOneWidget);
    });

    test('ThemeMode provider toggles between light and dark', () {
      final container = ProviderContainer();

      expect(container.read(themeModeProvider), ThemeMode.light);

      container.read(themeModeProvider.notifier).state = ThemeMode.dark;
      expect(container.read(themeModeProvider), ThemeMode.dark);

      container.read(themeModeProvider.notifier).state = ThemeMode.light;
      expect(container.read(themeModeProvider), ThemeMode.light);

      container.dispose();
    });

    test('Custom Accounts & Custom Categories management tests', () async {
      final accountRepo = AccountRepository();
      final categoryRepo = CategoryRepository();

      // 1. Tambah Akun Baru Kustom: BCA (Saldo Awal Rp 500.000)
      final newAccId = await accountRepo.insertAccount(
        Account(
          name: 'BCA',
          type: 'bank',
          colorHex: '0xFF0284C7',
          iconCodePoint: Icons.account_balance_rounded.codePoint,
          initialBalance: 500000,
          createdAt: DateTime.now(),
        ),
      );
      expect(newAccId, greaterThan(0));

      final accounts = await accountRepo.getAllAccounts();
      final bca = accounts.firstWhere((a) => a.name == 'BCA');
      expect(bca.initialBalance, 500000);

      // Verifikasi saldo BCA
      final bcaBalance =
          await accountRepo.calculateAccountBalance(bca.id!);
      expect(bcaBalance, 500000);

      // 2. Tambah Kategori Kustom: Kopi
      final newCatId = await categoryRepo.insertCategory(
        Category(
          name: 'Kopi',
          iconCodePoint: Icons.local_cafe_rounded.codePoint,
          colorHex: '0xFFF59E0B',
          type: 'expense',
          isActive: true,
        ),
      );
      expect(newCatId, greaterThan(0));

      final categories = await categoryRepo.getAllCategories();
      final kopi = categories.firstWhere((c) => c.name == 'Kopi');
      expect(kopi.name, 'Kopi');
      expect(kopi.type, 'expense');

      // 3. Test toggle aktif/nonaktif kategori
      await categoryRepo.toggleActive(kopi.id!, false);
      final activeCategories =
          await categoryRepo.getAllCategories(onlyActive: true);
      expect(activeCategories.any((c) => c.name == 'Kopi'), isFalse);
    });
  });
}

