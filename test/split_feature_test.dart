import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monetra/core/theme/app_theme.dart';
import 'package:monetra/data/models/account.dart';
import 'package:monetra/data/models/category.dart';
import 'package:monetra/data/models/transaction.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/category_repository.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:monetra/features/history/widgets/daily_transaction_group_card.dart';
import 'package:monetra/features/tools/screens/money_calculator_screen.dart';
import 'package:monetra/features/tools/widgets/split_bill_view.dart';
import 'package:monetra/features/transaction/providers/transaction_form_provider.dart';
import 'package:monetra/shared/providers/repository_providers.dart';

class _FakeAccountRepository implements AccountRepository {
  final Account dummyAccount = Account(
    id: 1,
    name: 'Dompet Tunai',
    type: 'cash',
    colorHex: '#059669',
    iconCodePoint: 0xe532,
    initialBalance: 1000000,
    createdAt: DateTime.now(),
  );

  @override
  Future<List<Account>> getAllAccounts({bool includeArchived = false}) async {
    return [dummyAccount];
  }

  @override
  Future<List<AccountWithBalance>> getAllAccountsWithBalances({
    bool includeArchived = false,
  }) async {
    return [
      AccountWithBalance(
        account: dummyAccount,
        balance: 1000000,
      ),
    ];
  }

  @override
  Future<bool> checkNewTransactionBalanceWarning({
    required int accountId,
    required int amount,
    required String type,
  }) async =>
      false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCategoryRepository implements CategoryRepository {
  @override
  Future<List<Category>> getAllCategories({
    bool onlyActive = true,
    String? type,
  }) async {
    return [
      const Category(
        id: 1,
        name: 'Bahan Makanan',
        iconCodePoint: 0xe532,
        colorHex: '#10B981',
        type: 'expense',
      ),
      const Category(
        id: 2,
        name: 'Hiburan',
        iconCodePoint: 0xe405,
        colorHex: '#F59E0B',
        type: 'expense',
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTransactionRepository implements TransactionRepository {
  final List<TransactionModel> inserted = [];

  @override
  Future<int> insertTransaction(TransactionModel transaction) async {
    inserted.add(transaction);
    return inserted.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Category 5: Fitur Split Transaksi & Lampiran Struk', () {
    test('TransactionModel imagePath and hasReceipt work correctly', () {
      final txWithoutReceipt = TransactionModel(
        id: 1,
        type: 'expense',
        amount: 50000,
        accountId: 1,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );
      expect(txWithoutReceipt.hasReceipt, isFalse);
      expect(txWithoutReceipt.imagePath, isNull);

      final txWithReceipt = txWithoutReceipt.copyWith(
        imagePath: '/storage/receipt_123.jpg',
      );
      expect(txWithReceipt.hasReceipt, isTrue);
      expect(txWithReceipt.imagePath, '/storage/receipt_123.jpg');

      final map = txWithReceipt.toMap();
      expect(map['imagePath'], '/storage/receipt_123.jpg');

      final reconstructed = TransactionModel.fromMap(map);
      expect(reconstructed.imagePath, '/storage/receipt_123.jpg');
      expect(reconstructed.hasReceipt, isTrue);

      final cleared = reconstructed.copyWith(clearImage: true);
      expect(cleared.imagePath, isNull);
      expect(cleared.hasReceipt, isFalse);
    });

    test('TransactionFormNotifier handles split transactions logic & multi-insert',
        () async {
      final fakeTxRepo = _FakeTransactionRepository();
      final fakeAccRepo = _FakeAccountRepository();
      final fakeCatRepo = _FakeCategoryRepository();

      final container = ProviderContainer(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeTxRepo),
          accountRepositoryProvider.overrideWithValue(fakeAccRepo),
          categoryRepositoryProvider.overrideWithValue(fakeCatRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(transactionFormNotifierProvider.notifier);

      // Set nominal: 300.000
      notifier.setAmount(300000);
      notifier.setAccount(1);
      notifier.setNote('Belanja Bulanan');

      // Aktifkan split
      notifier.toggleSplit(true);
      var state = container.read(transactionFormNotifierProvider);
      expect(state.isSplit, isTrue);
      expect(state.splitItems.length, 2);
      expect(state.splitTotalAmount, 300000);
      expect(state.isSplitBalanced, isTrue);

      // Ubah pecahan: 200.000 bahan makanan + 100.000 hiburan
      notifier.updateSplitItem(
        0,
        state.splitItems[0].copyWith(
          categoryId: 1,
          amount: 200000,
          note: 'Bahan Pokok Dapur',
        ),
      );
      notifier.updateSplitItem(
        1,
        state.splitItems[1].copyWith(
          categoryId: 2,
          amount: 100000,
          note: 'Cemilan & Hiburan',
        ),
      );

      // Set foto struk
      notifier.setImagePath('/photos/struk_supermarket.jpg');
      state = container.read(transactionFormNotifierProvider);
      expect(state.hasReceipt, isTrue);

      // Submit
      final success = await notifier.submit();
      expect(success, isTrue);

      // Harus tersimpan 2 transaksi terpisah dengan receipt dan akun yang sama
      expect(fakeTxRepo.inserted.length, 2);

      final tx1 = fakeTxRepo.inserted[0];
      expect(tx1.amount, 200000);
      expect(tx1.categoryId, 1);
      expect(tx1.note, 'Bahan Pokok Dapur');
      expect(tx1.imagePath, '/photos/struk_supermarket.jpg');

      final tx2 = fakeTxRepo.inserted[1];
      expect(tx2.amount, 100000);
      expect(tx2.categoryId, 2);
      expect(tx2.note, 'Cemilan & Hiburan');
      expect(tx2.imagePath, '/photos/struk_supermarket.jpg');
    });

    testWidgets('SplitBillView renders inside MoneyCalculatorScreen',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeAccRepo = _FakeAccountRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountRepositoryProvider.overrideWithValue(fakeAccRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const MoneyCalculatorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pastikan ada tab 'Bagi Tagihan (Split Bill)'
      expect(find.text('Bagi Tagihan'), findsOneWidget);

      // Ketuk tab Bagi Tagihan
      await tester.tap(find.text('Bagi Tagihan'));
      await tester.pumpAndSettle();

      // Periksa elemen-elemen Split Bill
      expect(find.byType(SplitBillView), findsOneWidget);
      expect(find.text('Tagihan Pokok'), findsOneWidget);
      expect(find.text('Salin Rincian'), findsOneWidget);
      expect(find.text('Catat Bagianku'), findsOneWidget);
    });

    testWidgets('DailyTransactionGroupCard displays receipt badge when hasReceipt is true',
        (tester) async {
      final txModel = TransactionModel(
        id: 1,
        type: 'expense',
        amount: 75000,
        accountId: 1,
        categoryId: 1,
        note: 'Makan Siang Bareng',
        date: DateTime.now(),
        createdAt: DateTime.now(),
        imagePath: '/path/to/struk.jpg',
      );

      final group = DailyTransactionsGroup(
        date: DateTime.now(),
        totalIncome: 0,
        totalExpense: 75000,
        items: [
          TransactionDetail(
            transaction: txModel,
            accountName: 'BCA',
            accountColorHex: '#0066AE',
            categoryName: 'Makan Minum',
            categoryColorHex: '#F59E0B',
            categoryIconCodePoint: 0xe532,
          ),
        ],
        transfers: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: DailyTransactionGroupCard(
              group: group,
              onItemTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Struk'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_rounded), findsWidgets);
    });
  });
}
