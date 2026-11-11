import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monetra/core/constants/bank_brands.dart';
import 'package:monetra/core/theme/theme_provider.dart';
import 'package:monetra/core/utils/bank_logo_helper.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/account.dart';
import 'package:monetra/data/models/category.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/category_repository.dart';
import 'package:monetra/features/accounts/screens/manage_accounts_screen.dart';
import 'package:monetra/features/home/providers/home_providers.dart';
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

      // 4. Test ubah kelompok dana akun (Uang Harian <-> Tabungan)
      expect(bca.category, 'harian');
      await accountRepo.updateAccountCategory(bca.id!, 'tabungan');
      final updatedBca = (await accountRepo.getAllAccounts()).firstWhere((a) => a.id == bca.id);
      expect(updatedBca.category, 'tabungan');

      final summary = await accountRepo.getBalanceSummary();
      expect(summary.savingsAccountNames.contains('BCA'), isTrue);

      // 5. Test hapus akun (Delete account)
      final deletedRows = await accountRepo.deleteAccount(bca.id!);
      expect(deletedRows, 1);
      final accountsAfterDelete = await accountRepo.getAllAccounts();
      expect(accountsAfterDelete.any((a) => a.id == bca.id), isFalse);
    });

    test('Complete BankBrands registry resolves banks, e-wallets & custom logoKey', () async {
      expect(BankBrands.all.length, greaterThanOrEqualTo(190));

      // Bank Nasional & Syariah
      expect(BankBrands.resolve(accountName: 'BCA')?.key, 'bca');
      expect(BankBrands.resolve(accountName: 'Bank Mandiri')?.key, 'mandiri');
      expect(BankBrands.resolve(accountName: 'BRI')?.key, 'bri');
      expect(BankBrands.resolve(accountName: 'BNI Gaji')?.key, 'bni');
      expect(BankBrands.resolve(accountName: 'BSI')?.key, 'bsi');
      expect(BankBrands.resolve(accountName: 'BTN')?.key, 'btn');
      expect(BankBrands.resolve(accountName: 'CIMB Niaga')?.key, 'cimb-niaga');
      expect(BankBrands.resolve(accountName: 'PermataBank')?.key, 'permata');
      expect(BankBrands.resolve(accountName: 'OCBC NISP')?.key, 'ocbc-nisp');
      expect(BankBrands.resolve(accountName: 'Bank Danamon')?.key, 'danamon');

      // Bank Digital & Daerah
      expect(BankBrands.resolve(accountName: 'SeaBank')?.key, 'seabank');
      expect(BankBrands.resolve(accountName: 'Bank Jago')?.key, 'jago');
      expect(BankBrands.resolve(accountName: 'blu BCA')?.key, 'blu-bca');
      expect(BankBrands.resolve(accountName: 'Jenius')?.key, 'jenius');
      expect(BankBrands.resolve(accountName: 'Neobank BNC')?.key, 'neobank');
      expect(BankBrands.resolve(accountName: 'Allo Bank')?.key, 'allo');
      expect(BankBrands.resolve(accountName: 'Superbank')?.key, 'superbank');
      expect(BankBrands.resolve(accountName: 'Bank Saqu')?.key, 'bank-saqu');
      expect(BankBrands.resolve(accountName: 'Krom Bank')?.key, 'krom');
      expect(BankBrands.resolve(accountName: 'Bank Jateng')?.key, 'bank-bpd-jateng');
      expect(BankBrands.resolve(accountName: 'Bank Jatim')?.key, 'bank-bpd-jatim');
      expect(BankBrands.resolve(accountName: 'Bank BJB')?.key, 'bank-bjb');

      // E-Wallet & Cash
      expect(BankBrands.resolve(accountName: 'GoPay')?.key, 'gopay');
      expect(BankBrands.resolve(accountName: 'DANA')?.key, 'dana');
      expect(BankBrands.resolve(accountName: 'OVO')?.key, 'ovo');
      expect(BankBrands.resolve(accountName: 'ShopeePay')?.key, 'shopee-pay');
      expect(BankBrands.resolve(accountName: 'LinkAja')?.key, 'linkaja');
      expect(BankBrands.resolve(accountName: 'AstraPay')?.key, 'astra-pay');
      expect(BankBrands.resolve(accountName: 'i.saku')?.key, 'i-saku');
      expect(BankBrands.resolve(accountName: 'Cash / Tunai')?.key, 'cash');

      // Guard kata pendek agar tidak salah cocok (misal 'pribadi' != 'bri', 'obrol' != 'ovo')
      expect(BankBrands.resolve(accountName: 'Tabungan Pribadi'), isNull);
      expect(BankBrands.resolve(accountName: 'Dompet Obrol'), isNull);

      // Override logoKey untuk nama akun kustom & persistensi database
      expect(
        BankBrands.resolve(accountName: 'Tabungan Nikah', logoKey: 'jago')?.key,
        'jago',
      );

      final accountRepo = AccountRepository();
      final customId = await accountRepo.insertAccount(
        Account(
          name: 'Tabungan Nikah',
          type: 'bank',
          colorHex: '0xFFFDB913',
          iconCodePoint: Icons.account_balance_rounded.codePoint,
          initialBalance: 250000,
          logoKey: 'jago',
          createdAt: DateTime.now(),
        ),
      );
      final saved = (await accountRepo.getAllAccounts()).firstWhere((a) => a.id == customId);
      expect(saved.logoKey, 'jago');
    });

    testWidgets('BankLogoHelper renders SVG brand logo, PNG cash, and monogram fallback',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Row(
                children: [
                  BankLogoHelper.buildAccountBadge(
                    context: context,
                    accountName: 'BNI',
                    accountColor: const Color(0xFFF15A23),
                  ),
                  BankLogoHelper.buildAccountBadge(
                    context: context,
                    accountName: 'Cash',
                    accountColor: const Color(0xFF10B981),
                  ),
                  BankLogoHelper.buildAccountBadge(
                    context: context,
                    accountName: 'Arisan Keluarga',
                    accountColor: const Color(0xFF8B5CF6),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      // Custom non-brand wallet always renders an unmistakable monogram logo badge
      expect(find.text('AK'), findsOneWidget);
    });

    testWidgets(
        'ManageAccountsScreen Add Account modal shows Indonesian banks/e-wallets without color picker',
        (WidgetTester tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final dummyAccount = AccountWithBalance(
        account: Account(
          id: 1,
          name: 'Mandiri',
          type: 'bank',
          category: 'harian',
          colorHex: '0xFF003D79',
          iconCodePoint: Icons.account_balance_rounded.codePoint,
          initialBalance: 500000,
          createdAt: DateTime.now(),
        ),
        balance: 500000,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountsWithBalanceProvider
                .overrideWith((ref) async => [dummyAccount]),
          ],
          child: const MaterialApp(
            home: ManageAccountsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final addBtn = find.text('Tambah Dompet / Rekening Baru');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Pastikan pemilih Bank / E-Wallet Indonesia ada dan pemilih warna TIDAK ada
      expect(find.text('Pilih Bank / E-Wallet Indonesia'), findsOneWidget);
      expect(find.text('Cari Bank atau E-Wallet Indonesia...'), findsOneWidget);
      expect(find.text('Warna Aksen'), findsNothing);
      expect(find.text('Pilih Warna:'), findsNothing);

      // Ketik 'bni' pada field nama untuk memunculkan saran bank Indonesia
      final nameField = find.byType(TextFormField).first;
      await tester.enterText(nameField, 'bni');
      await tester.pump();
      expect(find.widgetWithText(ActionChip, 'BNI'), findsOneWidget);

      // Buka daftar lengkap Bank & E-Wallet Indonesia
      await tester.tap(find.textContaining('bank nasional, digital, BPD'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Pilih Bank & E-Wallet Indonesia'), findsOneWidget);
      expect(find.text('Bank Nasional'), findsOneWidget);
      expect(find.text('E-Wallet'), findsOneWidget);
    });
  });
}

