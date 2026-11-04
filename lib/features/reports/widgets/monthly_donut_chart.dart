import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/repositories/report_repository.dart';
import '../providers/report_providers.dart';

class MonthlyDonutChart extends ConsumerWidget {
  final List<CategoryExpenseShare> categoryExpenses;
  final int totalExpense;

  const MonthlyDonutChart({
    super.key,
    required this.categoryExpenses,
    required this.totalExpense,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (categoryExpenses.isEmpty || totalExpense <= 0) {
      return const SizedBox.shrink();
    }

    final touchedIndex = ref.watch(touchedCategoryIndexProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Komposisi Pengeluaran',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '${categoryExpenses.length} Kategori',
                style: AppTypography.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Donut Chart dengan Informasi Tengah
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          ref.read(touchedCategoryIndexProvider.notifier).state =
                              null;
                          return;
                        }
                        final index = pieTouchResponse
                            .touchedSection!.touchedSectionIndex;
                        if (index >= 0 && index < categoryExpenses.length) {
                          ref.read(touchedCategoryIndexProvider.notifier).state =
                              index;
                        }
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 3,
                    centerSpaceRadius: 65,
                    sections: _buildSections(touchedIndex),
                  ),
                ),
                // Teks di tengah Donut
                _buildCenterInfo(touchedIndex),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections(int? touchedIndex) {
    return List.generate(categoryExpenses.length, (i) {
      final item = categoryExpenses[i];
      final isTouched = i == touchedIndex;
      final radius = isTouched ? 42.0 : 34.0;
      final color = Color(int.parse(item.colorHex));

      return PieChartSectionData(
        color: color,
        value: item.totalAmount.toDouble(),
        title: item.percentage >= 8 ? '${item.percentage.toStringAsFixed(0)}%' : '',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: isTouched ? 14 : 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }

  Widget _buildCenterInfo(int? touchedIndex) {
    if (touchedIndex != null &&
        touchedIndex >= 0 &&
        touchedIndex < categoryExpenses.length) {
      final touchedItem = categoryExpenses[touchedIndex];
      final color = Color(int.parse(touchedItem.colorHex));

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            touchedItem.categoryName,
            style: AppTypography.titleMedium.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            CurrencyFormatter.format(touchedItem.totalAmount),
            style: AppTypography.titleMedium.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${touchedItem.percentage.toStringAsFixed(1)}%',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Total Keluar',
          style: AppTypography.labelSmall.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          CurrencyFormatter.format(totalExpense),
          style: AppTypography.titleMedium.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.danger,
          ),
        ),
      ],
    );
  }
}

