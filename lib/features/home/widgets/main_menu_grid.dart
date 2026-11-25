import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../../profile/providers/profile_provider.dart';
import 'quick_feature_modals.dart';

class MainMenuGrid extends ConsumerWidget {
  const MainMenuGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBusiness = ref.watch(activeProfileProvider).valueOrNull?.isBusiness ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.dividerOf(context).withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Menu Utama
          Text(
            'Menu Utama',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 18),

          // Grid 2 Baris x 4 Kolom (Disesuaikan otomatis untuk Profil Bisnis vs Pribadi)
          if (isBusiness) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.inventory_2_rounded,
                  label: 'Katalog',
                  color: const Color(0xFF3B82F6),
                  onTap: () => context.push(AppRouter.menuCatalog),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.calculate_rounded,
                  label: 'HPP',
                  color: const Color(0xFF10B981),
                  onTap: () => context.push(AppRouter.hppCalculator),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.point_of_sale_rounded,
                  label: 'Kas Usaha',
                  color: const Color(0xFF0EA5E9),
                  onTap: () => context.push(AppRouter.manageAccounts),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.handshake_outlined,
                  label: 'Utang',
                  color: const Color(0xFFF59E0B),
                  onTap: () => context.push(AppRouter.utang),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.local_offer_outlined,
                  label: 'Promo',
                  color: const Color(0xFF0284C7),
                  onTap: () => context.push(AppRouter.promoCalculator),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.account_balance_outlined,
                  label: 'Pajak',
                  color: const Color(0xFF6366F1),
                  onTap: () => context.push(AppRouter.taxCalculator),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.category_outlined,
                  label: 'Kategori',
                  color: const Color(0xFFEC4899),
                  onTap: () => context.push(AppRouter.manageCategories),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.more_horiz_rounded,
                  label: 'Lainnya',
                  color: const Color(0xFF64748B),
                  onTap: () => context.push(AppRouter.allFeatures),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.pie_chart_outline_rounded,
                  label: 'Budget',
                  color: const Color(0xFFEC4899),
                  onTap: () => context.push(AppRouter.budget),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.beach_access_rounded,
                  label: 'Liburan',
                  color: const Color(0xFF0284C7),
                  onTap: () => context.push(AppRouter.vacations),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.account_balance_rounded,
                  label: 'Aset',
                  color: const Color(0xFF3B82F6),
                  onTap: () => context.push(AppRouter.manageAccounts),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.smart_toy_outlined,
                  label: 'AI Advisor',
                  color: const Color(0xFF14B8A6),
                  badge: 'Soon',
                  onTap: () => QuickFeatureModals.showAIAdvisorModal(context),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.trending_up_rounded,
                  label: 'Investasi',
                  color: const Color(0xFF6366F1),
                  onTap: () => context.push(AppRouter.investasi),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.handshake_outlined,
                  label: 'Utang',
                  color: const Color(0xFFF59E0B),
                  onTap: () => context.push(AppRouter.utang),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.repeat_rounded,
                  label: 'Rutin',
                  color: const Color(0xFF8B5CF6),
                  onTap: () => context.push(AppRouter.recurring),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.more_horiz_rounded,
                  label: 'Lainnya',
                  color: const Color(0xFF64748B),
                  onTap: () => context.push(AppRouter.allFeatures),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.16 : 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: color,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFB800),
                            Color(0xFFF59E0B),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.labelMedium.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

