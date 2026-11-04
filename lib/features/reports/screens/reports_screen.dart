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

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedReportDateProvider);
    final reportAsync = ref.watch(monthlyReportProvider);

    final monthName = DateFormatter.formatMonthYear(selectedDate);

    return Scaffold(
      backgroundColor: AppColors.surface,
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
          // 1. Selector Bulan (Navigasi Kiri / Kanan)
          _buildMonthNavigator(context, ref, selectedDate, monthName),

          // 2. Konten Laporan Bulanan
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.read(homeRefreshTriggerProvider.notifier).state++;
              },
              child: reportAsync.when(
                data: (report) {
                  if (report.totalIncome == 0 && report.totalExpense == 0) {
                    return _buildEmptyMonthState(monthName);
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    children: [
                      // Ringkasan Masuk vs Keluar + Net Cashflow
                      _buildCashflowCard(report),
                      const SizedBox(height: 14),

                      // 2 Kartu Metrik: Rata-rata Harian & Hari Terboros
                      _buildDailyMetricsRow(report),
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
                      const SizedBox(height: 80),
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error laporan: $e')),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 3,
        backgroundColor: AppColors.surfaceCard,
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
    WidgetRef ref,
    DateTime selectedDate,
    String monthName,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Bulan Sebelumnya',
            onPressed: () {
              ref.read(selectedReportDateProvider.notifier).state = DateTime(
                selectedDate.year,
                selectedDate.month - 1,
                1,
              );
            },
          ),
          Text(
            monthName,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Bulan Berikutnya',
            onPressed: () {
              ref.read(selectedReportDateProvider.notifier).state = DateTime(
                selectedDate.year,
                selectedDate.month + 1,
                1,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCashflowCard(MonthlyReportSummary report) {
    final isSurplus = report.netSavings >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
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
                        Text('Pemasukan',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      CurrencyFormatter.format(report.totalIncome),
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.divider),
              const SizedBox(width: 16),

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
                        Text('Pengeluaran',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.danger)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      CurrencyFormatter.format(report.totalExpense),
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.divider),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSurplus ? 'Sisa Kas (Surplus)' : 'Defisit Bulan Ini',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${isSurplus ? '+' : ''}${CurrencyFormatter.format(report.netSavings)}',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isSurplus ? const Color(0xFF059669) : AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyMetricsRow(MonthlyReportSummary report) {
    return Row(
      children: [
        // Rata-rata Pengeluaran Harian
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.speed_rounded,
                        size: 16, color: AppColors.primaryDark),
                    SizedBox(width: 6),
                    Text('Rata-rata / Hari',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyFormatter.format(report.dailyAverageExpense),
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
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
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.local_fire_department_rounded,
                        size: 16, color: AppColors.danger),
                    SizedBox(width: 6),
                    Text('Hari Terboros',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  report.highestExpenseAmount > 0
                      ? CurrencyFormatter.format(report.highestExpenseAmount)
                      : 'Rp 0',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyMonthState(String monthName) {
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
              style: AppTypography.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
