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
import '../../home/providers/home_providers.dart';
import 'goal_contribution_modal.dart';
import 'goal_form_modal.dart';

class GoalCard extends ConsumerWidget {
  final GoalDetail detail;

  const GoalCard({
    super.key,
    required this.detail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDone = detail.isDone;
    final isUrgent = detail.isUrgent;
    final progress = (detail.progressPercentage / 100).clamp(0.0, 1.0);
    final sourceColor = ColorHelper.parseHex(detail.sourceAccountColorHex);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDone
              ? const Color(0xFF059669).withValues(alpha: 0.4)
              : (isUrgent
                  ? AppColors.danger.withValues(alpha: 0.5)
                  : Theme.of(context).dividerColor),
          width: isUrgent || isDone ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Nama Target + Badge Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  detail.name,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: 12),

          // Nominal Progress: Terkumpul vs Target
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Terkumpul', style: AppTypography.labelSmall),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.format(detail.collectedAmount),
                        style: AppTypography.headlineMedium.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDone
                              ? const Color(0xFF059669)
                              : AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Target', style: AppTypography.labelSmall),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        CurrencyFormatter.format(detail.targetAmount),
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDone
                        ? const Color(0xFF059669)
                        : (isUrgent ? AppColors.danger : AppColors.primary),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Bar Info Sumber Dana & Tenggat Waktu (dipisah agar tidak bertabrakan dengan tombol)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    BankLogoHelper.buildAccountBadge(
                      context: context,
                      accountName: detail.sourceAccountName,
                      accountColor: sourceColor,
                      logoKey: detail.sourceAccountLogoKey,
                      iconCodePoint: detail.sourceAccountIconCodePoint,
                      size: 22,
                      iconSize: 12,
                      borderRadius: 6,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        detail.lockedAmount > 0
                            ? 'Terkunci: ${CurrencyFormatter.format(detail.lockedAmount)}'
                            : 'Sumber: ${detail.sourceAccountName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 11.5,
                          color: detail.lockedAmount > 0
                              ? (isDark
                                  ? const Color(0xFFFBBF24)
                                  : const Color(0xFFD97706))
                              : AppColors.textSecondaryOf(context),
                          fontWeight: detail.lockedAmount > 0
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
                    color: isUrgent
                        ? AppColors.danger
                        : AppColors.textSecondaryOf(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormatter.formatShort(detail.deadline),
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 11.5,
                      color: isUrgent
                          ? AppColors.danger
                          : AppColors.textSecondaryOf(context),
                      fontWeight:
                          isUrgent ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          Divider(
            height: 20,
            thickness: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.7),
          ),

          // Footer Aksi Rapi: Isi Tabungan / Pakai + Riwayat (Kiri) & Edit + Hapus (Kanan)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (!isDone)
                      _buildActionPill(
                        onTap: () =>
                            showAddContributionModal(context, ref, detail),
                        icon: Icons.add_circle_outline_rounded,
                        label: 'Isi Tabungan',
                        color: isDark
                            ? AppColors.primary
                            : AppColors.primaryDark,
                        bgColor: AppColors.primary
                            .withValues(alpha: isDark ? 0.22 : 0.14),
                      )
                    else if (detail.lockedAmount > 0)
                      _buildActionPill(
                        onTap: () => _showRealizeOptionsDialog(context, ref),
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Pakai / Bayar',
                        color: const Color(0xFF059669),
                        bgColor: const Color(0xFF059669).withValues(alpha: 0.14),
                      ),
                    if (detail.collectedAmount > 0)
                      _buildActionPill(
                        onTap: () =>
                            showGoalContributionsHistoryModal(context, detail),
                        icon: Icons.receipt_long_rounded,
                        label: 'Riwayat',
                        color: AppColors.textSecondaryOf(context),
                        bgColor: isDark
                            ? AppColors.darkSurfaceElevated
                                .withValues(alpha: 0.55)
                            : const Color(0xFFF3F4F6),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildIconActionButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit Target',
                color: AppColors.textSecondaryOf(context),
                bgColor: isDark
                    ? AppColors.darkSurfaceElevated.withValues(alpha: 0.55)
                    : const Color(0xFFF3F4F6),
                onTap: () =>
                    showGoalFormModal(context, ref, goalDetail: detail),
              ),
              const SizedBox(width: 6),
              _buildIconActionButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Hapus Target',
                color: AppColors.danger,
                bgColor: AppColors.danger.withValues(alpha: isDark ? 0.18 : 0.1),
                onTap: () => _handleDelete(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionPill({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 34,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Center(
              child: Icon(icon, size: 18, color: color),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (detail.isDone) {
      final isSettled =
          detail.collectedAmount > 0 && detail.lockedAmount == 0;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF059669).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isSettled ? 'Sudah Dibayar ✓' : 'Tercapai 🎉',
          style: const TextStyle(
            color: Color(0xFF059669),
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      );
    }

    if (detail.isUrgent) {
      final days = detail.daysRemaining;
      final text = days < 0
          ? 'Terlewat ${days.abs()} hari'
          : (days == 0 ? 'Hari Ini!' : '$days Hari Lagi!');
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '⚠️ $text',
          style: const TextStyle(
            color: AppColors.danger,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${detail.progressPercentage.toStringAsFixed(0)}%',
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Future<void> _showRealizeOptionsDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Gunakan Dana "${detail.name}"?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saat ini ${CurrencyFormatter.format(detail.lockedAmount)} masih tertahan di target ini (terpisah dari saldo bebas pakai).',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFD1FAE5),
                child: Icon(Icons.payments_rounded, color: Color(0xFF059669)),
              ),
              title: const Text('Catat Sudah Dibayar / Dipakai',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text(
                'Catat sebagai pengeluaran di riwayat & lepaskan kuncian target tanpa memotong saldo dua kali.',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await ref
                    .read(goalRepositoryProvider)
                    .realizeGoalAsExpense(detail.id);
                ref.read(homeRefreshTriggerProvider.notifier).state++;
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Target "${detail.name}" dicatat sebagai pengeluaran!'),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                }
              },
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFDBEAFE),
                child: Icon(Icons.undo_rounded, color: Color(0xFF0284C7)),
              ),
              title: const Text('Tarik Kembali ke Saldo Bebas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text(
                'Batalkan penyisihan target dan kembalikan dana menjadi saldo siap pakai di rekening sumber.',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await ref
                    .read(goalRepositoryProvider)
                    .releaseGoalFunds(detail.id);
                ref.read(homeRefreshTriggerProvider.notifier).state++;
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Dana target dikembalikan ke saldo bebas rekening sumber.'),
                      backgroundColor: Color(0xFF0284C7),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _handleDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Target Ini?'),
        content: Text(
          detail.lockedAmount > 0
              ? 'Yakin ingin menghapus target "${detail.name}"?\n\nDana sebesar ${CurrencyFormatter.format(detail.lockedAmount)} yang disisihkan di target ini akan otomatis dikembalikan ke saldo bebas rekening sumber.'
              : 'Yakin ingin menghapus target "${detail.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repo = ref.read(goalRepositoryProvider);
      await repo.deleteGoal(detail.id);
      ref.read(homeRefreshTriggerProvider.notifier).state++;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              detail.lockedAmount > 0
                  ? 'Target dihapus & ${CurrencyFormatter.format(detail.lockedAmount)} dikembalikan ke saldo bebas'
                  : 'Target berhasil dihapus',
            ),
          ),
        );
      }
    }
  }
}
