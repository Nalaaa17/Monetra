import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/repositories/report_repository.dart';
import '../../../../data/repositories/transaction_repository.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../providers/home_providers.dart';

class MonthlyActivityCalendar extends ConsumerWidget {
  const MonthlyActivityCalendar({super.key});

  static String _formatCompactAmount(int amount) {
    if (amount >= 1000000000) {
      final val = amount / 1000000000;
      return val == val.roundToDouble()
          ? '${val.toInt()}M'
          : '${val.toStringAsFixed(1)}M';
    }
    if (amount >= 1000000) {
      final val = amount / 1000000;
      return val == val.roundToDouble()
          ? '${val.toInt()}JT'
          : '${val.toStringAsFixed(1)}JT';
    }
    if (amount >= 1000) {
      final val = amount / 1000;
      return val == val.roundToDouble()
          ? '${val.toInt()}RB'
          : '${val.toStringAsFixed(0)}RB';
    }
    return amount.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedCalendarMonthProvider);
    final activityAsync = ref.watch(monthlyDailyActivityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final now = DateTime.now();
    final isCurrentMonth =
        selectedMonth.year == now.year && selectedMonth.month == now.month;

    // Bulan & Tahun
    final monthTitle =
        DateFormatter.formatMonthYear(selectedMonth).toUpperCase();

    // Hitung hari awal dalam kalender (Senin = 1, Minggu = 7)
    final firstDayOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final totalDaysInMonth =
        DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    // weekday: 1 = Senin, ..., 7 = Minggu
    final int startWeekdayOffset = firstDayOfMonth.weekday - 1; // 0 jika Senin

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.dividerOf(context).withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Judul
          Text(
            'Aktivitas Bulan Ini',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle Bulan & Tombol Navigasi Bulan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthTitle,
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondaryOf(context),
                  letterSpacing: 0.6,
                  fontSize: 12.5,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ref.read(selectedCalendarMonthProvider.notifier).state =
                          DateTime(
                        selectedMonth.year,
                        selectedMonth.month - 1,
                        1,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ref.read(selectedCalendarMonthProvider.notifier).state =
                          DateTime(
                        selectedMonth.year,
                        selectedMonth.month + 1,
                        1,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Header Hari: SN, SL, RB, KM, JM, SB, MG
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _WeekdayHeader('SN'),
              _WeekdayHeader('SL'),
              _WeekdayHeader('RB'),
              _WeekdayHeader('KM'),
              _WeekdayHeader('JM'),
              _WeekdayHeader('SB'),
              _WeekdayHeader('MG'),
            ],
          ),

          const SizedBox(height: 10),

          // Grid Kalender
          activityAsync.when(
            data: (dailyMap) => _buildCalendarGrid(
              context,
              ref,
              startWeekdayOffset,
              totalDaysInMonth,
              selectedMonth,
              dailyMap,
              isCurrentMonth ? now.day : -1,
            ),
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Gagal memuat kalender: $err'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    WidgetRef ref,
    int offset,
    int totalDays,
    DateTime selectedMonth,
    Map<int, DailyActivityPoint> dailyMap,
    int todayDay,
  ) {
    final totalCells = offset + totalDays;
    final rowCount = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rowCount, (rowIndex) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (colIndex) {
              final cellIndex = rowIndex * 7 + colIndex;
              final dayNum = cellIndex - offset + 1;

              if (dayNum < 1 || dayNum > totalDays) {
                // Sel kosong di luar bulan
                return const SizedBox(width: 40, height: 48);
              }

              final activity = dailyMap[dayNum];
              final hasExpense = (activity?.expense ?? 0) > 0;
              final hasIncome = (activity?.income ?? 0) > 0;
              final isToday = dayNum == todayDay;

              return _CalendarDayCell(
                dayNum: dayNum,
                isToday: isToday,
                hasExpense: hasExpense,
                hasIncome: hasIncome,
                expenseText: hasExpense
                    ? '-${_formatCompactAmount(activity!.expense)}'
                    : null,
                incomeText: hasIncome
                    ? '+${_formatCompactAmount(activity!.income)}'
                    : null,
                onTap: () => _showDayDetailModal(
                  context,
                  ref,
                  DateTime(selectedMonth.year, selectedMonth.month, dayNum),
                  activity,
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  void _showDayDetailModal(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    DailyActivityPoint? activity,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormatter.formatFull(date),
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Ringkasan Mutasi Harian',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondaryOf(ctx),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.tertiary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pemasukan',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.tertiary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(activity?.income ?? 0),
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pengeluaran',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(activity?.expense ?? 0),
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FutureBuilder<List<TransactionDetail>>(
                future: ref
                    .read(transactionRepositoryProvider)
                    .getTransactionsForDate(date),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final list = snapshot.data ?? [];
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Tidak ada transaksi pada tanggal ini ☕',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondaryOf(ctx),
                          ),
                        ),
                      ),
                    );
                  }
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final tx = list[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: tx.isIncome
                                ? AppColors.tertiary.withValues(alpha: 0.15)
                                : AppColors.danger.withValues(alpha: 0.15),
                            child: Icon(
                              tx.isIncome
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: tx.isIncome
                                  ? AppColors.tertiary
                                  : AppColors.danger,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            tx.categoryName ?? 'Tanpa Kategori',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            tx.accountName,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondaryOf(ctx),
                              fontSize: 11,
                            ),
                          ),
                          trailing: Text(
                            '${tx.isIncome ? '+' : '-'}${CurrencyFormatter.format(tx.amount)}',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w800,
                              color: tx.isIncome
                                  ? AppColors.tertiary
                                  : AppColors.danger,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final String label;
  const _WeekdayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.textSecondaryOf(context),
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int dayNum;
  final bool isToday;
  final bool hasExpense;
  final bool hasIncome;
  final String? expenseText;
  final String? incomeText;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.dayNum,
    required this.isToday,
    required this.hasExpense,
    required this.hasIncome,
    this.expenseText,
    this.incomeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 42,
        height: 52,
        decoration: BoxDecoration(
          color: isToday
              ? (isDark
                  ? const Color(0xFF272F3E)
                  : const Color(0xFFFFF7ED))
              : (hasExpense
                  ? (isDark
                      ? const Color(0xFF231924).withValues(alpha: 0.5)
                      : const Color(0xFFFFF1F2))
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          border: isToday
              ? Border.all(
                  color: AppColors.primary,
                  width: 1.6,
                )
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNum',
              style: AppTypography.labelMedium.copyWith(
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
                color: isToday
                    ? AppColors.primaryDark
                    : AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 2),
            if (expenseText != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  expenseText!,
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 8.5,
                  ),
                ),
              ),
            if (incomeText != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  incomeText!,
                  style: TextStyle(
                    color: AppColors.tertiary,
                    fontWeight: FontWeight.w700,
                    fontSize: 8.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

