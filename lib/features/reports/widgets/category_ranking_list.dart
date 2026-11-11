import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/color_helper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../data/repositories/report_repository.dart';

class CategoryRankingList extends StatelessWidget {
  final List<CategoryExpenseShare> categoryExpenses;

  const CategoryRankingList({
    super.key,
    required this.categoryExpenses,
  });

  @override
  Widget build(BuildContext context) {
    if (categoryExpenses.isEmpty) {
      return const SizedBox.shrink();
    }

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Rincian Pos Pengeluaran',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Urut Terbesar',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categoryExpenses.length,
            separatorBuilder: (context, index) =>
                Divider(height: 20, color: Theme.of(context).dividerColor),
            itemBuilder: (context, index) {
              final item = categoryExpenses[index];
              final color = ColorHelper.parseHex(item.colorHex);
              final icon = IconHelper.getIcon(item.iconCodePoint);
              final isTop = index == 0 && item.totalAmount > 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Icon(icon, color: color, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.categoryName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isTop) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.danger.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '🔥 Terbesar',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelSmall.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                CurrencyFormatter.format(item.totalAmount),
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              '${item.percentage.toStringAsFixed(1)}%',
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 11,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress Bar Proporsi
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.percentage / 100,
                      minHeight: 6,
                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

