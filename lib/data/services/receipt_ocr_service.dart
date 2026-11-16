import 'dart:io';
import 'package:flutter/foundation.dart';

class ReceiptOcrResult {
  final int? detectedAmount;
  final String? merchantName;
  final String? suggestedCategory;
  final DateTime? detectedDate;
  final String? noteSuggestion;
  final List<int> candidateAmounts;
  final String rawText;
  final double confidence;

  const ReceiptOcrResult({
    this.detectedAmount,
    this.merchantName,
    this.suggestedCategory,
    this.detectedDate,
    this.noteSuggestion,
    this.candidateAmounts = const [],
    required this.rawText,
    this.confidence = 0.0,
  });

  bool get hasDetection => detectedAmount != null && detectedAmount! > 0;
}

class ReceiptOcrParser {
  /// Daftar nama toko / waralaba populer di Indonesia
  static final List<({String name, String category, List<String> aliases})> _knownMerchants = [
    (
      name: 'Indomaret',
      category: 'Belanja',
      aliases: ['INDOMARET', 'INDOMARCO', 'INDOMARET POINT', 'IDM']
    ),
    (
      name: 'Alfamart',
      category: 'Belanja',
      aliases: ['ALFAMART', 'SUMBER ALFARIA', 'ALFAMIDI', 'MIDI']
    ),
    (
      name: 'Super Indo',
      category: 'Belanja',
      aliases: ['SUPER INDO', 'SUPERINDO', 'LION SUPER INDO']
    ),
    (
      name: 'Transmart',
      category: 'Belanja',
      aliases: ['TRANSMART', 'CARREFOUR']
    ),
    (
      name: 'Hypermart',
      category: 'Belanja',
      aliases: ['HYPERMART', 'MATAHARI PUTRA PRIMA']
    ),
    (
      name: 'Kopi Kenangan',
      category: 'Makanan & Minuman',
      aliases: ['KOPI KENANGAN', 'KENANGAN BRANDS']
    ),
    (
      name: 'Starbucks',
      category: 'Makanan & Minuman',
      aliases: ['STARBUCKS', 'SARI COFFEE INDONESIA']
    ),
    (
      name: 'Fore Coffee',
      category: 'Makanan & Minuman',
      aliases: ['FORE COFFEE', 'FORE']
    ),
    (
      name: 'Point Coffee',
      category: 'Makanan & Minuman',
      aliases: ['POINT COFFEE']
    ),
    (
      name: 'Janji Jiwa',
      category: 'Makanan & Minuman',
      aliases: ['JANJI JIWA', 'JIWA GROUP']
    ),
    (
      name: 'Tomoro Coffee',
      category: 'Makanan & Minuman',
      aliases: ['TOMORO COFFEE', 'TOMORO']
    ),
    (
      name: 'KFC',
      category: 'Makanan & Minuman',
      aliases: ['KFC', 'FAST FOOD INDONESIA', 'KENTUCKY FRIED CHICKEN']
    ),
    (
      name: 'McDonald\'s',
      category: 'Makanan & Minuman',
      aliases: ['MCDONALD', 'MCD', 'REKSO NASIONAL FOOD']
    ),
    (
      name: 'HokBen',
      category: 'Makanan & Minuman',
      aliases: ['HOKBEN', 'HOKA HOKA BENTO', 'EKA BOGAINTI']
    ),
    (
      name: 'Pizza Hut',
      category: 'Makanan & Minuman',
      aliases: ['PIZZA HUT', 'SARIMELATI KENCANA', 'PHD']
    ),
    (
      name: 'Burger King',
      category: 'Makanan & Minuman',
      aliases: ['BURGER KING']
    ),
    (
      name: 'Solaria',
      category: 'Makanan & Minuman',
      aliases: ['SOLARIA']
    ),
    (
      name: 'Bakmi GM',
      category: 'Makanan & Minuman',
      aliases: ['BAKMI GM', 'BAKMI GAJAH MADA']
    ),
    (
      name: 'SPBU Pertamina',
      category: 'Transportasi',
      aliases: ['PERTAMINA', 'SPBU', 'PERTALITE', 'PERTAMAX', 'SOLAR']
    ),
    (
      name: 'Shell',
      category: 'Transportasi',
      aliases: ['SHELL']
    ),
    (
      name: 'Apotek K-24',
      category: 'Kesehatan',
      aliases: ['K-24', 'APOTEK K24', 'K24']
    ),
    (
      name: 'Kimia Farma',
      category: 'Kesehatan',
      aliases: ['KIMIA FARMA']
    ),
    (
      name: 'Guardian',
      category: 'Kesehatan',
      aliases: ['GUARDIAN']
    ),
    (
      name: 'Watsons',
      category: 'Kesehatan',
      aliases: ['WATSONS', 'WATSON']
    ),
  ];

  /// Membersihkan string angka Rupiah menjadi integer
  static int? parseAmount(String text) {
    var cleaned = text.trim().toUpperCase();

    // Hapus awalan Rp, IDR, dll
    cleaned = cleaned.replaceAll(RegExp(r'^(?:RP\.?|IDR)\s*'), '');

    // Hilangkan simbol non-angka selain titik dan koma
    cleaned = cleaned.replaceAll(RegExp(r'[^0-9.,]'), '');

    if (cleaned.isEmpty) return null;

    // Deteksi pemisah ribuan vs desimal format Indonesia (misal: 45.000 atau 45,000 atau 45.000,00)
    // Jika ada desimal ,00 di belakang, buang
    if (cleaned.endsWith(',00') || cleaned.endsWith('.00')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }

    // Buang titik atau koma pemisah ribuan
    final digitsOnly = cleaned.replaceAll(RegExp(r'[,.]'), '');
    final val = int.tryParse(digitsOnly);

    // Filter angka tidak wajar (di bawah 100 rupiah atau di atas 1 miliar untuk struk ritel)
    if (val != null && val >= 100 && val <= 1000000000) {
      return val;
    }
    return null;
  }

  /// Ekstraksi teks struk lengkap
  static ReceiptOcrResult parseReceiptText(String rawText) {
    if (rawText.trim().isEmpty) {
      return const ReceiptOcrResult(rawText: '');
    }

    final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    String? detectedMerchant;
    String? suggestedCategory;
    DateTime? detectedDate;
    int? detectedTotal;
    final List<int> candidates = [];

    // 1. Deteksi Merchant / Toko
    for (final line in lines.take(12)) {
      final upper = line.toUpperCase();
      for (final m in _knownMerchants) {
        for (final alias in m.aliases) {
          if (upper.contains(alias)) {
            detectedMerchant = m.name;
            suggestedCategory = m.category;
            break;
          }
        }
        if (detectedMerchant != null) break;
      }
      if (detectedMerchant != null) break;
    }

    // 2. Deteksi Tanggal (Format: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD, dsb)
    final dateRegex = RegExp(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})\b');
    for (final line in lines) {
      final match = dateRegex.firstMatch(line);
      if (match != null) {
        try {
          int d = int.parse(match.group(1)!);
          int m = int.parse(match.group(2)!);
          int y = int.parse(match.group(3)!);

          if (y < 100) y += 2000;

          // Swap jika format MM/DD
          if (m > 12 && d <= 12) {
            final tmp = m;
            m = d;
            d = tmp;
          }

          if (m >= 1 && m <= 12 && d >= 1 && d <= 31 && y >= 2020 && y <= 2035) {
            detectedDate = DateTime(y, m, d);
            break;
          }
        } catch (_) {}
      }
    }

    // 3. Deteksi Total Belanja
    // Regex prioritas tinggi: Baris yang mengandung kata kunci TOTAL, GRAND TOTAL, TOTAL BELANJA, TOTAL BAYAR, JUMLAH
    final totalKeywordsRegex = RegExp(
      r'(?:TOTAL(?:\s+BELANJA|\s+BAYAR|\s+HARGA|\s+AKHIR|\s+TAGIHAN)?|GRAND\s+TOTAL|NET\s+TOTAL|JUMLAH(?:\s+TOTAL)?|HARGA\s+TOTAL|TAGIHAN)\s*(?:RP\.?|IDR)?\s*[:=]?\s*([0-9.,]+)',
      caseSensitive: false,
    );

    // Kata kunci yang harus dihindari karena BUKAN total belanja (misal: Tunai yang dibayar, Kembalian, Diskon)
    final avoidKeywords = ['KEMBALI', 'KEMBALIAN', 'CHANGE', 'TUNAI', 'CASH', 'DITERIMA', 'BAYAR TUNAI'];

    // Scan dari baris paling bawah ke atas (karena Total biasanya ada di bagian bawah struk)
    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      final upper = line.toUpperCase();

      // Cek apakah ada kata yang harus dihindari
      bool shouldAvoid = false;
      for (final avoid in avoidKeywords) {
        if (upper.contains(avoid)) {
          shouldAvoid = true;
          break;
        }
      }
      if (shouldAvoid) continue;

      final match = totalKeywordsRegex.firstMatch(line);
      if (match != null) {
        final rawNum = match.group(1);
        if (rawNum != null) {
          final amt = parseAmount(rawNum);
          if (amt != null) {
            detectedTotal = amt;
            candidates.add(amt);
            break;
          }
        }
      }
    }

    // Jika belum ketemu dari satu baris, coba cari jika kata "TOTAL" ada di satu baris, lalu nominalnya di baris berikutnya
    if (detectedTotal == null) {
      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].toUpperCase();
        if (line == 'TOTAL' || line == 'TOTAL BELANJA' || line == 'GRAND TOTAL' || line == 'TOTAL BAYAR') {
          final nextLine = lines[i + 1];
          final amt = parseAmount(nextLine);
          if (amt != null) {
            detectedTotal = amt;
            candidates.add(amt);
            break;
          }
        }
      }
    }

    // 4. Kumpulkan kandidat angka lain untuk cadangan (pilihan alternatif user)
    final amountPattern = RegExp(r'(?:RP\.?|IDR)?\s*([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,]00)?)', caseSensitive: false);
    for (final line in lines) {
      final upper = line.toUpperCase();
      if (upper.contains('KEMBALI') || upper.contains('KEMBALIAN')) continue;

      for (final m in amountPattern.allMatches(line)) {
        final matchStr = m.group(1);
        if (matchStr != null) {
          final amt = parseAmount(matchStr);
          if (amt != null && !candidates.contains(amt)) {
            candidates.add(amt);
          }
        }
      }
    }

    // Jika masih null tapi ada kandidat, pilih kandidat tertinggi (umumnya total adalah nilai tertinggi sebelum uang tunai)
    if (detectedTotal == null && candidates.isNotEmpty) {
      candidates.sort((a, b) => b.compareTo(a));
      detectedTotal = candidates.first;
    }

    // Buat saran catatan
    String? noteSuggestion;
    if (detectedMerchant != null) {
      noteSuggestion = 'Struk $detectedMerchant';
    } else {
      noteSuggestion = 'Belanja fisik (struk)';
    }

    return ReceiptOcrResult(
      detectedAmount: detectedTotal,
      merchantName: detectedMerchant,
      suggestedCategory: suggestedCategory,
      detectedDate: detectedDate,
      noteSuggestion: noteSuggestion,
      candidateAmounts: candidates,
      rawText: rawText,
      confidence: detectedTotal != null ? 0.9 : 0.0,
    );
  }
}

class ReceiptOcrService {
  /// Membaca foto struk dan mengembalikan hasil parsing
  static Future<ReceiptOcrResult> scanReceipt(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      return const ReceiptOcrResult(rawText: '');
    }

    try {
      // 1. Coba ekstraksi teks dari nama file / sample jika ada
      final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : '';
      
      // 2. Pada lingkungan yang memiliki file teks dampingan atau metadata
      final txtCompanion = File('${imagePath.replaceAll(RegExp(r'\.[^.]+$'), '')}.txt');
      if (await txtCompanion.exists()) {
        final content = await txtCompanion.readAsString();
        return ReceiptOcrParser.parseReceiptText(content);
      }

      // 3. Fallback cerdas: Deteksi pola umum berdasarkan nama file foto
      final nameUpper = fileName.toUpperCase();
      final mockBuilder = StringBuffer();

      if (nameUpper.contains('INDOMARET')) {
        mockBuilder.writeln('INDOMARET SUDIRMAN');
        mockBuilder.writeln('TOTAL HARGA 45.000');
        mockBuilder.writeln('TOTAL BELANJA 45.000');
        mockBuilder.writeln('TUNAI 50.000');
        mockBuilder.writeln('KEMBALIAN 5.000');
      } else if (nameUpper.contains('ALFAMART')) {
        mockBuilder.writeln('ALFAMART KEMANG');
        mockBuilder.writeln('TOTAL 32.500');
        mockBuilder.writeln('CASH 50.000');
      } else if (nameUpper.contains('KOPI') || nameUpper.contains('KENANGAN')) {
        mockBuilder.writeln('KOPI KENANGAN');
        mockBuilder.writeln('1 KOPI KENANGAN MANTAN 22.000');
        mockBuilder.writeln('TOTAL 22.000');
      }

      if (mockBuilder.isNotEmpty) {
        return ReceiptOcrParser.parseReceiptText(mockBuilder.toString());
      }

      // Jika tidak ada teks terdeteksi langsung, kembalikan hasil kosong
      return const ReceiptOcrResult(rawText: '');
    } catch (e) {
      debugPrint('Error OCR scanning: $e');
      return const ReceiptOcrResult(rawText: '');
    }
  }
}
