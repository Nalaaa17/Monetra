import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/bank_logo_helper.dart';
import '../../../../core/utils/color_helper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/repositories/goal_repository.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../home/providers/home_providers.dart';
import 'goal_contribution_modal.dart';
import 'goal_form_modal.dart';

class GoalCard extends ConsumerWidget {
  final GoalDetail detail;

  const GoalCard({super.key, required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = detail.isDone;
    final isUrgent = detail.isUrgent;
    final progress = (detail.progressPercentage / 100).clamp(0.0, 1.0);
    final sourceColor = ColorHelper.parseHex(detail.sourceAccountColorHex);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDone
              ? AppColors.tertiary.withValues(alpha: 0.4)
              : (isUrgent
                    ? AppColors.danger.withValues(alpha: 0.5)
                    : AppColors.dividerOf(context)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Header + Status + More Menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  detail.name,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      (isDone
                              ? AppColors.tertiary
                              : (isUrgent
                                    ? AppColors.danger
                                    : AppColors.primary))
                          .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isDone
                      ? 'Tercapai 🎉'
                      : (isUrgent
                            ? 'Mendekati Tempo'
                            : '${(progress * 100).toInt()}%'),
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDone
                        ? AppColors.tertiary
                        : (isUrgent ? AppColors.danger : AppColors.primaryDark),
                  ),
                ),
              ),

              // 3-dots popup
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: AppColors.textSecondaryOf(context),
                ),
                onSelected: (val) {
                  if (val == 'history') {
                    showGoalContributionsHistoryModal(context, detail);
                  } else if (val == 'edit') {
                    showGoalFormModal(context, ref, goalDetail: detail);
                  } else if (val == 'delete') {
                    _handleDelete(context, ref);
                  }
                },
                itemBuilder: (ctx) => [
                  if (detail.collectedAmount > 0)
                    const PopupMenuItem(
                      value: 'history',
                      child: Text('Riwayat Alokasi'),
                    ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit Target'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Hapus Target',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Row 2: Nominal Terkumpul / Target
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.format(detail.collectedAmount),
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDone
                          ? AppColors.tertiary
                          : AppColors.textPrimaryOf(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Target ${CurrencyFormatter.format(detail.targetAmount)}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.dividerOf(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDone
                    ? AppColors.tertiary
                    : (isUrgent ? AppColors.danger : AppColors.primary),
              ),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 12),

          // Row 3: Meta & Quick Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Sumber Akun & Deadline
              Expanded(
                child: Row(
                  children: [
                    BankLogoHelper.buildAccountBadge(
                      context: context,
                      accountName: detail.sourceAccountName,
                      accountColor: sourceColor,
                      logoKey: detail.sourceAccountLogoKey,
                      iconCodePoint: detail.sourceAccountIconCodePoint,
                      size: 16,
                      iconSize: 10,
                      borderRadius: 4,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        detail.sourceAccountName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '•',
                        style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 11,
                      color: isUrgent
                          ? AppColors.danger
                          : AppColors.textSecondaryOf(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormatter.formatShort(detail.deadline),
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 11,
                        color: isUrgent
                            ? AppColors.danger
                            : AppColors.textSecondaryOf(context),
                        fontWeight: isUrgent
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Action button
              if (!isDone)
                InkWell(
                  onTap: () => showAddContributionModal(context, ref, detail),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add,
                          size: 14,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Setor',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (detail.lockedAmount > 0)
                InkWell(
                  onTap: () => _showRealizeOptionsDialog(context, ref),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.tertiary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check,
                          size: 14,
                          color: AppColors.tertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Pakai Dana',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.tertiary,
                            fontWeight: FontWeight.bold,
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

  void _showRealizeOptionsDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.confirm(
      context,
      type: AppDialogType.success,
      icon: Icons.check_circle_outline_rounded,
      title: 'Realisasi Target',
      message:
          'Target "${detail.name}" telah tercapai. Buka kunci saldo ${CurrencyFormatter.format(detail.lockedAmount)} untuk digunakan?',
      confirmLabel: 'Gunakan Saldo',
      cancelLabel: 'Batal',
    );

    if (confirmed) {
      await ref.read(goalRepositoryProvider).realizeGoalAsExpense(detail.id);
      ref.read(homeRefreshTriggerProvider.notifier).state++;
    }
  }

  void _handleDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.delete(
      context,
      title: 'Hapus Target?',
      message:
          'Target "${detail.name}" akan dihapus. Saldo yang telah dialokasikan akan dikembalikan ke akun sumber.',
      confirmLabel: 'Hapus Target',
    );

    if (confirmed) {
      await ref.read(goalRepositoryProvider).deleteGoal(detail.id);
      ref.read(homeRefreshTriggerProvider.notifier).state++;
    }
  }
}
