import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Menyediakan animasi shimmer tunggal yang dibagikan ke seluruh [SkeletonBox]
/// di bawahnya agar ringan dan sinkron.
class AppShimmer extends StatefulWidget {
  final Widget child;

  const AppShimmer({
    super.key,
    required this.child,
  });

  static Animation<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ShimmerScope>()
        ?.notifier;
  }

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerScope(
      animation: _controller,
      child: widget.child,
    );
  }
}

class _ShimmerScope extends InheritedNotifier<Animation<double>> {
  const _ShimmerScope({
    required Animation<double> animation,
    required super.child,
  }) : super(notifier: animation);
}

/// Elemen placeholder persegi panjang / lingkaran dengan efek kilau shimmer.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final bool isCircle;
  final bool onDarkSurface;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
    this.isCircle = false,
    this.onDarkSurface = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = onDarkSurface
        ? Colors.white.withValues(alpha: 0.10)
        : (isDark ? const Color(0xFF263042) : const Color(0xFFE8ECF2));
    final highlightColor = onDarkSurface
        ? Colors.white.withValues(alpha: 0.22)
        : (isDark ? const Color(0xFF334155) : const Color(0xFFF6F8FB));

    final animation = AppShimmer.maybeOf(context);
    final shape = isCircle ? BoxShape.circle : BoxShape.rectangle;
    final radius = isCircle ? null : BorderRadius.circular(borderRadius);

    if (animation == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          shape: shape,
          borderRadius: radius,
        ),
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final slide = -1.0 + (animation.value * 3.0);
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            shape: shape,
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment(slide - 1.0, -0.3),
              end: Alignment(slide + 1.0, 0.3),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton kartu hero gelap standar Monetra (dipakai di Beranda, Laporan,
/// Rekening, Budget, Goals).
class HeroCardSkeleton extends StatelessWidget {
  final double height;

  const HeroCardSkeleton({super.key, this.height = 166});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppShimmer(
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: height),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161A23) : const Color(0xFF1E2430),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonBox(width: 96, height: 12, onDarkSurface: true),
                SkeletonBox(width: 24, height: 24, isCircle: true, onDarkSurface: true),
              ],
            ),
            const SizedBox(height: 12),
            const SkeletonBox(width: 190, height: 28, borderRadius: 10, onDarkSurface: true),
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.07),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 72, height: 10, onDarkSurface: true),
                      SizedBox(height: 6),
                      SkeletonBox(width: 105, height: 14, onDarkSurface: true),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 72, height: 10, onDarkSurface: true),
                      SizedBox(height: 6),
                      SkeletonBox(width: 105, height: 14, onDarkSurface: true),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton daftar rekening horizontal di Beranda.
class HorizontalAccountsSkeleton extends StatelessWidget {
  const HorizontalAccountsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppShimmer(
      child: SizedBox(
        height: 128,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, _) => Container(
            width: 174,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.dividerOf(context)
                    .withValues(alpha: isDark ? 0.45 : 0.7),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(width: 82, height: 14),
                    SkeletonBox(width: 28, height: 28, borderRadius: 8),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 48, height: 10),
                    SizedBox(height: 6),
                    SkeletonBox(width: 112, height: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton daftar kartu transaksi (dipakai di Beranda).
class TransactionListSkeleton extends StatelessWidget {
  final int count;

  const TransactionListSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppShimmer(
      child: Column(
        children: List.generate(
          count,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.dividerOf(context)
                    .withValues(alpha: isDark ? 0.35 : 0.6),
              ),
            ),
            child: const Row(
              children: [
                SkeletonBox(width: 42, height: 42, borderRadius: 13),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 130, height: 13),
                      SizedBox(height: 6),
                      SkeletonBox(width: 90, height: 10),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                SkeletonBox(width: 78, height: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton grup riwayat harian di HistoryScreen.
class HistoryListSkeleton extends StatelessWidget {
  const HistoryListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = AppColors.dividerOf(context).withValues(alpha: 0.6);

    return AppShimmer(
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: 3,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: dividerColor),
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E2430).withValues(alpha: 0.7)
                      : const Color(0xFFF8FAFC),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(19)),
                  border: Border(bottom: BorderSide(color: dividerColor)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SkeletonBox(width: 120, height: 14),
                        SkeletonBox(width: 64, height: 11),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        SkeletonBox(width: 106, height: 22, borderRadius: 8),
                        SizedBox(width: 8),
                        SkeletonBox(width: 112, height: 22, borderRadius: 8),
                      ],
                    ),
                  ],
                ),
              ),
              ...List.generate(
                index == 0 ? 3 : 2,
                (rowIdx) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const SkeletonBox(width: 38, height: 38, borderRadius: 11),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(
                              width: rowIdx.isEven ? 136 : 108,
                              height: 13,
                            ),
                            const SizedBox(height: 6),
                            const SkeletonBox(width: 84, height: 11),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const SkeletonBox(width: 72, height: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton kartu progres pengeluaran 50/30/20 (Budget & Laporan).
class SpendingProgressCardSkeleton extends StatelessWidget {
  const SpendingProgressCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 64, height: 64, isCircle: true),
              SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 150, height: 16),
                    SizedBox(height: 8),
                    SkeletonBox(width: 96, height: 20, borderRadius: 8),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 22),
          SkeletonBox(width: double.infinity, height: 22, borderRadius: 6),
          SizedBox(height: 14),
          SkeletonBox(width: double.infinity, height: 22, borderRadius: 6),
          SizedBox(height: 14),
          SkeletonBox(width: double.infinity, height: 22, borderRadius: 6),
        ],
      ),
    );
  }
}

/// Skeleton halaman Laporan Keuangan.
class ReportsSkeleton extends StatelessWidget {
  const ReportsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final dividerColor = AppColors.dividerOf(context).withValues(alpha: 0.6);
    return AppShimmer(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          const HeroCardSkeleton(height: 176),
          const SizedBox(height: 12),
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dividerColor),
            ),
            child: const Row(
              children: [
                SkeletonBox(width: 28, height: 28, borderRadius: 8),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(width: 140, height: 13)),
                SizedBox(width: 16),
                SkeletonBox(width: 48, height: 14),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 88,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardOf(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: dividerColor),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(width: 84, height: 11),
                      SkeletonBox(width: 100, height: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 88,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardOf(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: dividerColor),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(width: 84, height: 11),
                      SkeletonBox(width: 100, height: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 220,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: dividerColor),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonBox(width: 160, height: 16),
                Center(child: SkeletonBox(width: 124, height: 124, isCircle: true)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    SkeletonBox(width: 64, height: 12),
                    SkeletonBox(width: 64, height: 12),
                    SkeletonBox(width: 64, height: 12),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 108),
        ],
      ),
    );
  }
}

/// Skeleton halaman Rekening & Dompet.
class ManageAccountsSkeleton extends StatelessWidget {
  const ManageAccountsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final dividerColor = AppColors.dividerOf(context).withValues(alpha: 0.6);
    return AppShimmer(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const HeroCardSkeleton(height: 164),
          const SizedBox(height: 16),
          const Row(
            children: [
              SkeletonBox(width: 88, height: 34, borderRadius: 10),
              SizedBox(width: 8),
              SkeletonBox(width: 84, height: 34, borderRadius: 10),
              SizedBox(width: 8),
              SkeletonBox(width: 96, height: 34, borderRadius: 10),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(
            3,
            (_) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardOf(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: dividerColor),
              ),
              child: const Column(
                children: [
                  Row(
                    children: [
                      SkeletonBox(width: 38, height: 38, borderRadius: 10),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 118, height: 14),
                            SizedBox(height: 6),
                            SkeletonBox(width: 80, height: 12),
                          ],
                        ),
                      ),
                      SkeletonBox(width: 20, height: 20, borderRadius: 6),
                    ],
                  ),
                  SizedBox(height: 12),
                  SkeletonBox(
                    width: double.infinity,
                    height: 46,
                    borderRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton daftar kategori di halaman Budget.
class BudgetCategoriesSkeleton extends StatelessWidget {
  const BudgetCategoriesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final dividerColor = AppColors.dividerOf(context).withValues(alpha: 0.6);
    return AppShimmer(
      child: Column(
        children: List.generate(
          4,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: dividerColor),
            ),
            child: const Column(
              children: [
                Row(
                  children: [
                    SkeletonBox(width: 40, height: 40, borderRadius: 12),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 112, height: 14),
                          SizedBox(height: 6),
                          SkeletonBox(width: 148, height: 11),
                        ],
                      ),
                    ),
                    SkeletonBox(width: 56, height: 14),
                  ],
                ),
                SizedBox(height: 12),
                SkeletonBox(
                  width: double.infinity,
                  height: 7,
                  borderRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton halaman Target Tabungan (Goals).
class GoalsScreenSkeleton extends StatelessWidget {
  const GoalsScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final dividerColor = AppColors.dividerOf(context).withValues(alpha: 0.6);
    return AppShimmer(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const HeroCardSkeleton(height: 138),
          const SizedBox(height: 14),
          Container(
            height: 46,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: dividerColor),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: SkeletonBox(
                    width: double.infinity,
                    height: 36,
                    borderRadius: 10,
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: SkeletonBox(
                    width: double.infinity,
                    height: 36,
                    borderRadius: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(
            3,
            (_) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardOf(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: dividerColor),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(width: 146, height: 15),
                      SkeletonBox(width: 58, height: 22, borderRadius: 8),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(width: 104, height: 17),
                      SkeletonBox(width: 92, height: 12),
                    ],
                  ),
                  SizedBox(height: 10),
                  SkeletonBox(
                    width: double.infinity,
                    height: 6,
                    borderRadius: 4,
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(width: 140, height: 12),
                      SkeletonBox(width: 68, height: 26, borderRadius: 10),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
