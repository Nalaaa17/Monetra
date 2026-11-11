import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/repositories/goal_repository.dart';
import '../providers/goal_providers.dart';

class HomeGoalPreviewSection extends ConsumerWidget {
  const HomeGoalPreviewSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urgentGoalsAsync = ref.watch(upcomingUrgentGoalsProvider);

    return urgentGoalsAsync.maybeWhen(
      data: (goals) {
        if (goals.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.track_changes_rounded,
                          size: 20, color: AppColors.primaryDark),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Target Mendekati Jatuh Tempo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(AppRouter.goals),
                  child: const Text('Lihat Semua'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...goals.map((goal) => _buildUrgentGoalCard(context, goal)),
            const SizedBox(height: 14),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildUrgentGoalCard(BuildContext context, GoalDetail goal) {
    final progress = (goal.progressPercentage / 100).clamp(0.0, 1.0);
    final days = goal.daysRemaining;
    final deadlineText = days < 0
        ? 'Terlewat!'
        : (days == 0 ? 'Hari Ini!' : '$days hari lagi');

    return InkWell(
      onTap: () => context.push(AppRouter.goals),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: goal.isUrgent
                ? AppColors.danger.withValues(alpha: 0.4)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    goal.name,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: goal.isUrgent
                        ? AppColors.danger.withValues(alpha: 0.12)
                        : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    deadlineText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: goal.isUrgent
                          ? AppColors.danger
                          : AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Terkumpul: ${CurrencyFormatter.format(goal.collectedAmount)}',
                      maxLines: 1,
                      style: AppTypography.labelSmall,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Target: ${CurrencyFormatter.format(goal.targetAmount)}',
                      maxLines: 1,
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(
                  goal.isUrgent ? AppColors.danger : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

