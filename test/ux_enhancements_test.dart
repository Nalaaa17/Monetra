import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monetra/core/constants/app_colors.dart';
import 'package:monetra/core/theme/app_theme.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/account.dart';
import 'package:monetra/data/models/transaction.dart';
import 'package:monetra/data/models/transfer.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/category_repository.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:monetra/data/repositories/transfer_repository.dart';
import 'package:monetra/features/history/screens/history_screen.dart';
import 'package:monetra/features/home/providers/home_providers.dart';
import 'package:monetra/features/transaction/widgets/account_chips_selector.dart';
import 'package:monetra/shared/providers/repository_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _InMemoryTransactionRepo extends TransactionRepository {
  final List<TransactionDetail> store;

  _InMemoryTransactionRepo(this.store);

  @override
  Future<int> insertTransaction(TransactionModel transaction) async {
    final accName = transaction.accountId == 1 ? 'BCA' : 'Cash';
    store.add(
      TransactionDetail(
        transaction: transaction,
        accountName: accName,
        accountColorHex: '0xFF0066AE',
        categoryName: transaction.categoryId == 1 ? 'Jajan' : 'Bensin',
      ),
    );
    return transaction.id ?? store.length;
  }

  @override
  Future<int> deleteTransaction(int id) async {
    final before = store.length;
    store.removeWhere((d) => d.id == id);
    return before - store.length;
  }

  @override
  Future<List<DailyTransactionsGroup>> getGroupedTransactionsByDate({
    int? accountId,
    List<int>? accountIds,
    int? categoryId,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    final q = searchQuery?.trim().toLowerCase() ?? '';
    final filtered = store.where((item) {
      if (accountId != null && item.accountId != accountId) return false;
      if (accountId == null &&
          accountIds != null &&
          !accountIds.contains(item.accountId)) {
        return false;
      }
      if (categoryId != null && item.categoryId != categoryId) return false;
      if (type != null && type != 'transfer' && item.type != type) return false;
      if (type == 'transfer') return false;
      if (q.isEmpty) return true;
      return (item.note ?? '').toLowerCase().contains(q) ||
          (item.categoryName ?? '').toLowerCase().contains(q) ||
          item.accountName.toLowerCase().contains(q) ||
          item.amount.toString().contains(q.replaceAll('.', ''));
    }).toList();

    if (filtered.isEmpty) return [];

    int totalExpense = 0;
    int totalIncome = 0;
    for (final item in filtered) {
      if (item.isIncome) {
        totalIncome += item.amount;
      } else {
        totalExpense += item.amount;
      }
    }

    return [
      DailyTransactionsGroup(
        date: filtered.first.date,
        items: filtered,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
      ),
    ];
  }
}

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

  group('UX Enhancements Tests', () {
    testWidgets(
        '1. AccountChipsSelector displays crisp balance on chips & selected header pill without overflow at 320px',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final accounts = [
        AccountWithBalance(
          account: Account(
            id: 1,
            name: 'BCA',
            type: 'bank',
            category: 'harian',
            colorHex: '0xFF0066AE',
            iconCodePoint: Icons.account_balance.codePoint,
            initialBalance: 2500000,
            logoKey: 'bca',
            createdAt: DateTime(2026, 1, 1),
          ),
          balance: 2000000,
          allocatedInGoals: 500000,
        ),
        AccountWithBalance(
          account: Account(
            id: 2,
            name: 'Dompet Tunai',
            type: 'cash',
            category: 'harian',
            colorHex: '0xFF10B981',
            iconCodePoint: Icons.wallet.codePoint,
            initialBalance: 0,
            createdAt: DateTime(2026, 1, 1),
          ),
          balance: 0,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: AccountChipsSelector(
                accounts: accounts,
                selectedAccountId: 1,
                onSelectAccount: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bebas: Rp 2.000.000'), findsOneWidget);
      expect(find.text('Bebas Rp 2.000.000'), findsOneWidget);

      // Geser daftar chip ke kanan pada layar 320px untuk memverifikasi chip kedua
      await tester.drag(find.byType(ListView), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(find.text('Rp 0'), findsOneWidget);

      final zeroText = tester.widget<Text>(find.text('Rp 0'));
      expect(zeroText.style?.color, AppColors.danger);
    });

    test(
        '3. TransactionRepository search filters accurately by note, category, account & amount',
        () async {
      final accountRepo = AccountRepository();
      final txRepo = TransactionRepository();
      final transferRepo = TransferRepository();
      final catRepo = CategoryRepository();

      final accounts = await accountRepo.getAllAccounts();
      final mandiri = accounts.firstWhere((a) => a.name == 'Mandiri');
      final cash = accounts.firstWhere((a) => a.name == 'Cash');
      final cats = await catRepo.getAllCategories(type: 'expense');
      final bensin = cats.firstWhere((c) => c.name == 'Bensin');
      final makan = cats.firstWhere((c) => c.name == 'Makan');

      final day = DateTime(2026, 11, 10, 10, 0);
      await txRepo.insertTransaction(TransactionModel(
        type: 'expense',
        amount: 710000,
        accountId: mandiri.id!,
        categoryId: makan.id,
        note: 'Bayar Ressa',
        date: day,
        createdAt: day,
      ));
      await txRepo.insertTransaction(TransactionModel(
        type: 'expense',
        amount: 35000,
        accountId: cash.id!,
        categoryId: bensin.id,
        note: 'Pertamax Motor',
        date: day,
        createdAt: day,
      ));
      await transferRepo.insertTransfer(TransferModel(
        fromAccountId: mandiri.id!,
        toAccountId: cash.id!,
        amount: 200000,
        note: 'Tarik ATM',
        date: day,
        createdAt: day,
      ));

      // Search by note
      final byNote = await txRepo.getGroupedTransactionsByDate(
        searchQuery: 'ressa',
      );
      expect(byNote.length, 1);
      expect(byNote.first.items.length, 1);
      expect(byNote.first.items.first.note, 'Bayar Ressa');

      // Search by category
      final byCat = await txRepo.getGroupedTransactionsByDate(
        searchQuery: 'bensin',
      );
      expect(byCat.first.items.length, 1);
      expect(byCat.first.items.first.note, 'Pertamax Motor');

      // Search by formatted nominal
      final byAmount = await txRepo.getGroupedTransactionsByDate(
        searchQuery: '710.000',
      );
      expect(byAmount.first.items.length, 1);
      expect(byAmount.first.items.first.amount, 710000);

      // Search transfer note
      final byTransfer = await txRepo.getGroupedTransactionsByDate(
        searchQuery: 'tarik atm',
      );
      expect(byTransfer.first.items, isEmpty);
      expect(byTransfer.first.transfers.length, 1);
    });

    testWidgets(
        '2 & 3. HistoryScreen supports live Search and 1-swipe delete with Undo',
        (WidgetTester tester) async {
      final bca = Account(
        id: 1,
        name: 'BCA',
        type: 'bank',
        category: 'harian',
        colorHex: '0xFF0066AE',
        iconCodePoint: Icons.account_balance.codePoint,
        initialBalance: 1000000,
        createdAt: DateTime(2026, 1, 1),
      );

      final fakeRepo = _InMemoryTransactionRepo([
        TransactionDetail(
          transaction: TransactionModel(
            id: 101,
            type: 'expense',
            amount: 28000,
            accountId: 1,
            categoryId: 1,
            note: 'Kopi Susu',
            date: DateTime(2026, 11, 11, 9, 0),
            createdAt: DateTime(2026, 11, 11, 9, 0),
          ),
          accountName: 'BCA',
          accountColorHex: '0xFF0066AE',
          categoryName: 'Jajan',
        ),
        TransactionDetail(
          transaction: TransactionModel(
            id: 102,
            type: 'expense',
            amount: 40000,
            accountId: 1,
            categoryId: 2,
            note: 'Bensin Pertamax',
            date: DateTime(2026, 11, 11, 11, 0),
            createdAt: DateTime(2026, 11, 11, 11, 0),
          ),
          accountName: 'BCA',
          accountColorHex: '0xFF0066AE',
          categoryName: 'Bensin',
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionRepositoryProvider.overrideWithValue(fakeRepo),
            accountsWithBalanceProvider.overrideWith(
              (ref) async => [AccountWithBalance(account: bca, balance: 932000)],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HistoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Keduanya tampil di awal
      expect(find.text('Kopi Susu'), findsOneWidget);
      expect(find.text('Bensin Pertamax'), findsOneWidget);

      // 3. Test Search: Tap ikon search lalu ketik 'kopi'
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'kopi');
      await tester.pumpAndSettle();

      expect(find.text('Kopi Susu'), findsOneWidget);
      expect(find.text('Bensin Pertamax'), findsNothing);

      // Ketik query yang tidak ada hasil => state kosong pencarian + tombol reset
      await tester.enterText(find.byType(TextField), 'tidakada123');
      await tester.pumpAndSettle();
      expect(find.text('Tidak Ada Hasil Ditemukan'), findsOneWidget);

      await tester.tap(find.text('Reset Pencarian & Filter'));
      await tester.pumpAndSettle();
      expect(find.text('Kopi Susu'), findsOneWidget);
      expect(find.text('Bensin Pertamax'), findsOneWidget);

      // 2. Test Swipe-to-delete: geser 'Kopi Susu' ke kiri + tap Urungkan
      await tester.drag(find.text('Kopi Susu'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Kopi Susu'), findsNothing);
      expect(find.text('Transaksi "Kopi Susu" dihapus'), findsOneWidget);
      expect(find.text('Urungkan'), findsOneWidget);

      await tester.tap(find.text('Urungkan'));
      await tester.pumpAndSettle();
      expect(find.text('Kopi Susu'), findsOneWidget);
    });
  });
}
