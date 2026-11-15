import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/core/theme/app_theme.dart';
import 'package:monetra/data/models/account.dart';
import 'package:monetra/data/models/category.dart';
import 'package:monetra/data/models/transaction.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:monetra/features/history/providers/history_providers.dart';
import 'package:monetra/features/history/screens/history_screen.dart';
import 'package:monetra/features/home/providers/home_providers.dart';

void main() {
  testWidgets('Repro: HistoryScreen renders with accountId filter set',
      (WidgetTester tester) async {
    final seabank = Account(
      id: 5,
      name: 'SeaBank',
      type: 'bank',
      category: 'tabungan',
      colorHex: '0xFFFD5531',
      iconCodePoint: Icons.account_balance.codePoint,
      initialBalance: 2000000,
      createdAt: DateTime(2026, 1, 1),
    );

    final seabankWithBalance = AccountWithBalance(
      account: seabank,
      balance: 2000000,
    );

    final tx = TransactionDetail(
      transaction: TransactionModel(
        id: 1,
        type: 'income',
        amount: 500000,
        accountId: 5,
        date: DateTime(2026, 11, 15, 10, 0),
        createdAt: DateTime(2026, 11, 15, 10, 0),
        note: 'Bunga SeaBank',
      ),
      accountName: 'SeaBank',
      accountColorHex: '0xFFFD5531',
    );

    final group = DailyTransactionsGroup(
      date: DateTime(2026, 11, 15),
      items: [tx],
      totalIncome: 500000,
      totalExpense: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyFilterProvider.overrideWith(
            (ref) => const HistoryFilter(accountId: 5),
          ),
          accountsWithBalanceProvider.overrideWith(
            (ref) async => [seabankWithBalance],
          ),
          groupedHistoryTransactionsProvider.overrideWith(
            (ref) async => [group],
          ),
          historyCategoriesProvider.overrideWith(
            (ref) async => <Category>[],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const HistoryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Catatan Riwayat'), findsOneWidget);
    expect(find.text('SeaBank'), findsWidgets);
  });
}
