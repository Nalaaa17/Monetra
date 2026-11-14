import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/repositories/account_repository.dart';
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
    final totalAssets = summary.totalPhysicalNetWorth;
    final hasGoals = summary.allocatedInGoals > 0;

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
                'Total Aset',
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

          // Baris 3: Dua Kolom Ramping: Uang Harian & Tabungan
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
                        Text(
                          'Uang Harian',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isHidden
                          ? '••••••'
                          : CurrencyFormatter.format(summary.dailySpendingBalance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
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
                        Text(
                          'Tabungan',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isHidden
                          ? '••••••'
                          : CurrencyFormatter.format(summary.savingsBalance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (hasGoals) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => context.push(AppRouter.goals),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '🎯 Dana Target',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      isHidden
                          ? '••••••'
                          : CurrencyFormatter.format(summary.allocatedInGoals),
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
