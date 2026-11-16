import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/data/models/account.dart';
import 'package:monetra/data/models/profile_model.dart';
import 'package:monetra/data/models/transaction.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/repositories/report_repository.dart';
import 'package:monetra/data/repositories/transaction_repository.dart';
import 'package:monetra/data/services/report_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final personalProfile = ProfileModel(
    key: 'default',
    name: 'Pribadi',
    type: 'personal',
    iconCodePoint: 0xe491,
    colorHex: '0xFF10B981',
    createdAt: DateTime(2026, 1, 1),
  );

  final businessProfile = ProfileModel(
    key: 'toko_kopi',
    name: 'Kopi Senja Bersama',
    type: 'business',
    iconCodePoint: 0xe5e1,
    colorHex: '0xFF3B82F6',
    createdAt: DateTime(2026, 1, 1),
  );

  final dummySummary = MonthlyReportSummary(
    year: 2026,
    month: 11,
    totalIncome: 12500000,
    totalExpense: 6800000,
    netSavings: 5700000,
    dailyAverageExpense: 226667,
    highestExpenseAmount: 1500000,
    categoryIncomes: [
      const CategoryExpenseShare(
        categoryId: 1,
        categoryName: 'Penjualan Kopi',
        colorHex: '0xFF10B981',
        iconCodePoint: 0xe8e5,
        totalAmount: 10000000,
        percentage: 80.0,
      ),
      const CategoryExpenseShare(
        categoryId: 2,
        categoryName: 'Penjualan Snack & Pastry',
        colorHex: '0xFF10B981',
        iconCodePoint: 0xe8e5,
        totalAmount: 2500000,
        percentage: 20.0,
      ),
    ],
    categoryExpenses: [
      const CategoryExpenseShare(
        categoryId: 3,
        categoryName: 'Bahan Baku Biji & Susu',
        colorHex: '0xFFEF4444',
        iconCodePoint: 0xe491,
        totalAmount: 4000000,
        percentage: 58.8,
      ),
      const CategoryExpenseShare(
        categoryId: 4,
        categoryName: 'Sewa & Listrik',
        colorHex: '0xFFEF4444',
        iconCodePoint: 0xe491,
        totalAmount: 2800000,
        percentage: 41.2,
      ),
    ],
    accountExpenses: [
      const AccountExpenseShare(
        accountId: 1,
        accountName: 'Kas Usaha',
        colorHex: '0xFF10B981',
        totalExpense: 6800000,
        totalIncome: 12500000,
      ),
    ],
  );

  final dummyAccounts = [
    AccountWithBalance(
      account: Account(
        id: 1,
        name: 'Kas Usaha',
        type: 'cash',
        category: 'harian',
        colorHex: '0xFF10B981',
        iconCodePoint: 0xe491,
        initialBalance: 2000000,
        createdAt: DateTime(2026, 1, 1),
      ),
      balance: 7700000,
    ),
  ];

  final dummyTransactions = [
    TransactionDetail(
      transaction: TransactionModel(
        id: 1,
        type: 'income',
        amount: 5000000,
        accountId: 1,
        categoryId: 1,
        note: 'Penjualan Akhir Pekan',
        date: DateTime(2026, 11, 15, 14, 30),
        createdAt: DateTime(2026, 11, 15, 14, 30),
      ),
      accountName: 'Kas Usaha',
      accountColorHex: '0xFF10B981',
      categoryName: 'Penjualan Kopi',
    ),
    TransactionDetail(
      transaction: TransactionModel(
        id: 2,
        type: 'expense',
        amount: 1500000,
        accountId: 1,
        categoryId: 3,
        note: 'Restock Susu & Biji Arabika',
        date: DateTime(2026, 11, 16, 10, 00),
        createdAt: DateTime(2026, 11, 16, 10, 00),
      ),
      accountName: 'Kas Usaha',
      accountColorHex: '0xFF10B981',
      categoryName: 'Bahan Baku Biji & Susu',
    ),
  ];

  group('ReportExportService Tests', () {
    test('Generate PDF untuk profil Bisnis menghasilkan byte PDF valid', () async {
      final pdfBytes = await ReportExportService.generatePdfBytes(
        profile: businessProfile,
        year: 2026,
        month: 11,
        summary: dummySummary,
        accounts: dummyAccounts,
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      // Validasi PDF magic number "%PDF-"
      final header = utf8.decode(pdfBytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test('Generate PDF untuk profil Pribadi menghasilkan byte PDF valid', () async {
      final pdfBytes = await ReportExportService.generatePdfBytes(
        profile: personalProfile,
        year: 2026,
        month: 11,
        summary: dummySummary,
        accounts: dummyAccounts,
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      final header = utf8.decode(pdfBytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test('Generate CSV menghasilkan file sesuai standar Excel (BOM UTF-8, kolom lengkap)', () {
      final csv = ReportExportService.generateCsvContent(
        profile: businessProfile,
        year: 2026,
        month: 11,
        transactions: dummyTransactions,
        summary: dummySummary,
      );

      // Pastikan ada UTF-8 BOM
      expect(csv.startsWith('\uFEFF'), isTrue);

      // Pastikan metadata & header tabel lengkap
      expect(csv.contains('Kopi Senja Bersama'), isTrue);
      expect(csv.contains('Bisnis'), isTrue);
      expect(csv.contains('No,Tanggal,Jam,Tipe,Kategori,Rekening,Nominal,Catatan'), isTrue);

      // Pastikan data transaksi masuk
      expect(csv.contains('Penjualan Kopi'), isTrue);
      expect(csv.contains('Restock Susu & Biji Arabika'), isTrue);

      // Pastikan ringkasan masuk
      expect(csv.contains('Total Omzet,12500000'), isTrue);
      expect(csv.contains('Laba Bersih Usaha,5700000'), isTrue);
    });
  });
}
