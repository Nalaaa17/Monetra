import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../profile/providers/profile_provider.dart';
import '../widgets/quick_feature_modals.dart';

class AllFeaturesScreen extends ConsumerWidget {
  const AllFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeProfile = ref.watch(activeProfileProvider).valueOrNull;
    final isBusiness = activeProfile?.isBusiness ?? false;
    final profileName =
        activeProfile?.name ?? (isBusiness ? 'Bisnis' : 'Pribadi');

    return Scaffold(
      backgroundColor: AppColors.surfaceOf(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Semua Fitur',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            Text(
              isBusiness
                  ? 'Mode Bisnis • $profileName'
                  : 'Mode Pribadi • $profileName',
              style: AppTypography.labelSmall.copyWith(
                fontSize: 11,
                color: isBusiness ? const Color(0xFF3B82F6) : AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: isBusiness
            ? _buildBusinessSections(context, isDark)
            : _buildPersonalSections(context, isDark),
      ),
    );
  }

  List<Widget> _buildBusinessSections(BuildContext context, bool isDark) {
    return [
      _buildSectionHeader(context, 'OPERASIONAL & TRANSAKSI'),
      const SizedBox(height: 8),
      _buildFeatureGrid(
        context,
        isDark,
        items: [
          _FeatureItem(
            icon: Icons.inventory_2_rounded,
            label: 'Katalog',
            color: const Color(0xFF3B82F6),
            onTap: () => context.push(AppRouter.menuCatalog),
          ),
          _FeatureItem(
            icon: Icons.calculate_rounded,
            label: 'Hitung HPP',
            color: const Color(0xFF10B981),
            onTap: () => context.push(AppRouter.hppCalculator),
          ),
          _FeatureItem(
            icon: Icons.local_offer_outlined,
            label: 'Promo',
            color: const Color(0xFFF59E0B),
            onTap: () => context.push(AppRouter.promoCalculator),
          ),
          _FeatureItem(
            icon: Icons.arrow_downward_rounded,
            label: 'Omzet',
            color: const Color(0xFF10B981),
            onTap: () => context.push('${AppRouter.addTransaction}?type=income'),
          ),
          _FeatureItem(
            icon: Icons.arrow_upward_rounded,
            label: 'Biaya',
            color: const Color(0xFFEF4444),
            onTap: () =>
                context.push('${AppRouter.addTransaction}?type=expense'),
          ),
          _FeatureItem(
            icon: Icons.swap_horiz_rounded,
            label: 'Transfer',
            color: const Color(0xFF3B82F6),
            onTap: () => context.push(AppRouter.transfer),
          ),
          _FeatureItem(
            icon: Icons.repeat_rounded,
            label: 'Biaya Rutin',
            color: const Color(0xFF8B5CF6),
            onTap: () => context.push(AppRouter.recurring),
          ),
          _FeatureItem(
            icon: Icons.receipt_long_rounded,
            label: 'Buku Kas',
            color: const Color(0xFF0EA5E9),
            onTap: () => context.push(AppRouter.history),
          ),
        ],
      ),
      const SizedBox(height: 20),
      _buildSectionHeader(context, 'ANALISIS & PERFORMA'),
      const SizedBox(height: 8),
      _buildFeatureGrid(
        context,
        isDark,
        items: [
          _FeatureItem(
            icon: Icons.bar_chart_rounded,
            label: 'Laba Rugi',
            color: const Color(0xFF3B82F6),
            onTap: () => context.push(AppRouter.reports),
          ),
          _FeatureItem(
            icon: Icons.account_balance_outlined,
            label: 'Pajak 0.5%',
            color: const Color(0xFF10B981),
            onTap: () => context.push(AppRouter.taxCalculator),
          ),
          _FeatureItem(
            icon: Icons.handshake_outlined,
            label: 'Utang Usaha',
            color: const Color(0xFFF59E0B),
            onTap: () => context.push(AppRouter.utang),
          ),
          _FeatureItem(
            icon: Icons.pie_chart_outline_rounded,
            label: 'Anggaran',
            color: const Color(0xFFEC4899),
            onTap: () => context.push(AppRouter.budget),
          ),
          _FeatureItem(
            icon: Icons.calculate_outlined,
            label: 'Kalkulator',
            color: const Color(0xFF8B5CF6),
            onTap: () => context.push(AppRouter.calculator),
          ),
          _FeatureItem(
            icon: Icons.smart_toy_outlined,
            label: 'AI Advisor',
            color: const Color(0xFF14B8A6),
            badge: 'Segera',
            onTap: () => QuickFeatureModals.showAIAdvisorModal(context),
          ),
        ],
      ),
      const SizedBox(height: 20),
      _buildSectionHeader(context, 'DATA & PENGATURAN'),
      const SizedBox(height: 8),
      _buildFeatureGrid(
        context,
        isDark,
        items: [
          _FeatureItem(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Rekening',
            color: const Color(0xFF3B82F6),
            onTap: () => context.push(AppRouter.manageAccounts),
          ),
          _FeatureItem(
            icon: Icons.category_outlined,
            label: 'Kategori',
            color: const Color(0xFFF59E0B),
            onTap: () => context.push(AppRouter.manageCategories),
          ),
          _FeatureItem(
            icon: Icons.switch_account_rounded,
            label: 'Profil',
            color: const Color(0xFF8B5CF6),
            onTap: () => context.push(AppRouter.profiles),
          ),
          _FeatureItem(
            icon: Icons.cloud_sync_outlined,
            label: 'Cadangkan',
            color: const Color(0xFF10B981),
            onTap: () => context.push(AppRouter.backup),
          ),
          _FeatureItem(
            icon: Icons.fingerprint_rounded,
            label: 'Keamanan',
            color: const Color(0xFF0EA5E9),
            onTap: () => context.push(AppRouter.securitySettings),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildPersonalSections(BuildContext context, bool isDark) {
    return [
      _buildSectionHeader(context, 'TRANSAKSI HARIAN'),
      const SizedBox(height: 8),
      _buildFeatureGrid(
        context,
        isDark,
        items: [
          _FeatureItem(
            icon: Icons.arrow_upward_rounded,
            label: 'Pengeluaran',
            color: const Color(0xFFEF4444),
            onTap: () =>
                context.push('${AppRouter.addTransaction}?type=expense'),
          ),
          _FeatureItem(
            icon: Icons.arrow_downward_rounded,
            label: 'Pemasukan',
            color: const Color(0xFF10B981),
            onTap: () => context.push('${AppRouter.addTransaction}?type=income'),
          ),
          _FeatureItem(
            icon: Icons.swap_horiz_rounded,
            label: 'Transfer',
            color: const Color(0xFF3B82F6),
            onTap: () => context.push(AppRouter.transfer),
          ),
          _FeatureItem(
            icon: Icons.repeat_rounded,
            label: 'Rutin',
            color: const Color(0xFF8B5CF6),
            onTap: () => context.push(AppRouter.recurring),
          ),
          _FeatureItem(
            icon: Icons.receipt_long_rounded,
            label: 'Riwayat',
            color: const Color(0xFF0EA5E9),
            onTap: () => context.push(AppRouter.history),
          ),
        ],
      ),
      const SizedBox(height: 20),
      _buildSectionHeader(context, 'TABUNGAN & PERENCANAAN'),
      const SizedBox(height: 8),
      _buildFeatureGrid(
        context,
        isDark,
        items: [
          _FeatureItem(
            icon: Icons.pie_chart_outline_rounded,
            label: 'Anggaran',
            color: const Color(0xFFEC4899),
            onTap: () => context.push(AppRouter.budget),
          ),
          _FeatureItem(
            icon: Icons.track_changes_rounded,
            label: 'Target',
            color: const Color(0xFF10B981),
            onTap: () => context.push(AppRouter.goals),
          ),
          _FeatureItem(
            icon: Icons.beach_access_rounded,
            label: 'Liburan',
            color: const Color(0xFF0284C7),
            onTap: () => context.push(AppRouter.vacations),
          ),
          _FeatureItem(
            icon: Icons.trending_up_rounded,
            label: 'Investasi',
            color: const Color(0xFF6366F1),
            onTap: () => context.push(AppRouter.investasi),
          ),
          _FeatureItem(
            icon: Icons.handshake_outlined,
            label: 'Utang',
            color: const Color(0xFFF59E0B),
            onTap: () => context.push(AppRouter.utang),
          ),
          _FeatureItem(
            icon: Icons.bar_chart_rounded,
            label: 'Laporan',
            color: const Color(0xFF3B82F6),
            onTap: () => context.push(AppRouter.reports),
          ),
          _FeatureItem(
            icon: Icons.calculate_outlined,
            label: 'Kalkulator',
            color: const Color(0xFF8B5CF6),
            onTap: () => context.push(AppRouter.calculator),
          ),
          _FeatureItem(
            icon: Icons.smart_toy_outlined,
            label: 'AI Advisor',
            color: const Color(0xFF14B8A6),
            badge: 'Segera',
            onTap: () => QuickFeatureModals.showAIAdvisorModal(context),
          ),
        ],
      ),
      const SizedBox(height: 20),
      _buildSectionHeader(context, 'DATA & PENGATURAN'),
      const SizedBox(height: 8),
      _buildFeatureGrid(
        context,
        isDark,
        items: [
          _FeatureItem(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Rekening',
            color: const Color(0xFF3B82F6),
            onTap: () => context.push(AppRouter.manageAccounts),
          ),
          _FeatureItem(
            icon: Icons.category_outlined,
            label: 'Kategori',
            color: const Color(0xFFF59E0B),
            onTap: () => context.push(AppRouter.manageCategories),
          ),
          _FeatureItem(
            icon: Icons.switch_account_rounded,
            label: 'Profil',
            color: const Color(0xFF8B5CF6),
            onTap: () => context.push(AppRouter.profiles),
          ),
          _FeatureItem(
            icon: Icons.cloud_sync_outlined,
            label: 'Cadangkan',
            color: const Color(0xFF10B981),
            onTap: () => context.push(AppRouter.backup),
          ),
          _FeatureItem(
            icon: Icons.fingerprint_rounded,
            label: 'Keamanan',
            color: const Color(0xFF0EA5E9),
            onTap: () => context.push(AppRouter.securitySettings),
          ),
        ],
      ),
    ];
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: AppTypography.labelSmall.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondaryOf(context),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildFeatureGrid(
    BuildContext context,
    bool isDark, {
    required List<_FeatureItem> items,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.dividerOf(context).withValues(alpha: 0.5),
        ),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 14,
          crossAxisSpacing: 6,
          childAspectRatio: 0.9,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: isDark ? 0.16 : 0.12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        item.icon,
                        size: 22,
                        color: item.color,
                      ),
                    ),
                    if (item.badge != null)
                      Positioned(
                        top: -5,
                        right: -8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.badge!,
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  const _FeatureItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });
}
