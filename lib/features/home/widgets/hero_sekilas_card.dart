import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/home_providers.dart';

class HeroSekilasCard extends ConsumerWidget {
  final BalanceSummary summary;

  const HeroSekilasCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHidden = ref.watch(isBalanceHiddenProvider);
    final isBusiness = ref.watch(activeProfileProvider).valueOrNull?.isBusiness ?? false;
    final todaySummaryAsync = ref.watch(todaySummaryProvider);
    final totalAssets = summary.totalPhysicalNetWorth;
    final hasGoals = summary.allocatedInGoals > 0;
    final hasDebts = summary.allocatedInDebts > 0;
    final hasVacations = summary.allocatedInVacation > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF161A23), // Modern obsidian slate minimalis
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris 1: Label Bersih "Total Aset" & Tombol Sensor
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isBusiness ? 'Kas & Modal Usaha' : 'Total Aset',
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
              InkWell(
                onTap: () {
                  ref.read(isBalanceHiddenProvider.notifier).state = !isHidden;
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isHidden
                        ? Icons.lock_outline_rounded
                        : Icons.lock_open_rounded,
                    color: Colors.white.withValues(alpha: 0.65),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Baris 2: Nominal Utama Besar & Jelas
          Text(
            isHidden ? '••••••••' : CurrencyFormatter.format(totalAssets),
            style: AppTypography.headlineLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 30,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 18),

          // Garis pemisah halus minimalis
          Container(
            height: 1,
            width: double.infinity,
            color: Colors.white.withValues(alpha: 0.07),
          ),

          const SizedBox(height: 14),

          // Baris 3: Profil Bisnis: Omzet & Laba Hari Ini | Profil Pribadi: Uang Harian & Tabungan
          if (isBusiness)
            todaySummaryAsync.when(
              data: (today) {
                final netProfit = today.income - today.expense;
                return Row(
                  children: [
                    // Kolom Omzet Hari Ini
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Omzet Hari Ini',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              isHidden
                                  ? '••••••'
                                  : CurrencyFormatter.format(today.income),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      height: 32,
                      width: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    const SizedBox(width: 16),

                    // Kolom Laba Bersih Hari Ini
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: netProfit >= 0
                                      ? const Color(0xFF3B82F6)
                                      : AppColors.danger,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Laba Bersih Hari Ini',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              isHidden
                                  ? '••••••'
                                  : CurrencyFormatter.format(netProfit),
                              style: TextStyle(
                                color: netProfit >= 0
                                    ? const Color(0xFF60A5FA)
                                    : Colors.redAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(height: 32),
              error: (_, _) => const SizedBox.shrink(),
            )
          else
            Row(
              children: [
                // Kolom Uang Harian
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Uang Harian',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isHidden
                              ? '••••••'
                              : CurrencyFormatter.format(summary.dailySpendingBalance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  height: 32,
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                const SizedBox(width: 16),

                // Kolom Tabungan
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.tertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Tabungan',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isHidden
                              ? '••••••'
                              : CurrencyFormatter.format(summary.savingsBalance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          if (hasGoals || hasDebts || hasVacations) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (hasGoals)
                  _buildAllocatedCard(
                    context: context,
                    label: 'Target Tabungan',
                    amount: summary.allocatedInGoals,
                    icon: Icons.track_changes_rounded,
                    accentColor: const Color(0xFFF59E0B),
                    onTap: () => context.push(AppRouter.goals),
                    isHidden: isHidden,
                  ),
                if (hasGoals && (hasDebts || hasVacations)) const SizedBox(width: 8),
                if (hasDebts)
                  _buildAllocatedCard(
                    context: context,
                    label: 'Cicilan Utang',
                    amount: summary.allocatedInDebts,
                    icon: Icons.account_balance_wallet_outlined,
                    accentColor: const Color(0xFF38BDF8),
                    onTap: () => context.push(AppRouter.utang),
                    isHidden: isHidden,
                  ),
                if (hasDebts && hasVacations) const SizedBox(width: 8),
                if (hasVacations)
                  _buildAllocatedCard(
                    context: context,
                    label: 'Dana Liburan',
                    amount: summary.allocatedInVacation,
                    icon: Icons.beach_access_rounded,
                    accentColor: const Color(0xFF0284C7),
                    onTap: () => context.push(AppRouter.vacations),
                    isHidden: isHidden,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAllocatedCard({
    required BuildContext context,
    required String label,
    required int amount,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
    required bool isHidden,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: accentColor.withValues(alpha: 0.12),
          highlightColor: accentColor.withValues(alpha: 0.06),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1B202B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 15,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isHidden
                              ? '••••••'
                              : CurrencyFormatter.format(amount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
