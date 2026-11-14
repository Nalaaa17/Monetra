import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';

class FloatingBottomBar extends StatefulWidget {
  final int selectedIndex;

  const FloatingBottomBar({
    super.key,
    required this.selectedIndex,
  });

  @override
  State<FloatingBottomBar> createState() => _FloatingBottomBarState();
}

class _FloatingBottomBarState extends State<FloatingBottomBar> {
  int? _pressingIndex;

  void _onTabSelected(int index) {
    if (index == widget.selectedIndex) return;

    switch (index) {
      case 0:
        context.go(AppRouter.home);
        break;
      case 1:
        context.go(AppRouter.history);
        break;
      case 2:
        context.go(AppRouter.reports);
        break;
      case 3:
        context.go(AppRouter.goals);
        break;
    }
  }

  void _showAddActionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161A23) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    color: AppColors.danger,
                    size: 22,
                  ),
                ),
                title: Text(
                  'Catat Pengeluaran',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryOf(ctx),
                  ),
                ),
                subtitle: Text(
                  'Makan, bensin, belanja, tagihan bulanan...',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryOf(ctx),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRouter.addTransaction, extra: {'type': 'expense'});
                },
              ),
              const SizedBox(height: 4),
              Divider(height: 1, color: AppColors.dividerOf(ctx).withValues(alpha: 0.5)),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.arrow_downward_rounded,
                    color: AppColors.tertiary,
                    size: 22,
                  ),
                ),
                title: Text(
                  'Catat Pemasukan',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryOf(ctx),
                  ),
                ),
                subtitle: Text(
                  'Gaji, bonus, imbal hasil, penjualan...',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryOf(ctx),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRouter.addTransaction, extra: {'type': 'income'});
                },
              ),
              const SizedBox(height: 4),
              Divider(height: 1, color: AppColors.dividerOf(ctx).withValues(alpha: 0.5)),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: AppColors.secondary,
                    size: 22,
                  ),
                ),
                title: Text(
                  'Transfer Antar Rekening',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryOf(ctx),
                  ),
                ),
                subtitle: Text(
                  'Pindah saldo kas harian ke tabungan atau sebaliknya',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryOf(ctx),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRouter.transfer);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        height: 68,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161A23) : Colors.white,
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: AppColors.dividerOf(context).withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 0. HOME / DASHBOARD
              _buildAnimatedTabItem(
                context,
                index: 0,
                selectedIcon: Icons.grid_view_rounded,
                unselectedIcon: Icons.grid_view_outlined,
                label: 'Home',
              ),

              // 1. RIWAYAT TRANSAKSI
              _buildAnimatedTabItem(
                context,
                index: 1,
                selectedIcon: Icons.receipt_long_rounded,
                unselectedIcon: Icons.receipt_long_outlined,
                label: 'Riwayat',
              ),

              // TOMBOL TENGAH (+) AKSI CEPAT
              _buildCenterActionButton(context),

              // 2. LAPORAN FINANSIAL
              _buildAnimatedTabItem(
                context,
                index: 2,
                selectedIcon: Icons.bar_chart_rounded,
                unselectedIcon: Icons.bar_chart_outlined,
                label: 'Laporan',
              ),

              // 3. TARGET & TABUNGAN (GOALS)
              _buildAnimatedTabItem(
                context,
                index: 3,
                selectedIcon: Icons.track_changes_rounded,
                unselectedIcon: Icons.track_changes_outlined,
                label: 'Goals',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedTabItem(
    BuildContext context, {
    required int index,
    required IconData selectedIcon,
    required IconData unselectedIcon,
    required String label,
  }) {
    final isSelected = widget.selectedIndex == index;
    final isPressing = _pressingIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressingIndex = index),
      onTapUp: (_) => setState(() => _pressingIndex = null),
      onTapCancel: () => setState(() => _pressingIndex = null),
      onTap: () => _onTabSelected(index),
      child: AnimatedScale(
        scale: isPressing ? 0.90 : (isSelected ? 1.08 : 1.0),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 14 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    width: 1.2,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: child,
                ),
                child: Icon(
                  isSelected ? selectedIcon : unselectedIcon,
                  key: ValueKey<bool>(isSelected),
                  size: isSelected ? 24 : 22,
                  color: isSelected
                      ? AppColors.primaryDark
                      : AppColors.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: 3),
              // Micro dot indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: isSelected ? 12 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterActionButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAddActionModal(context),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFB800), // Primary Monetra Amber
              Color(0xFFF59E0B), // Primary Dark
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.black87,
          size: 28,
        ),
      ),
    );
  }
}
