import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../data/repositories/report_repository.dart';
import '../providers/home_providers.dart';

class SpendingProgressCard extends ConsumerWidget {
  const SpendingProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allocationAsync = ref.watch(spendingAllocationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.dividerOf(context).withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: allocationAsync.when(
        data: (allocation) => _buildContent(context, allocation),
        loading: () => const SizedBox(
          height: 140,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => _buildFallback(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context, SpendingAllocation allocation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Baris Header dengan Radial Day Ring yang Rapi & Proporsional
        Row(
          children: [
            _DayProgressRing(
              currentDay: allocation.currentDay,
              totalDays: allocation.totalDaysInMonth,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Progres Pengeluaran',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Hari ${allocation.currentDay} dari ${allocation.totalDaysInMonth}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        // 1. Kebutuhan (Needs)
        _buildProgressBar(
          context,
          label: 'KEBUTUHAN',
          status: allocation.needsStatus,
          percentage: allocation.needsPercentage,
          barColor: const Color(0xFFA78BFA), // Ungu lembut seperti di gambar
        ),

        const SizedBox(height: 16),

        // 2. Keinginan (Wants)
        _buildProgressBar(
          context,
          label: 'KEINGINAN',
          status: allocation.wantsStatus,
          percentage: allocation.wantsPercentage,
          barColor: AppColors.primary, // Emas Amber Monetra
        ),

        const SizedBox(height: 16),

        // 3. Tabungan (Savings)
        _buildProgressBar(
          context,
          label: 'TABUNGAN',
          status: allocation.savingsStatus,
          percentage: allocation.savingsPercentage,
          barColor: AppColors.tertiary, // Mint Emerald Monetra
        ),
      ],
    );
  }

  Widget _buildProgressBar(
    BuildContext context, {
    required String label,
    required String status,
    required double percentage,
    required Color barColor,
  }) {
    final clampedRatio = (percentage / 100).clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryOf(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              '${percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF334155)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(5),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: clampedRatio,
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallback(BuildContext context) {
    final now = DateTime.now();
    return _buildContent(
      context,
      SpendingAllocation(
        needsAmount: 0,
        needsPercentage: 0,
        needsStatus: 'Masih aman',
        wantsAmount: 0,
        wantsPercentage: 0,
        wantsStatus: 'Masih aman',
        savingsAmount: 0,
        savingsPercentage: 0,
        savingsStatus: 'Belum ada',
        currentDay: now.day,
        totalDaysInMonth: DateTime(now.year, now.month + 1, 0).day,
      ),
    );
  }
}

class _DayProgressRing extends StatelessWidget {
  final int currentDay;
  final int totalDays;

  const _DayProgressRing({
    required this.currentDay,
    required this.totalDays,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ratio = totalDays > 0 ? (currentDay / totalDays).clamp(0.0, 1.0) : 0.0;

    return CustomPaint(
      size: const Size(64, 64),
      painter: _DayProgressPainter(
        progress: ratio,
        trackColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        progressColor: isDark ? AppColors.primary : const Color(0xFF94A3B8),
      ),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'HARI',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondaryOf(context),
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$currentDay',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimaryOf(context),
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  _DayProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 4.5;
    final radius = (size.width - strokeWidth) / 2;

    // Track Circle
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc (Starts from top: -pi/2)
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DayProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}
