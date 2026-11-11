import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/color_helper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/repositories/report_repository.dart';

class MonthlyAccountBarChart extends StatelessWidget {
  final List<AccountExpenseShare> accountExpenses;

  const MonthlyAccountBarChart({
    super.key,
    required this.accountExpenses,
  });

  @override
  Widget build(BuildContext context) {
    if (accountExpenses.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxVal = accountExpenses.fold<int>(
      0,
      (max, e) => e.totalExpense > max ? e.totalExpense : max,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Pengeluaran Per Dompet/Bank',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.bar_chart_rounded,
                  color: AppColors.primaryDark, size: 20),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal > 0 ? (maxVal * 1.25).toDouble() : 100000,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = accountExpenses[groupIndex];
                      return BarTooltipItem(
                        '${item.accountName}\n${CurrencyFormatter.format(rod.toY.toInt())}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < accountExpenses.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SizedBox(
                              width: 58,
                              child: Text(
                                accountExpenses[index].accountName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: AppTypography.labelSmall.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(accountExpenses.length, (index) {
                  final acc = accountExpenses[index];
                  final color = ColorHelper.parseHex(acc.colorHex);

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: acc.totalExpense.toDouble(),
                        color: color,
                        width: 28,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

