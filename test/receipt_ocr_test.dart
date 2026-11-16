import 'package:flutter_test/flutter_test.dart';
import 'package:monetra/data/services/receipt_ocr_service.dart';

void main() {
  group('ReceiptOcrParser Tests', () {
    test('Deteksi struk Indomaret: Total belanja, merchant, tanggal, dan kategori', () {
      const receipt = '''
PT. INDOMARCO PRISMATAMA
INDOMARET POINT
JL. JEND. SUDIRMAN KAV 21
-------------------------
ROTI KASUR        15.000
SUSU ULTRA 1L     21.500
AIR MINERAL 600ML  4.000
-------------------------
TOTAL HARGA       40.500
TOTAL BELANJA     40.500
TUNAI             50.000
KEMBALIAN          9.500
16/11/2026 09:45:12
''';

      final result = ReceiptOcrParser.parseReceiptText(receipt);

      expect(result.detectedAmount, 40500); // Harus 40.500, bukan tunai 50.000 atau kembalian 9.500
      expect(result.merchantName, 'Indomaret');
      expect(result.suggestedCategory, 'Belanja');
      expect(result.detectedDate, DateTime(2026, 11, 16));
      expect(result.hasDetection, isTrue);
    });

    test('Deteksi struk Cafe / Kopi Kenangan: Grand total dan kategori F&B', () {
      const receipt = '''
KOPI KENANGAN
MALL CENTRAL PARK
-------------------------
1 KOPI KENANGAN MANTAN   22.000
1 TOAST COKLAT KLASIK    18.000
SUBTOTAL                 40.000
PB1 10%                   4.000
GRAND TOTAL              44.000
QRIS BCA                 44.000
15-11-2026
''';

      final result = ReceiptOcrParser.parseReceiptText(receipt);

      expect(result.detectedAmount, 44000);
      expect(result.merchantName, 'Kopi Kenangan');
      expect(result.suggestedCategory, 'Makanan & Minuman');
      expect(result.detectedDate, DateTime(2026, 11, 15));
    });

    test('Deteksi struk SPBU Pertamina: BBM & kategori Transportasi', () {
      const receipt = '''
SPBU 31.12345 PERTAMINA
PERTALITE
LITER: 20.00
HARGA/LITER: 10.000
TOTAL : Rp 200.000
TUNAI : Rp 200.000
''';

      final result = ReceiptOcrParser.parseReceiptText(receipt);

      expect(result.detectedAmount, 200000);
      expect(result.merchantName, 'SPBU Pertamina');
      expect(result.suggestedCategory, 'Transportasi');
    });

    test('Deteksi kata kunci TOTAL multiline & abaikan kembalian', () {
      const receipt = '''
WARUNG MAKAN SEDAP
AYAM GORENG 65.000
ES TEH       10.000
-------------------------
TOTAL
75.000
BAYAR TUNAI 100.000
KEMBALIAN 25.000
''';

      final result = ReceiptOcrParser.parseReceiptText(receipt);

      expect(result.detectedAmount, 75000);
      expect(result.candidateAmounts.contains(75000), isTrue);
    });

    test('Helper parseAmount membersihkan simbol mata uang dengan benar', () {
      expect(ReceiptOcrParser.parseAmount('Rp 125.000'), 125000);
      expect(ReceiptOcrParser.parseAmount('IDR 50.000,00'), 50000);
      expect(ReceiptOcrParser.parseAmount('TOTAL: 15.500'), 15500);
      expect(ReceiptOcrParser.parseAmount('Rp. 3.500.000'), 3500000);
      expect(ReceiptOcrParser.parseAmount('abc'), isNull);
    });
  });
}
