import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/services/receipt_ocr_service.dart';

class ReceiptScanResultSheet extends StatefulWidget {
  final String imagePath;
  final ReceiptOcrResult initialResult;
  final ValueChanged<ReceiptOcrResult> onApply;

  const ReceiptScanResultSheet({
    super.key,
    required this.imagePath,
    required this.initialResult,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required String imagePath,
    required ReceiptOcrResult initialResult,
    required ValueChanged<ReceiptOcrResult> onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReceiptScanResultSheet(
        imagePath: imagePath,
        initialResult: initialResult,
        onApply: onApply,
      ),
    );
  }

  @override
  State<ReceiptScanResultSheet> createState() => _ReceiptScanResultSheetState();
}

class _ReceiptScanResultSheetState extends State<ReceiptScanResultSheet> {
  late int? _selectedAmount;
  late String? _merchantName;
  late String? _category;
  late DateTime? _date;
  late TextEditingController _manualTextController;
  bool _showRawText = false;

  @override
  void initState() {
    super.initState();
    _selectedAmount = widget.initialResult.detectedAmount;
    _merchantName = widget.initialResult.merchantName;
    _category = widget.initialResult.suggestedCategory;
    _date = widget.initialResult.detectedDate;

    _manualTextController = TextEditingController(
      text: widget.initialResult.rawText,
    );
  }

  @override
  void dispose() {
    _manualTextController.dispose();
    super.dispose();
  }

  void _reparseText(String newText) {
    final parsed = ReceiptOcrParser.parseReceiptText(newText);
    setState(() {
      _selectedAmount = parsed.detectedAmount ?? _selectedAmount;
      _merchantName = parsed.merchantName ?? _merchantName;
      _category = parsed.suggestedCategory ?? _category;
      _date = parsed.detectedDate ?? _date;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E222A) : Colors.white;
    final file = File(widget.imagePath);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.document_scanner_rounded,
                    color: AppColors.primaryDark,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hasil Scan Struk',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Nominal Card Utama
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 56,
                      height: 64,
                      child: file.existsSync()
                          ? Image.file(file, fit: BoxFit.cover)
                          : Container(
                              color: Colors.grey.withValues(alpha: 0.2),
                              child: const Icon(Icons.receipt_long),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL TRANSAKSI',
                          style: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _selectedAmount != null
                                ? CurrencyFormatter.format(_selectedAmount!)
                                : 'Tidak terdeteksi',
                            style: AppTypography.headlineMedium.copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: _selectedAmount != null
                                  ? const Color(0xFF059669)
                                  : AppColors.danger,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (_merchantName != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  _merchantName!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            if (_category != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  _category!,
                                  style: AppTypography.labelSmall.copyWith(fontSize: 10),
                                ),
                              ),
                            if (_date != null)
                              Text(
                                DateFormatter.formatShort(_date!),
                                style: AppTypography.labelSmall.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Pilihan Alternatif Angka
            if (widget.initialResult.candidateAmounts.length > 1) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: widget.initialResult.candidateAmounts.map((amt) {
                  final isSelected = amt == _selectedAmount;
                  return ChoiceChip(
                    label: Text(CurrencyFormatter.format(amt), style: const TextStyle(fontSize: 11)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedAmount = amt);
                      }
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.25),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            // Koreksi Manual Toggle
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showRawText = !_showRawText),
                icon: Icon(
                  _showRawText ? Icons.expand_less : Icons.edit_note_rounded,
                  size: 16,
                ),
                label: Text(
                  _showRawText ? 'Sembunyikan Teks OCR' : 'Koreksi Teks OCR',
                  style: const TextStyle(fontSize: 11),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),

            if (_showRawText) ...[
              const SizedBox(height: 6),
              TextField(
                controller: _manualTextController,
                maxLines: 3,
                onChanged: _reparseText,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'Teks dari struk...',
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(height: 10),
            ],

            const SizedBox(height: 14),

            // Tombol Terapkan
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Batal', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _selectedAmount != null && _selectedAmount! > 0
                        ? () {
                            final finalResult = ReceiptOcrResult(
                              detectedAmount: _selectedAmount,
                              merchantName: _merchantName,
                              suggestedCategory: _category,
                              detectedDate: _date,
                              noteSuggestion: _merchantName != null
                                  ? 'Struk $_merchantName'
                                  : 'Belanja struk',
                              rawText: _manualTextController.text,
                            );
                            widget.onApply(finalResult);
                            Navigator.pop(context);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Gunakan Nominal Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
