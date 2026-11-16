import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/services/receipt_ocr_service.dart';
import 'receipt_preview_dialog.dart';
import 'receipt_scan_dialog.dart';

class ReceiptAttachmentCard extends StatelessWidget {
  final String? imagePath;
  final ValueChanged<String?> onImageSelected;
  final ValueChanged<ReceiptOcrResult>? onOcrResultApplied;

  const ReceiptAttachmentCard({
    super.key,
    required this.imagePath,
    required this.onImageSelected,
    this.onOcrResultApplied,
  });

  Future<void> _pickImage(
    BuildContext context,
    ImageSource source, {
    bool runOcr = true,
  }) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (picked != null) {
        onImageSelected(picked.path);

        if (runOcr && onOcrResultApplied != null && context.mounted) {
          _triggerOcrScan(context, picked.path);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil foto: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _triggerOcrScan(BuildContext context, String path) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 10),
            Text('Memindai struk belanja...'),
          ],
        ),
        duration: Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final result = await ReceiptOcrService.scanReceipt(path);
    if (!context.mounted) return;

    ReceiptScanResultSheet.show(
      context,
      imagePath: path,
      initialResult: result,
      onApply: onOcrResultApplied!,
    );
  }

  void _showSourceSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E222A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Lampiran Struk Belanja',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Opsi 1: Foto & Scan OCR Otomatis
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.document_scanner_rounded, color: AppColors.primaryDark),
                  ),
                  title: const Text('Foto & Scan Otomatis (OCR)'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'PINTAR',
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(context, ImageSource.camera, runOcr: true);
                  },
                ),

                // Opsi 2: Kamera Biasa
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt_outlined),
                  ),
                  title: const Text('Kamera (Hanya Foto)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(context, ImageSource.camera, runOcr: false);
                  },
                ),

                // Opsi 3: Galeri Gambar
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library_outlined, color: Color(0xFF3B82F6)),
                  ),
                  title: const Text('Pilih dari Galeri'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(context, ImageSource.gallery, runOcr: true);
                  },
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).dividerColor;

    if (imagePath == null || imagePath!.isEmpty) {
      return InkWell(
        onTap: () => _showSourceSheet(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primaryDark,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Foto Struk Belanja',
                style: AppTypography.titleMedium.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Auto-OCR',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.add_a_photo_outlined, size: 18, color: AppColors.textSecondaryOf(context)),
            ],
          ),
        ),
      );
    }

    final file = File(imagePath!);
    final exists = file.existsSync();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Thumbnail with tap to preview
          GestureDetector(
            onTap: () => showReceiptPreviewDialog(
              context,
              imagePath: imagePath!,
              onDelete: () => onImageSelected(null),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 44,
                child: exists
                    ? Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.withValues(alpha: 0.2),
                          child: const Icon(Icons.broken_image, size: 20),
                        ),
                      )
                    : Container(
                        color: Colors.grey.withValues(alpha: 0.2),
                        child: const Icon(Icons.receipt_long, size: 20),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => showReceiptPreviewDialog(
                context,
                imagePath: imagePath!,
                onDelete: () => onImageSelected(null),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 13),
                      const SizedBox(width: 4),
                      Text(
                        'Struk Terlampir',
                        style: AppTypography.titleMedium.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Ketuk untuk perbesar',
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondaryOf(context)),
                  ),
                ],
              ),
            ),
          ),
          if (onOcrResultApplied != null)
            IconButton(
              icon: const Icon(Icons.document_scanner_rounded, size: 18, color: AppColors.primaryDark),
              tooltip: 'Scan OCR',
              onPressed: () => _triggerOcrScan(context, imagePath!),
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Ganti',
            onPressed: () => _showSourceSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
            tooltip: 'Hapus',
            onPressed: () => onImageSelected(null),
          ),
        ],
      ),
    );
  }
}
