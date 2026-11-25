import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monetra/data/database/app_database.dart';
import 'package:monetra/data/models/account.dart';
import 'package:monetra/data/repositories/account_repository.dart';
import 'package:monetra/data/services/receipt_ocr_service.dart';
import 'package:monetra/data/services/share_intent_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppDatabase.testDbPath = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await AppDatabase.close();
  });

  group('Account Balance Reconciliation Tests', () {
    test('reconcileAccountBalance logs expense when actual balance is lower', () async {
      final repo = AccountRepository();
      final accId = await repo.insertAccount(
        Account(
          name: 'Mandiri Reconcile',
          type: 'bank',
          category: 'harian',
          colorHex: '0xFFF59E0B',
          iconCodePoint: 1234,
          initialBalance: 1000000,
          createdAt: DateTime.now(),
        ),
      );

      final result = await repo.reconcileAccountBalance(
        accountId: accId,
        actualPhysicalBalance: 987500,
        note: 'Biaya admin bulanan',
      );

      expect(result.hasAdjustment, isTrue);
      expect(result.adjustmentType, 'expense');
      expect(result.difference, -12500);
      expect(result.transactionId, isNotNull);

      final updatedBalance = await repo.calculateAccountBalance(accId);
      expect(updatedBalance, 987500);
    });

    test('reconcileAccountBalance logs income when actual balance is higher', () async {
      final repo = AccountRepository();
      final accId = await repo.insertAccount(
        Account(
          name: 'SeaBank Reconcile',
          type: 'bank',
          category: 'tabungan',
          colorHex: '0xFF00B0FF',
          iconCodePoint: 1234,
          initialBalance: 500000,
          createdAt: DateTime.now(),
        ),
      );

      final result = await repo.reconcileAccountBalance(
        accountId: accId,
        actualPhysicalBalance: 512000,
      );

      expect(result.hasAdjustment, isTrue);
      expect(result.adjustmentType, 'income');
      expect(result.difference, 12000);
      expect(result.transactionId, isNotNull);

      final updatedBalance = await repo.calculateAccountBalance(accId);
      expect(updatedBalance, 512000);
    });

    test('reconcileAccountBalance returns zero adjustment without inserting transaction', () async {
      final repo = AccountRepository();
      final accId = await repo.insertAccount(
        Account(
          name: 'Cash Reconcile',
          type: 'cash',
          category: 'harian',
          colorHex: '0xFF10B981',
          iconCodePoint: 1234,
          initialBalance: 250000,
          createdAt: DateTime.now(),
        ),
      );

      final result = await repo.reconcileAccountBalance(
        accountId: accId,
        actualPhysicalBalance: 250000,
      );

      expect(result.hasAdjustment, isFalse);
      expect(result.adjustmentType, isNull);
      expect(result.difference, 0);
      expect(result.transactionId, isNull);
    });
  });

  group('M-Banking Receipt Parser & Share Payload Tests', () {
    test('Parses Livin by Mandiri transfer receipt text accurately', () {
      const text = '''
LIVIN' BY MANDIRI
TRANSFER BERHASIL
25 Nov 2026 14:22 WIB
PENERIMA: BUDI SANTOSO
KE REKENING: BRI ****1234
NOMINAL: Rp 150.000
BIAYA ADMIN: Rp 2.500
TOTAL TRANSAKSI: Rp 152.500
''';

      final parsed = ReceiptOcrParser.parseReceiptText(text);

      expect(parsed.detectedAmount, 152500);
      expect(parsed.bankName, 'Mandiri');
      expect(parsed.detectedDate, DateTime(2026, 11, 25));
      expect(parsed.isIncomeSuggestion, isFalse);
      expect(parsed.noteSuggestion, 'Transfer ke BUDI SANTOSO');
    });

    test('Parses SeaBank QRIS receipt and detects bank & merchant', () {
      const text = '''
SEABANK INDONESIA
PEMBAYARAN QRIS BERHASIL
MERCHANT: KOPI KENANGAN
2026-11-25
TOTAL BAYAR: IDR 35.000
''';

      final parsed = ReceiptOcrParser.parseReceiptText(text);

      expect(parsed.detectedAmount, 35000);
      expect(parsed.bankName, 'SeaBank');
      expect(parsed.merchantName, 'Kopi Kenangan');
      expect(parsed.suggestedCategory, 'Makanan & Minuman');
      expect(parsed.detectedDate, DateTime(2026, 11, 25));
      expect(parsed.isIncomeSuggestion, isFalse);
    });

    test('Detects incoming transfer receipt from myBCA as income suggestion', () {
      const text = '''
myBCA
DANA MASUK BERHASIL DITERIMA
25 November 2026
DARI: PT MAJU JAYA
NOMINAL TRANSFER: Rp 2.500.000
''';

      final parsed = ReceiptOcrParser.parseReceiptText(text);

      expect(parsed.detectedAmount, 2500000);
      expect(parsed.bankName, 'BCA');
      expect(parsed.isIncomeSuggestion, isTrue);
      expect(parsed.detectedDate, DateTime(2026, 11, 25));
      expect(parsed.noteSuggestion, 'Terima dari PT MAJU JAYA');
    });

    test('SharedReceiptPayload.fromMap validates non-empty fields cleanly', () {
      expect(SharedReceiptPayload.fromMap(null), isNull);
      expect(SharedReceiptPayload.fromMap({'imagePath': ' ', 'text': ''}), isNull);

      final payload = SharedReceiptPayload.fromMap({
        'imagePath': '/data/cache/receipt_1.jpg',
        'text': 'TOTAL BAYAR Rp 50.000',
      });
      expect(payload, isNotNull);
      expect(payload!.hasImage, isTrue);
      expect(payload.hasText, isTrue);
      expect(payload.imagePath, '/data/cache/receipt_1.jpg');
    });
  });
}
