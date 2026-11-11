import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/repositories/report_repository.dart';

class SixMonthTrendChart extends StatelessWidget {
  final List<MonthlyCashflowPoint> points;
  final int selectedYear;
  final int selectedMonth;

  const SixMonthTrendChart({
    super.key,
    required this.points,
    required this.selectedYear,
    required this.selectedMonth,
  });

  String _formatCompactAxis(double value) {
    if (value <= 0) return '0';
    if (value >= 1000000000) {
      final m = value / 1000000000;
      return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}M';
    }
    if (value >= 1000000) {
      final jt = value / 1000000;
      return '${jt.toStringAsFixed(jt >= 10 || jt == jt.roundToDouble() ? 0 : 1)}jt';
    }
    if (value >= 1000) {
      return '${(value / 1000).round()}rb';
    }
    return value.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty ||
        !points.any((p) => p.totalIncome > 0 || p.totalExpense > 0)) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final incomeColor =
        isDark ? AppColors.tertiary : const Color(0xFF059669);
    const expenseColor = AppColors.danger;

    int maxVal = 0;
    int sixMonthNet = 0;
    for (final p in points) {
      if (p.totalIncome > maxVal) maxVal = p.totalIncome;
      if (p.totalExpense > maxVal) maxVal = p.totalExpense;
      sixMonthNet += p.net;
    }
    final chartMaxY = maxVal > 0 ? (maxVal * 1.22).toDouble() : 100000.0;

    final comparisonText = _buildMonthComparisonText();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tren 6 Bulan Terakhir',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Perbandingan masuk vs keluar bulanan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (sixMonthNet >= 0 ? incomeColor : expenseColor)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    sixMonthNet >= 0
                        ? 'Hemat +${_formatCompactAxis(sixMonthNet.toDouble())}'
                        : 'Defisit -${_formatCompactAxis(sixMonthNet.abs().toDouble())}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: sixMonthNet >= 0 ? incomeColor : expenseColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Legend
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _buildLegendDot(incomeColor, 'Pemasukan'),
              _buildLegendDot(expenseColor, 'Pengeluaran'),
            ],
          ),
          const SizedBox(height: 16),

          // Grouped Bar Chart
          SizedBox(
            height: 195,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartMaxY,
                groupsSpace: 10,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      if (groupIndex < 0 || groupIndex >= points.length) {
                        return null;
                      }
                      final p = points[groupIndex];
                      final fullMonth = DateFormatter.formatMonthYear(
                        DateTime(p.year, p.month, 1),
                      );
                      final netPrefix = p.net >= 0 ? '+' : '';
                      return BarTooltipItem(
                        '$fullMonth\n'
                        'Masuk: ${CurrencyFormatter.format(p.totalIncome)}\n'
                        'Keluar: ${CurrencyFormatter.format(p.totalExpense)}\n'
                        'Selisih: $netPrefix${CurrencyFormatter.format(p.net)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      );
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: chartMaxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: chartMaxY / 4,
                      getTitlesWidget: (value, meta) {
                        if (value <= 0) {
                          return Text(
                            '0',
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 10,
                              color: AppColors.textSecondaryOf(context),
                            ),
                          );
                        }
                        return Text(
                          _formatCompactAxis(value),
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 10,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final p = points[idx];
                        final isSelected =
                            p.year == selectedYear && p.month == selectedMonth;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            p.label,
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? (isDark
                                      ? AppColors.primary
                                      : AppColors.primaryDark)
                                  : AppColors.textSecondaryOf(context),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(points.length, (i) {
                  final p = points[i];
                  final isSelected =
                      p.year == selectedYear && p.month == selectedMonth;
                  return BarChartGroupData(
                    x: i,
                    barsSpace: 3,
                    barRods: [
                      BarChartRodData(
                        toY: p.totalIncome.toDouble(),
                        color: isSelected
                            ? incomeColor
                            : incomeColor.withValues(alpha: 0.72),
                        width: 9,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: p.totalExpense.toDouble(),
                        color: isSelected
                            ? expenseColor
                            : expenseColor.withValues(alpha: 0.72),
                        width: 9,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),

          if (comparisonText != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface
                    : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.7),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.insights_rounded,
                    size: 16,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      comparisonText,
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 11.5,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(fontSize: 11.5),
        ),
      ],
    );
  }

  String? _buildMonthComparisonText() {
    if (points.length < 2) return null;
    final current = points.last;
    final prev = points[points.length - 2];
    if (prev.totalExpense == 0 && current.totalExpense == 0) return null;

    if (prev.totalExpense == 0 && current.totalExpense > 0) {
      return 'Pengeluaran ${current.label}: ${CurrencyFormatter.format(current.totalExpense)}.';
    }
    final diff = current.totalExpense - prev.totalExpense;
    if (diff < 0) {
      return 'Lebih hemat ${CurrencyFormatter.format(diff.abs())} dibanding pengeluaran ${prev.label}.';
    } else if (diff > 0) {
      return 'Pengeluaran naik ${CurrencyFormatter.format(diff)} dibanding ${prev.label}.';
    }
    return 'Pengeluaran sama persis dengan ${prev.label}.';
  }
}

