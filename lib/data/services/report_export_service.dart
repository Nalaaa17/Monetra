import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../models/profile_model.dart';
import '../repositories/account_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/transaction_repository.dart';

class ReportExportService {
  /// Format rupiah bersih untuk PDF & CSV
  static String formatRupiah(int amount) {
    return CurrencyFormatter.format(amount);
  }

  // ===========================================================================
  // 1. GENERATE DOKUMEN PDF
  // ===========================================================================

  static Future<Uint8List> generatePdfBytes({
    required ProfileModel profile,
    required int year,
    required int month,
    required MonthlyReportSummary summary,
    required List<AccountWithBalance> accounts,
  }) async {
    final pdf = pw.Document();
    final periodDate = DateTime(year, month, 1);
    final periodName = DateFormatter.formatMonthYear(periodDate);
    final isBusiness = profile.isBusiness;

    final primaryColor = PdfColor.fromHex('#059669'); // Emerald
    final darkColor = PdfColor.fromHex('#0F172A'); // Slate 900
    final textMuted = PdfColor.fromHex('#64748B'); // Slate 500
    final borderColor = PdfColor.fromHex('#E2E8F0'); // Slate 200
    final lightBg = PdfColor.fromHex('#F8FAFC'); // Slate 50
    final dangerColor = PdfColor.fromHex('#EF4444'); // Red 500

    // Hitung margin persentase laba / tabungan
    final double netMargin = summary.totalIncome > 0
        ? (summary.netSavings / summary.totalIncome) * 100
        : 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 12),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: borderColor)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Monetra - Aplikasi Manajemen Finansial Multi-Wallet & Multi-Profil',
                  style: pw.TextStyle(fontSize: 8, color: textMuted),
                ),
                pw.Text(
                  'Halaman ${context.pageNumber} dari ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, color: textMuted),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // 1. Header Dokumen
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 16),
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 1.5)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: pw.BoxDecoration(
                              color: primaryColor,
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            child: pw.Text(
                              'MONETRA',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            isBusiness
                                ? 'LAPORAN LABA RUGI (P&L)'
                                : 'LAPORAN ARUS KAS & KEUANGAN',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: darkColor,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        isBusiness
                            ? 'Unit Usaha: ${profile.name}'
                            : 'Profil: ${profile.name}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'PERIODE: $periodName',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Dicetak: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())} WIB',
                        style: pw.TextStyle(fontSize: 8, color: textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),

            // 2. Tiga Kartu Ringkasan Finansial Utama
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildPdfSummaryCard(
                    title: isBusiness ? 'TOTAL OMZET' : 'TOTAL PEMASUKAN',
                    amount: formatRupiah(summary.totalIncome),
                    amountColor: primaryColor,
                    borderColor: borderColor,
                    lightBg: lightBg,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _buildPdfSummaryCard(
                    title: isBusiness ? 'BEBAN OPERASIONAL' : 'TOTAL PENGELUARAN',
                    amount: formatRupiah(summary.totalExpense),
                    amountColor: dangerColor,
                    borderColor: borderColor,
                    lightBg: lightBg,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _buildPdfSummaryCard(
                    title: isBusiness ? 'LABA BERSIH (NET)' : 'SURPLUS / TABUNGAN',
                    amount: formatRupiah(summary.netSavings),
                    amountColor: summary.netSavings >= 0 ? primaryColor : dangerColor,
                    subtext: isBusiness
                        ? 'Margin Laba: ${netMargin.toStringAsFixed(1)}%'
                        : 'Savings Rate: ${netMargin.toStringAsFixed(1)}%',
                    borderColor: borderColor,
                    lightBg: lightBg,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // 3. Tabel Rincian Pemasukan / Omzet
            pw.Text(
              isBusiness
                  ? 'RINCIAN SUMBER OMZET / PENDAPATAN'
                  : 'RINCIAN SUMBER PEMASUKAN',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: darkColor,
              ),
            ),
            pw.SizedBox(height: 8),
            summary.categoryIncomes.isEmpty
                ? _buildEmptyTableNote('Belum ada transaksi pemasukan pada periode ini.', textMuted)
                : pw.Table(
                    border: pw.TableBorder.all(color: borderColor, width: 0.8),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1),
                      1: const pw.FlexColumnWidth(5),
                      2: const pw.FlexColumnWidth(3),
                      3: const pw.FlexColumnWidth(2),
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: lightBg),
                        children: [
                          _buildPdfTableHeader('#'),
                          _buildPdfTableHeader('Kategori Pemasukan'),
                          _buildPdfTableHeader('Nominal (Rp)', align: pw.TextAlign.right),
                          _buildPdfTableHeader('Porsi (%)', align: pw.TextAlign.right),
                        ],
                      ),
                      ...summary.categoryIncomes.asMap().entries.map((entry) {
                        final idx = entry.key + 1;
                        final item = entry.value;
                        return pw.TableRow(
                          children: [
                            _buildPdfTableCell('$idx', align: pw.TextAlign.center),
                            _buildPdfTableCell(item.categoryName, isBold: true),
                            _buildPdfTableCell(formatRupiah(item.totalAmount), align: pw.TextAlign.right),
                            _buildPdfTableCell('${item.percentage.toStringAsFixed(1)}%', align: pw.TextAlign.right),
                          ],
                        );
                      }),
                    ],
                  ),
            pw.SizedBox(height: 20),

            // 4. Tabel Rincian Beban / Pengeluaran
            pw.Text(
              isBusiness
                  ? 'RINCIAN BEBAN & BIAYA OPERASIONAL'
                  : 'RINCIAN POS PENGELUARAN',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: darkColor,
              ),
            ),
            pw.SizedBox(height: 8),
            summary.categoryExpenses.isEmpty
                ? _buildEmptyTableNote('Belum ada transaksi pengeluaran pada periode ini.', textMuted)
                : pw.Table(
                    border: pw.TableBorder.all(color: borderColor, width: 0.8),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1),
                      1: const pw.FlexColumnWidth(5),
                      2: const pw.FlexColumnWidth(3),
                      3: const pw.FlexColumnWidth(2),
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: lightBg),
                        children: [
                          _buildPdfTableHeader('#'),
                          _buildPdfTableHeader('Kategori Pengeluaran'),
                          _buildPdfTableHeader('Nominal (Rp)', align: pw.TextAlign.right),
                          _buildPdfTableHeader('Porsi (%)', align: pw.TextAlign.right),
                        ],
                      ),
                      ...summary.categoryExpenses.asMap().entries.map((entry) {
                        final idx = entry.key + 1;
                        final item = entry.value;
                        return pw.TableRow(
                          children: [
                            _buildPdfTableCell('$idx', align: pw.TextAlign.center),
                            _buildPdfTableCell(item.categoryName, isBold: true),
                            _buildPdfTableCell(formatRupiah(item.totalAmount), align: pw.TextAlign.right),
                            _buildPdfTableCell('${item.percentage.toStringAsFixed(1)}%', align: pw.TextAlign.right),
                          ],
                        );
                      }),
                    ],
                  ),
            pw.SizedBox(height: 20),

            // 5. Posisi Saldo Kas & Rekening
            pw.Text(
              isBusiness
                  ? 'POSISI SALDO KAS & REKENING USAHA'
                  : 'POSISI SALDO DOMPET & TABUNGAN',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: darkColor,
              ),
            ),
            pw.SizedBox(height: 8),
            accounts.isEmpty
                ? _buildEmptyTableNote('Belum ada dompet/rekening terdaftar.', textMuted)
                : pw.Table(
                    border: pw.TableBorder.all(color: borderColor, width: 0.8),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1),
                      1: const pw.FlexColumnWidth(5),
                      2: const pw.FlexColumnWidth(3),
                      3: const pw.FlexColumnWidth(3),
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: lightBg),
                        children: [
                          _buildPdfTableHeader('#'),
                          _buildPdfTableHeader('Nama Rekening / Dompet'),
                          _buildPdfTableHeader('Kategori'),
                          _buildPdfTableHeader('Saldo Saat Ini (Rp)', align: pw.TextAlign.right),
                        ],
                      ),
                      ...accounts.asMap().entries.map((entry) {
                        final idx = entry.key + 1;
                        final acc = entry.value;
                        return pw.TableRow(
                          children: [
                            _buildPdfTableCell('$idx', align: pw.TextAlign.center),
                            _buildPdfTableCell(acc.name, isBold: true),
                            _buildPdfTableCell(acc.category.toUpperCase()),
                            _buildPdfTableCell(formatRupiah(acc.balance), align: pw.TextAlign.right),
                          ],
                        );
                      }),
                    ],
                  ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfSummaryCard({
    required String title,
    required String amount,
    required PdfColor amountColor,
    String? subtext,
    required PdfColor borderColor,
    required PdfColor lightBg,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: borderColor),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#475569'),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            amount,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: amountColor,
            ),
          ),
          if (subtext != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              subtext,
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColor.fromHex('#64748B'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildPdfTableHeader(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#1E293B'),
        ),
      ),
    );
  }

  static pw.Widget _buildPdfTableCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColor.fromHex('#334155'),
        ),
      ),
    );
  }

  static pw.Widget _buildEmptyTableNote(String note, PdfColor textMuted) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      child: pw.Text(
        note,
        style: pw.TextStyle(fontSize: 9, color: textMuted, fontStyle: pw.FontStyle.italic),
      ),
    );
  }

  /// Pratinjau atau Cetak PDF langsung melalui dialog printer bawaan platform
  static Future<void> previewOrPrintPdf({
    required ProfileModel profile,
    required int year,
    required int month,
    required MonthlyReportSummary summary,
    required List<AccountWithBalance> accounts,
  }) async {
    final pdfBytes = await generatePdfBytes(
      profile: profile,
      year: year,
      month: month,
      summary: summary,
      accounts: accounts,
    );

    final safeProfileName = profile.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final fileName = 'Laporan_${safeProfileName}_${year}_$month.pdf';

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: fileName,
    );
  }

  /// Bagikan file PDF via WhatsApp, Email, Drive, atau aplikasi lain
  static Future<void> sharePdf({
    required ProfileModel profile,
    required int year,
    required int month,
    required MonthlyReportSummary summary,
    required List<AccountWithBalance> accounts,
  }) async {
    final pdfBytes = await generatePdfBytes(
      profile: profile,
      year: year,
      month: month,
      summary: summary,
      accounts: accounts,
    );

    final safeProfileName = profile.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final fileName = 'Laporan_${safeProfileName}_${year}_$month.pdf';

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: fileName,
    );
  }

  // ===========================================================================
  // 2. GENERATE & EKSPOR EXCEL / CSV
  // ===========================================================================

  /// Escape string sesuai standar RFC-4180 untuk file CSV/Excel
  static String escapeCsv(String value) {
    if (value.contains(',') ||
        value.contains(';') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Menghasilkan format string CSV lengkap dengan BOM UTF-8
  static String generateCsvContent({
    required ProfileModel profile,
    required int year,
    required int month,
    required List<TransactionDetail> transactions,
    required MonthlyReportSummary summary,
  }) {
    final buffer = StringBuffer();
    final periodDate = DateTime(year, month, 1);
    final periodName = DateFormatter.formatMonthYear(periodDate);

    // 1. Tambahkan UTF-8 Byte Order Mark (BOM) agar Microsoft Excel membaca karakter dengan benar
    buffer.write('\uFEFF');

    // 2. Header Metadata
    buffer.writeln('LAPORAN MUTASI KEUANGAN - MONETRA');
    buffer.writeln('Profil,${escapeCsv(profile.name)}');
    buffer.writeln('Tipe Profil,${profile.isBusiness ? "Bisnis" : "Pribadi"}');
    buffer.writeln('Periode,${escapeCsv(periodName)}');
    buffer.writeln('Tanggal Ekspor,${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    buffer.writeln('');

    // 3. Kolom Tabel
    buffer.writeln('No,Tanggal,Jam,Tipe,Kategori,Rekening,Nominal,Catatan');

    // 4. Baris Transaksi
    for (int i = 0; i < transactions.length; i++) {
      final tx = transactions[i];
      final no = i + 1;
      final dateStr = DateFormat('yyyy-MM-dd').format(tx.date);
      final timeStr = DateFormat('HH:mm').format(tx.date);
      final typeStr = tx.isIncome ? 'Pemasukan' : 'Pengeluaran';
      final categoryStr = escapeCsv(tx.categoryName ?? 'Tanpa Kategori');
      final accountStr = escapeCsv(tx.accountName);
      final amountStr = tx.amount.toString();
      final noteStr = escapeCsv(tx.note ?? '');

      buffer.writeln('$no,$dateStr,$timeStr,$typeStr,$categoryStr,$accountStr,$amountStr,$noteStr');
    }

    // 5. Ringkasan Finansial di Bagian Bawah
    buffer.writeln('');
    buffer.writeln('--- RINGKASAN FINANSIAL ---');
    buffer.writeln('${profile.isBusiness ? "Total Omzet" : "Total Pemasukan"},${summary.totalIncome}');
    buffer.writeln('${profile.isBusiness ? "Total Beban Operasional" : "Total Pengeluaran"},${summary.totalExpense}');
    buffer.writeln('${profile.isBusiness ? "Laba Bersih Usaha" : "Surplus Bersih"},${summary.netSavings}');

    return buffer.toString();
  }

  /// Simpan file CSV ke temporary storage lalu bagikan via Share Plus
  static Future<void> shareCsv({
    required ProfileModel profile,
    required int year,
    required int month,
    required List<TransactionDetail> transactions,
    required MonthlyReportSummary summary,
  }) async {
    final csvContent = generateCsvContent(
      profile: profile,
      year: year,
      month: month,
      transactions: transactions,
      summary: summary,
    );

    final safeProfileName = profile.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final fileName = 'Mutasi_${safeProfileName}_${year}_$month.csv';

    final tempDir = await getTemporaryDirectory();
    final filePath = p.join(tempDir.path, fileName);
    final file = File(filePath);
    await file.writeAsString(csvContent);

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            filePath,
            mimeType: 'text/csv',
            name: fileName,
          ),
        ],
        subject: 'Laporan Mutasi Keuangan $safeProfileName ($year-$month)',
        text:
            'Berikut lampiran mutasi keuangan Monetra untuk periode $year-$month.',
      ),
    );
  }
}
