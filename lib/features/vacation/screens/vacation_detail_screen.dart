import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/vacation.dart';
import '../../../data/services/vacation_pdf_service.dart';
import '../../home/providers/home_providers.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../providers/vacation_providers.dart';
import '../widgets/add_vacation_expense_sheet.dart';

class VacationDetailScreen extends ConsumerWidget {
  final int vacationId;

  const VacationDetailScreen({
    super.key,
    required this.vacationId,
  });

  Future<void> _completeVacation(BuildContext context, WidgetRef ref, VacationDetail detail) async {
    final confirm = await AppDialog.confirm(
      context,
      type: AppDialogType.success,
      icon: Icons.beach_access_rounded,
      title: 'Selesaikan Liburan?',
      message:
          'Sisa dana Rp ${CurrencyFormatter.format(detail.remainingBudget)} akan otomatis kembali ke saldo bebas di Beranda.',
      confirmLabel: 'Selesaikan Trip',
      cancelLabel: 'Batal',
    );

    if (confirm == true) {
      final repo = ref.read(vacationRepositoryProvider);
      await repo.completeVacation(vacationId);
      ref.read(vacationRefreshTriggerProvider.notifier).state++;
      ref.read(homeRefreshTriggerProvider.notifier).state++;

      if (context.mounted) {
        AppSnackBar.showSuccess(
          context,
          'Trip selesai! Sisa dana kembali ke saldo bebas.',
        );
      }
    }
  }

  Future<void> _deleteVacation(BuildContext context, WidgetRef ref) async {
    final confirm = await AppDialog.delete(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Hapus Trip?',
      message:
          'Alokasi dana akan dibatalkan dan sisa dana kembali ke rekening asal.',
      confirmLabel: 'Hapus Trip',
    );

    if (confirm == true) {
      final repo = ref.read(vacationRepositoryProvider);
      await repo.deleteVacation(vacationId);
      ref.read(vacationRefreshTriggerProvider.notifier).state++;
      ref.read(homeRefreshTriggerProvider.notifier).state++;

      if (context.mounted) {
        Navigator.pop(context);
        AppSnackBar.showError(context, 'Trip liburan telah dihapus');
      }
    }
  }

  void _openAddExpense(BuildContext context, VacationDetail detail) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: AddVacationExpenseSheet(vacationDetail: detail),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detailAsync = ref.watch(vacationDetailProvider(vacationId));

    return detailAsync.when(
      data: (detail) {
        if (detail == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Trip Liburan')),
            body: const Center(child: Text('Data tidak ditemukan')),
          );
        }

        final vac = detail.vacation;

        return Scaffold(
          backgroundColor: AppColors.surfaceOf(context),
          appBar: AppBar(
            title: Text(
              vac.name,
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Bagikan PDF',
                onPressed: () => VacationPdfService.sharePdf(context, detail),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (val) {
                  if (val == 'share_pdf') {
                    VacationPdfService.sharePdf(context, detail);
                  } else if (val == 'print_pdf') {
                    VacationPdfService.previewOrPrintPdf(context, detail);
                  } else if (val == 'complete') {
                    _completeVacation(context, ref, detail);
                  } else if (val == 'delete') {
                    _deleteVacation(context, ref);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'share_pdf',
                    child: Row(
                      children: [
                        Icon(Icons.share_rounded, color: Color(0xFF0284C7), size: 18),
                        SizedBox(width: 8),
                        Text('Bagikan Ringkasan PDF'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'print_pdf',
                    child: Row(
                      children: [
                        Icon(Icons.print_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Cetak / Pratinjau PDF'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  if (vac.isActive)
                    const PopupMenuItem(
                      value: 'complete',
                      child: Row(
                        children: [
                          Icon(Icons.flag_rounded, color: Color(0xFF0284C7), size: 18),
                          SizedBox(width: 8),
                          Text('Selesaikan Trip'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
                        SizedBox(width: 8),
                        Text('Hapus Trip', style: TextStyle(color: AppColors.danger)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            children: [
              // Hero Card
              _buildHeroCard(context, detail, isDark),
              const SizedBox(height: 14),

              // Burn Rate & Pace Telemetry Card
              _buildBurnRateCard(context, detail, isDark),
              const SizedBox(height: 20),

              // Rincian Bank Liburan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'REKENING TRIP',
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '${detail.accounts.length} Akun',
                    style: AppTypography.labelSmall.copyWith(
                      color: const Color(0xFF0284C7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...detail.accounts.map((acc) => _buildAccountBreakdownCard(context, acc, isDark)),

              const SizedBox(height: 20),

              // Pengeluaran Liburan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MUTASI TRIP',
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '${detail.transactions.length} Pos',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (detail.transactions.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: AppColors.cardOf(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Belum ada pengeluaran trip ini',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                )
              else
                ...detail.transactions.map((tx) => _buildTransactionCard(context, tx, isDark)),
            ],
          ),
          bottomSheet: vac.isActive
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _openAddExpense(context, detail),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'Catat Pos Pengeluaran',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        body: Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, VacationDetail detail, bool isDark) {
    final vac = detail.vacation;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161A23), // Obsidian Monetra Core
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF38BDF8),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    vac.destination ?? 'Trip Aktif',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (vac.isActive ? const Color(0xFF38BDF8) : Colors.grey)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  vac.isActive ? 'AKTIF' : 'SELESAI',
                  style: TextStyle(
                    color: vac.isActive ? const Color(0xFF38BDF8) : Colors.grey,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            'Sisa Bujet Liburan',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Rp ${CurrencyFormatter.format(detail.remainingBudget)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 30,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: detail.spentPercentage,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alokasi Rp ${CurrencyFormatter.format(detail.totalAllocated)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Terpakai Rp ${CurrencyFormatter.format(detail.totalSpent)} (${(detail.spentPercentage * 100).toInt()}%)',
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBurnRateCard(BuildContext context, VacationDetail detail, bool isDark) {
    final vac = detail.vacation;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 1. Kalkulasi Hari
    int totalDays = 1;
    int elapsedDays = 1;
    int remainingDays = 1;

    if (vac.startDate != null && vac.endDate != null) {
      final s = DateTime(vac.startDate!.year, vac.startDate!.month, vac.startDate!.day);
      final e = DateTime(vac.endDate!.year, vac.endDate!.month, vac.endDate!.day);
      totalDays = (e.difference(s).inDays + 1).clamp(1, 365);

      if (today.isBefore(s)) {
        elapsedDays = 0;
        remainingDays = totalDays;
      } else if (today.isAfter(e)) {
        elapsedDays = totalDays;
        remainingDays = 0;
      } else {
        elapsedDays = (today.difference(s).inDays + 1).clamp(1, totalDays);
        remainingDays = (e.difference(today).inDays + 1).clamp(0, totalDays);
      }
    } else {
      final created = DateTime(vac.createdAt.year, vac.createdAt.month, vac.createdAt.day);
      elapsedDays = (today.difference(created).inDays + 1).clamp(1, 365);
      totalDays = elapsedDays;
      remainingDays = 1;
    }

    // 2. Metrik Burn Rate Finansial
    final effectiveElapsed = elapsedDays > 0 ? elapsedDays : 1;
    final dailyBurnRate = detail.totalSpent > 0 ? (detail.totalSpent / effectiveElapsed).round() : 0;

    final effectiveRemaining = remainingDays > 0 ? remainingDays : 1;
    final safeDailyAllowance = detail.remainingBudget > 0
        ? (detail.remainingBudget / effectiveRemaining).round()
        : 0;

    // 3. Status Pace (Aman, Waspada, Boros)
    String paceLabel = 'Pace Aman';
    Color paceColor = const Color(0xFF10B981);
    IconData paceIcon = Icons.check_circle_outline_rounded;

    if (detail.remainingBudget <= 0) {
      paceLabel = 'Bujet Habis';
      paceColor = AppColors.danger;
      paceIcon = Icons.error_outline_rounded;
    } else if (vac.isCompleted) {
      paceLabel = 'Trip Selesai';
      paceColor = const Color(0xFF0284C7);
      paceIcon = Icons.flag_rounded;
    } else if (dailyBurnRate > safeDailyAllowance * 1.25 && dailyBurnRate > 0) {
      paceLabel = 'Pace Boros';
      paceColor = AppColors.danger;
      paceIcon = Icons.trending_up_rounded;
    } else if (dailyBurnRate > safeDailyAllowance && dailyBurnRate > 0) {
      paceLabel = 'Waspada';
      paceColor = const Color(0xFFF59E0B);
      paceIcon = Icons.warning_amber_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.speed_rounded,
                    size: 16,
                    color: Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'TELEMETRI BUJET',
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: paceColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(paceIcon, size: 12, color: paceColor),
                    const SizedBox(width: 4),
                    Text(
                      paceLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: paceColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2 KPI Metric Boxes
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RATA-RATA / HARI',
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 9,
                          letterSpacing: 0.6,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rp ${CurrencyFormatter.format(dailyBurnRate)}',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$elapsedDays hari berjalan',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BATAS AMAN / HARI',
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 9,
                          letterSpacing: 0.6,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rp ${CurrencyFormatter.format(safeDailyAllowance)}',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sisa $remainingDays hari trip',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountBreakdownCard(
      BuildContext context, VacationAccountBreakdown acc, bool isDark) {
    final accColor = Color(int.parse(acc.colorHex));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              IconData(acc.iconCodePoint, fontFamily: 'MaterialIcons'),
              color: accColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  acc.accountName,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Alokasi: Rp ${CurrencyFormatter.format(acc.allocatedAmount)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rp ${CurrencyFormatter.format(acc.remainingAmount)}',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: acc.remainingAmount > 0
                      ? const Color(0xFF0284C7)
                      : AppColors.danger,
                  fontSize: 14,
                ),
              ),
              Text(
                'Sisa Saldo',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
      BuildContext context, dynamic tx, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.north_east_rounded,
                color: AppColors.danger, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.note?.isNotEmpty == true ? tx.note! : 'Pos Liburan',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  DateFormatter.formatRelative(tx.date),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '-Rp ${CurrencyFormatter.format(tx.amount)}',
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}
