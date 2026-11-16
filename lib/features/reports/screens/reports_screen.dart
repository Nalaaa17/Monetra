import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/repositories/report_repository.dart';
import '../../home/providers/home_providers.dart';
import '../providers/report_providers.dart';
import '../widgets/category_ranking_list.dart';
import '../widgets/monthly_account_bar_chart.dart';
import '../widgets/monthly_donut_chart.dart';
import '../widgets/six_month_trend_chart.dart';
import '../../home/widgets/spending_progress_card.dart';
import '../../home/widgets/monthly_activity_calendar.dart';
import '../../home/widgets/floating_bottom_bar.dart';
import '../widgets/export_report_sheet.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _slideDirection = 1;

  void _changeMonth(DateTime current, int delta) {
    setState(() => _slideDirection = delta >= 0 ? 1 : -1);
    ref.read(touchedCategoryIndexProvider.notifier).state = null;
    ref.read(selectedReportDateProvider.notifier).state = DateTime(
      current.year,
      current.month + delta,
      1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedReportDateProvider);
    final reportAsync = ref.watch(monthlyReportProvider);
    final trendAsync = ref.watch(sixMonthTrendProvider);

    final monthName = DateFormatter.formatMonthYear(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Laporan Finansial',
          style: AppTypography.headlineMedium.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Ekspor Laporan (PDF / Excel)',
            onPressed: reportAsync.valueOrNull == null
                ? null
                : () {
                    ExportReportSheet.show(
                      context,
                      selectedDate: selectedDate,
                      summary: reportAsync.value!,
                    );
                  },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: () {
              ref.read(homeRefreshTriggerProvider.notifier).state++;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Selector Bulan (Navigasi Kiri / Kanan + Swipe)
          _buildMonthNavigator(context, selectedDate, monthName),

          // 2. Konten Laporan Bulanan dengan animasi geser antar bulan (PRD §4.5)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity > 280) {
                  _changeMonth(selectedDate, -1);
                } else if (velocity < -280) {
                  _changeMonth(selectedDate, 1);
                }
              },
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.read(homeRefreshTriggerProvider.notifier).state++;
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final isIncoming = child.key ==
                        ValueKey('${selectedDate.year}-${selectedDate.month}');
                    final offset = Offset(
                      (isIncoming ? _slideDirection : -_slideDirection) * 0.08,
                      0,
                    );
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: offset,
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey('${selectedDate.year}-${selectedDate.month}'),
                    child: reportAsync.when(
                      data: (report) {
                        final trendPoints = trendAsync.valueOrNull ??
                            const <MonthlyCashflowPoint>[];
                        final hasTrendActivity = trendPoints.any(
                          (p) => p.totalIncome > 0 || p.totalExpense > 0,
                        );

                        if (report.totalIncome == 0 &&
                            report.totalExpense == 0) {
                          if (!hasTrendActivity) {
                            return _buildEmptyMonthState(context, monthName);
                          }
                          return ListView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            children: [
                              _buildEmptyMonthBanner(context, monthName),
                              const SizedBox(height: 16),
                              SixMonthTrendChart(
                                points: trendPoints,
                                selectedYear: selectedDate.year,
                                selectedMonth: selectedDate.month,
                              ),
                              const SizedBox(height: 80),
                            ],
                          );
                        }

                        return ListView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          children: [
                            // Ringkasan Masuk vs Keluar + Net Cashflow
                            _buildCashflowCard(context, report),
                            const SizedBox(height: 12),

                            // Tombol Ekspor Cepat (PDF & Excel/CSV)
                            _buildExportQuickBanner(context, selectedDate, report),
                            const SizedBox(height: 14),

                            // 2 Kartu Metrik: Rata-rata Harian & Hari Terboros
                            _buildDailyMetricsRow(context, report),
                            const SizedBox(height: 18),

                            // Progres Pengeluaran 50/30/20
                            const SpendingProgressCard(),
                            const SizedBox(height: 18),

                            // Aktivitas Bulan Ini (Kalender Keuangan)
                            const MonthlyActivityCalendar(),
                            const SizedBox(height: 20),

                            // Donut Chart Kategori
                            MonthlyDonutChart(
                              categoryExpenses: report.categoryExpenses,
                              totalExpense: report.totalExpense,
                            ),
                            const SizedBox(height: 16),

                            // Rincian Pos Pengeluaran
                            CategoryRankingList(
                              categoryExpenses: report.categoryExpenses,
                            ),
                            const SizedBox(height: 20),

                            // Bar Chart Pengeluaran Per Dompet/Bank
                            MonthlyAccountBarChart(
                              accountExpenses: report.accountExpenses,
                            ),
                            if (hasTrendActivity) ...[
                              const SizedBox(height: 20),
                              SixMonthTrendChart(
                                points: trendPoints,
                                selectedYear: selectedDate.year,
                                selectedMonth: selectedDate.month,
                              ),
                            ],
                            const SizedBox(height: 80),
                          ],
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) =>
                          Center(child: Text('Error laporan: $e')),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const FloatingBottomBar(selectedIndex: 2),
    );
  }

  Widget _buildMonthNavigator(
    BuildContext context,
    DateTime selectedDate,
    String monthName,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.6))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Bulan Sebelumnya',
            onPressed: () => _changeMonth(selectedDate, -1),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 15,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      monthName,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Bulan Berikutnya',
            onPressed: () => _changeMonth(selectedDate, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildCashflowCard(BuildContext context, MonthlyReportSummary report) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSurplus = report.netSavings >= 0;
    final savingsRatio = report.totalIncome > 0
        ? ((report.netSavings / report.totalIncome) * 100).clamp(0, 100).toInt()
        : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161A23) : const Color(0xFF1E2430),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 18,
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
              Flexible(
                child: Text(
                  'ARUS KAS BULANAN',
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white60,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSurplus && report.totalIncome > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34D399).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Rasio Tabungan $savingsRatio%',
                    style: AppTypography.labelSmall.copyWith(
                      color: const Color(0xFF34D399),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${isSurplus ? '+' : ''}${CurrencyFormatter.format(report.netSavings)}',
                    style: AppTypography.headlineMedium.copyWith(
                      color: isSurplus ? const Color(0xFF34D399) : AppColors.danger,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isSurplus ? 'Surplus' : 'Defisit',
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF34D399),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Pemasukan',
                              style: AppTypography.labelSmall.copyWith(color: Colors.white54),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyFormatter.format(report.totalIncome),
                          style: AppTypography.titleSmall.copyWith(
                            color: const Color(0xFF34D399),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Pengeluaran',
                              style: AppTypography.labelSmall.copyWith(color: Colors.white54),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyFormatter.format(report.totalExpense),
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportQuickBanner(
    BuildContext context,
    DateTime selectedDate,
    MonthlyReportSummary report,
  ) {
    return InkWell(
      onTap: () => ExportReportSheet.show(
        context,
        selectedDate: selectedDate,
        summary: report,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.file_download_outlined, size: 18, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Text(
              'Ekspor Laporan (PDF & Excel)',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
            const Spacer(),
            Text(
              'Buka',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppColors.primaryDark),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyMetricsRow(BuildContext context, MonthlyReportSummary report) {
    final parsedTopDay = report.highestExpenseDay != null
        ? DateTime.tryParse(report.highestExpenseDay!)
        : null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rata-rata Pengeluaran Harian
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.speed_rounded,
                          size: 14,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'RATA-RATA / HARI',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      CurrencyFormatter.format(report.dailyAverageExpense),
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Hari Pengeluaran Terbesar
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.local_fire_department_rounded,
                          size: 14,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'HARI TERBOROS',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          report.highestExpenseAmount > 0
                              ? CurrencyFormatter.format(report.highestExpenseAmount)
                              : 'Rp 0',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                      if (parsedTopDay != null && report.highestExpenseAmount > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            DateFormatter.formatShort(parsedTopDay),
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMonthBanner(BuildContext context, String monthName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.analytics_outlined,
              size: 24,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Belum Ada Catatan Bulan Ini',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Grafik tren 6 bulan tetap dapat dipantau di bawah.',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMonthState(BuildContext context, String monthName) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.analytics_outlined,
                size: 52,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Transaksi',
              style: AppTypography.headlineMedium.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              'Catat transaksi untuk melihat grafik analisa finansial bulan ini.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 13,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
