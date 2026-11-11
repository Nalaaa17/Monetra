import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/repositories/report_repository.dart';
import '../../home/providers/home_providers.dart';
import '../providers/report_providers.dart';
import '../widgets/category_ranking_list.dart';
import '../widgets/monthly_account_bar_chart.dart';
import '../widgets/monthly_donut_chart.dart';
import '../widgets/six_month_trend_chart.dart';

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
                            const SizedBox(height: 14),

                            // 2 Kartu Metrik: Rata-rata Harian & Hari Terboros
                            _buildDailyMetricsRow(context, report),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: 3,
        backgroundColor: Theme.of(context).cardColor,
        elevation: 4,
        onDestinationSelected: (index) {
          if (index == 0) {
            context.go(AppRouter.home);
          } else if (index == 1) {
            context.push(AppRouter.history);
          } else if (index == 2) {
            context.push(AppRouter.goals);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon:
                Icon(Icons.home_rounded, color: AppColors.primaryDark),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon:
                Icon(Icons.receipt_long_rounded, color: AppColors.primaryDark),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.track_changes_outlined),
            selectedIcon:
                Icon(Icons.track_changes_rounded, color: AppColors.primaryDark),
            label: 'Goal',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon:
                Icon(Icons.bar_chart_rounded, color: AppColors.primaryDark),
            label: 'Laporan',
          ),
        ],
      ),
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
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Bulan Sebelumnya',
            onPressed: () => _changeMonth(selectedDate, -1),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  monthName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Geser kiri / kanan untuk ganti bulan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 10,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
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
    final isSurplus = report.netSavings >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Kolom Total Masuk
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.arrow_downward_rounded,
                            size: 16, color: Color(0xFF059669)),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Pemasukan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.format(report.totalIncome),
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 40, color: Theme.of(context).dividerColor),
              const SizedBox(width: 12),

              // Kolom Total Keluar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.arrow_upward_rounded,
                            size: 16, color: AppColors.danger),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Pengeluaran',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.format(report.totalExpense),
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 24, color: Theme.of(context).dividerColor),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  isSurplus ? 'Sisa Kas (Surplus)' : 'Defisit Bulan Ini',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${isSurplus ? '+' : ''}${CurrencyFormatter.format(report.netSavings)}',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSurplus
                          ? const Color(0xFF059669)
                          : AppColors.danger,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.speed_rounded,
                          size: 16, color: AppColors.primaryDark),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Rata-rata / Hari',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      CurrencyFormatter.format(report.dailyAverageExpense),
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          size: 16, color: AppColors.danger),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Hari Terboros',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      report.highestExpenseAmount > 0
                          ? CurrencyFormatter.format(report.highestExpenseAmount)
                          : 'Rp 0',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                  if (parsedTopDay != null && report.highestExpenseAmount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      DateFormatter.formatShort(parsedTopDay),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 10.5,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.analytics_outlined,
              size: 28,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Belum Ada Catatan di $monthName',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Anda tetap dapat memantau perbandingan tren 6 bulan terakhir di bawah ini.',
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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.analytics_outlined,
                size: 64,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum Ada Catatan di $monthName',
              style: AppTypography.headlineMedium.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Catat pengeluaran dan pemasukan harian Anda untuk melihat grafik analisa pos pengeluaran dan perbandingan dompet di sini.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
