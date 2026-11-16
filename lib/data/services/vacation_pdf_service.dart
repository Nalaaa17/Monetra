import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../models/vacation.dart';

class VacationPdfService {
  static String _formatRupiah(int amount) => CurrencyFormatter.format(amount);

  /// Menghasilkan file PDF ringkasan liburan dalam bentuk Uint8List
  static Future<Uint8List> generatePdfBytes(VacationDetail detail) async {
    final pdf = pw.Document();

    final skyColor = PdfColor.fromHex('#0284C7');
    final darkColor = PdfColor.fromHex('#0F172A');
    final textMuted = PdfColor.fromHex('#64748B');
    final borderColor = PdfColor.fromHex('#E2E8F0');
    final lightBg = PdfColor.fromHex('#F8FAFC');
    final dangerColor = PdfColor.fromHex('#EF4444');
    final successColor = PdfColor.fromHex('#10B981');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 10),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Monetra • Ringkasan Pengeluaran Trip Liburan',
                  style: pw.TextStyle(color: textMuted, fontSize: 8),
                ),
                pw.Text(
                  'Halaman ${context.pageNumber} dari ${context.pagesCount}',
                  style: pw.TextStyle(color: textMuted, fontSize: 8),
                ),
              ],
            ),
          );
        },
        build: (context) {
          return [
            // Header Dokumen
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'MONETRA',
                      style: pw.TextStyle(
                        color: skyColor,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      detail.vacation.name,
                      style: pw.TextStyle(
                        color: darkColor,
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (detail.vacation.destination != null &&
                        detail.vacation.destination!.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Destinasi: ${detail.vacation.destination}',
                        style: pw.TextStyle(color: textMuted, fontSize: 10),
                      ),
                    ],
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: detail.vacation.isActive
                            ? PdfColor.fromHex('#E0F2FE')
                            : PdfColor.fromHex('#D1FAE5'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Text(
                        detail.vacation.isActive ? 'TRIP AKTIF' : 'SELESAI',
                        style: pw.TextStyle(
                          color: detail.vacation.isActive ? skyColor : successColor,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Dicetak: ${DateFormatter.formatShort(DateTime.now())}',
                      style: pw.TextStyle(color: textMuted, fontSize: 8),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 18),

            // Kartu Ringkasan Finansial (3 Kolom)
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: lightBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                border: pw.Border.all(color: borderColor),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TOTAL BUJET',
                            style: pw.TextStyle(
                                color: textMuted,
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('Rp ${_formatRupiah(detail.totalBudget)}',
                            style: pw.TextStyle(
                                color: darkColor,
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  pw.Container(width: 1, height: 28, color: borderColor),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TOTAL TERPAKAI',
                            style: pw.TextStyle(
                                color: textMuted,
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('Rp ${_formatRupiah(detail.totalSpent)}',
                            style: pw.TextStyle(
                                color: dangerColor,
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  pw.Container(width: 1, height: 28, color: borderColor),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('SISA SALDO',
                            style: pw.TextStyle(
                                color: textMuted,
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('Rp ${_formatRupiah(detail.remainingBudget)}',
                            style: pw.TextStyle(
                                color: skyColor,
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Section 1: Alokasi Rekening
            pw.Text(
              'RINCIAN ALOKASI REKENING',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: textMuted,
                letterSpacing: 0.8,
              ),
            ),
            pw.SizedBox(height: 8),

            pw.Table(
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(color: borderColor, width: 0.5),
                bottom: pw.BorderSide(color: borderColor, width: 0.8),
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: lightBg),
                  children: [
                    _buildCell('Rekening Sumber', isHeader: true),
                    _buildCell('Alokasi Awal', isHeader: true, alignRight: true),
                    _buildCell('Terpakai', isHeader: true, alignRight: true),
                    _buildCell('Sisa Saldo', isHeader: true, alignRight: true),
                  ],
                ),
                ...detail.accounts.map((acc) {
                  return pw.TableRow(
                    children: [
                      _buildCell(acc.accountName),
                      _buildCell('Rp ${_formatRupiah(acc.allocatedAmount)}',
                          alignRight: true),
                      _buildCell('Rp ${_formatRupiah(acc.spentAmount)}',
                          alignRight: true),
                      _buildCell('Rp ${_formatRupiah(acc.remainingAmount)}',
                          alignRight: true, highlight: true),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 24),

            // Section 2: Daftar Transaksi Pengeluaran
            pw.Text(
              'DAFTAR PENGELUARAN (${detail.transactions.length} Transaksi)',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: textMuted,
                letterSpacing: 0.8,
              ),
            ),
            pw.SizedBox(height: 8),

            if (detail.transactions.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Text('Belum ada transaksi pengeluaran yang dicatat.',
                    style: pw.TextStyle(color: textMuted, fontSize: 10)),
              )
            else
              pw.Table(
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: borderColor, width: 0.5),
                  bottom: pw.BorderSide(color: borderColor, width: 0.8),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(2.5),
                  2: pw.FlexColumnWidth(3.5),
                  3: pw.FlexColumnWidth(2.5),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightBg),
                    children: [
                      _buildCell('Tanggal', isHeader: true),
                      _buildCell('Sumber & Kategori', isHeader: true),
                      _buildCell('Catatan', isHeader: true),
                      _buildCell('Nominal', isHeader: true, alignRight: true),
                    ],
                  ),
                  ...detail.transactions.map((tx) {
                    final accName = detail.accounts
                        .where((a) => a.accountId == tx.accountId)
                        .firstOrNull
                        ?.accountName ??
                        '-';

                    return pw.TableRow(
                      children: [
                        _buildCell(DateFormatter.formatShort(tx.date)),
                        _buildCell(accName),
                        _buildCell(tx.note?.isNotEmpty == true ? tx.note! : '-'),
                        _buildCell('Rp ${_formatRupiah(tx.amount)}',
                            alignRight: true),
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

  static pw.Widget _buildCell(
    String text, {
    bool isHeader = false,
    bool alignRight = false,
    bool highlight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 9,
          fontWeight: isHeader || highlight ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader
              ? PdfColor.fromHex('#64748B')
              : (highlight ? PdfColor.fromHex('#0284C7') : PdfColor.fromHex('#0F172A')),
        ),
      ),
    );
  }

  /// Bagikan file PDF ringkasan liburan via WhatsApp atau media sosial
  static Future<void> sharePdf(BuildContext context, VacationDetail detail) async {
    final bytes = await generatePdfBytes(detail);
    final safeName = detail.vacation.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final fileName = 'Trip_${safeName}_Ringkasan.pdf';

    await Printing.sharePdf(
      bytes: bytes,
      filename: fileName,
    );
  }

  /// Cetak / Pratinjau PDF langsung
  static Future<void> previewOrPrintPdf(BuildContext context, VacationDetail detail) async {
    final bytes = await generatePdfBytes(detail);
    final safeName = detail.vacation.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final fileName = 'Trip_${safeName}_Ringkasan.pdf';

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: fileName,
    );
  }
}
