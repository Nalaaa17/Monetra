import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../data/services/report_export_service.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';
import '../../profile/providers/profile_provider.dart';

class ExportReportSheet extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final MonthlyReportSummary summary;

  const ExportReportSheet({
    super.key,
    required this.selectedDate,
    required this.summary,
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime selectedDate,
    required MonthlyReportSummary summary,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExportReportSheet(
        selectedDate: selectedDate,
        summary: summary,
      ),
    );
  }

  @override
  ConsumerState<ExportReportSheet> createState() => _ExportReportSheetState();
}

class _ExportReportSheetState extends ConsumerState<ExportReportSheet> {
  bool _isExporting = false;
  String? _statusText;

  @override
  Widget build(BuildContext context) {
    final activeProfile = ref.watch(activeProfileProvider).valueOrNull ??
        ProfileModel(
          key: 'default',
          name: 'Pribadi',
          type: 'personal',
          iconCodePoint: 0xe491,
          colorHex: '0xFF10B981',
          createdAt: DateTime.now(),
        );

    final periodName = DateFormatter.formatMonthYear(widget.selectedDate);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E222A) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.file_download_outlined,
                  color: AppColors.primaryDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ekspor Laporan',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '$periodName • ${activeProfile.name}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isExporting ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isExporting) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _statusText ?? 'Menyiapkan file...',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Card 1: Dokumen PDF Laba Rugi / Keuangan
            _buildExportCard(
              context: context,
              icon: Icons.picture_as_pdf_rounded,
              iconColor: const Color(0xFFEF4444),
              badge: activeProfile.isBusiness ? 'P&L / LABA RUGI' : 'FINANSIAL',
              title: activeProfile.isBusiness ? 'Dokumen PDF Laba Rugi' : 'Dokumen PDF Keuangan',
              actions: [
                OutlinedButton.icon(
                  onPressed: () => _handlePdfAction(activeProfile, isPrint: true),
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Cetak / Pratinjau', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _handlePdfAction(activeProfile, isPrint: false),
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('Bagikan PDF', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Card 2: Spreadsheet Excel / CSV
            _buildExportCard(
              context: context,
              icon: Icons.table_chart_rounded,
              iconColor: const Color(0xFF10B981),
              badge: 'EXCEL / CSV',
              title: 'Data Seluruh Mutasi Transaksi',
              actions: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleCsvAction(activeProfile),
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    label: const Text('Unduh / Bagikan File Excel', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExportCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String badge,
    required String title,
    required List<Widget> actions,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: actions,
          ),
        ],
      ),
    );
  }

  Future<void> _handlePdfAction(ProfileModel profile, {required bool isPrint}) async {
    setState(() {
      _isExporting = true;
      _statusText = isPrint ? 'Membuka pratinjau...' : 'Menyiapkan PDF...';
    });

    try {
      var accounts = ref.read(accountsWithBalanceProvider).valueOrNull;
      if (accounts == null || accounts.isEmpty) {
        accounts = await ref.read(accountRepositoryProvider).getAllAccountsWithBalances();
      }

      if (isPrint) {
        await ReportExportService.previewOrPrintPdf(
          profile: profile,
          year: widget.selectedDate.year,
          month: widget.selectedDate.month,
          summary: widget.summary,
          accounts: accounts,
        );
      } else {
        await ReportExportService.sharePdf(
          profile: profile,
          year: widget.selectedDate.year,
          month: widget.selectedDate.month,
          summary: widget.summary,
          accounts: accounts,
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 2000),
            content: Text('Gagal mengekspor PDF: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleCsvAction(ProfileModel profile) async {
    setState(() {
      _isExporting = true;
      _statusText = 'Menyusun file Excel...';
    });

    try {
      final txRepo = ref.read(transactionRepositoryProvider);
      final startDate = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
      final endDate = DateTime(widget.selectedDate.year, widget.selectedDate.month + 1, 0);

      final transactions = await txRepo.getAllTransactionDetails(
        startDate: startDate,
        endDate: endDate,
      );

      await ReportExportService.shareCsv(
        profile: profile,
        year: widget.selectedDate.year,
        month: widget.selectedDate.month,
        transactions: transactions,
        summary: widget.summary,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 2000),
            content: Text('Gagal mengekspor Excel: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}
