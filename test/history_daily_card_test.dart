import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/core/theme/app_theme.dart';
import 'package:monetra/data/models/transaction.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:monetra/features/history/widgets/daily_transaction_group_card.dart';

void main() {
  group('DailyTransactionGroupCard Header Tests', () {
    testWidgets(
        'Menampilkan DUA-DUANYA: Pemasukan dan Pengeluaran secara bersamaan pada header tiap hari',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final txExpense = TransactionModel(
        id: 1,
        type: 'expense',
        amount: 25000,
        accountId: 1,
        categoryId: 1,
        note: 'Beli Kopi',
        date: DateTime(2026, 11, 18),
        createdAt: DateTime(2026, 11, 18),
      );

      final txIncome = TransactionModel(
        id: 2,
        type: 'income',
        amount: 150000,
        accountId: 1,
        categoryId: 2,
        note: 'Gaji Freelance',
        date: DateTime(2026, 11, 18),
        createdAt: DateTime(2026, 11, 18),
      );

      final group = DailyTransactionsGroup(
        date: DateTime(2026, 11, 18),
        totalIncome: 150000,
        totalExpense: 25000,
        items: [
          TransactionDetail(
            transaction: txExpense,
            accountName: 'BCA',
            accountColorHex: '#0066AE',
            categoryName: 'Makan Minum',
          ),
          TransactionDetail(
            transaction: txIncome,
            accountName: 'BCA',
            accountColorHex: '#0066AE',
            categoryName: 'Gaji',
          ),
        ],
        transfers: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyTransactionGroupCard(
                group: group,
                onItemTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Memastikan kedua label 'Pemasukan: ' dan 'Pengeluaran: ' tampil (tidak hanya salah satu)
      expect(find.textContaining('Pemasukan: +Rp 150.000'), findsOneWidget);
      expect(find.textContaining('Pengeluaran: -Rp 25.000'), findsOneWidget);

      // Memastikan jumlah transaksi tertera
      expect(find.text('2 transaksi'), findsOneWidget);

      // Tidak ada overflow exception
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Tetap menampilkan kedua informasi Pemasukan & Pengeluaran meskipun hari tersebut hanya ada pengeluaran',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final txExpense = TransactionModel(
        id: 1,
        type: 'expense',
        amount: 50000,
        accountId: 1,
        categoryId: 1,
        note: 'Makan Siang',
        date: DateTime(2026, 11, 18),
        createdAt: DateTime(2026, 11, 18),
      );

      final group = DailyTransactionsGroup(
        date: DateTime(2026, 11, 18),
        totalIncome: 0,
        totalExpense: 50000,
        items: [
          TransactionDetail(
            transaction: txExpense,
            accountName: 'Dompet Tunai',
            accountColorHex: '#10B981',
            categoryName: 'Makan Minum',
          ),
        ],
        transfers: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyTransactionGroupCard(
                group: group,
                onItemTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pemasukan tetap tertera dengan angka Rp 0
      expect(find.textContaining('Pemasukan: Rp 0'), findsOneWidget);

      // Pengeluaran tertera nominalnya
      expect(find.textContaining('Pengeluaran: -Rp 50.000'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
