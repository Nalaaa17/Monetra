import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../widgets/quick_feature_modals.dart';

class AllFeaturesScreen extends StatelessWidget {
  const AllFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.surfaceOf(context),
      appBar: AppBar(
        title: Text(
          'Semua Fitur',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // 1. ARUS KAS & TRANSAKSI
          _buildSectionHeader(context, 'ARUS KAS & TRANSAKSI'),
          const SizedBox(height: 8),
          _buildFeatureGroup(
            context,
            isDark,
            items: [
              _FeatureItem(
                icon: Icons.arrow_upward_rounded,
                title: 'Catat Pengeluaran',
                subtitle: 'Belanja harian, makan & tagihan',
                onTap: () => context.push('${AppRouter.addTransaction}?type=expense'),
              ),
              _FeatureItem(
                icon: Icons.arrow_downward_rounded,
                title: 'Catat Pemasukan',
                subtitle: 'Gaji, hasil bisnis & pendapatan',
                onTap: () => context.push('${AppRouter.addTransaction}?type=income'),
              ),
              _FeatureItem(
                icon: Icons.swap_horiz_rounded,
                title: 'Transfer Saldo',
                subtitle: 'Pindah dana antar rekening',
                onTap: () => context.push(AppRouter.transfer),
              ),
              _FeatureItem(
                icon: Icons.repeat_rounded,
                title: 'Transaksi Rutin',
                subtitle: 'Automasi langganan & setoran',
                onTap: () => context.push(AppRouter.recurring),
              ),
              _FeatureItem(
                icon: Icons.receipt_long_rounded,
                title: 'Riwayat Transaksi',
                subtitle: 'Semua mutasi finansial',
                onTap: () => context.push(AppRouter.history),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 2. PERENCANAAN & ANALITIK
          _buildSectionHeader(context, 'PERENCANAAN & ANALITIK'),
          const SizedBox(height: 8),
          _buildFeatureGroup(
            context,
            isDark,
            items: [
              _FeatureItem(
                icon: Icons.pie_chart_outline_rounded,
                title: 'Anggaran (Budget)',
                subtitle: 'Batas bulanan & rasio 50/30/20',
                onTap: () => context.push(AppRouter.budget),
              ),
              _FeatureItem(
                icon: Icons.track_changes_rounded,
                title: 'Target Tabungan (Goals)',
                subtitle: 'Impian & dana darurat',
                onTap: () => context.push(AppRouter.goals),
              ),
              _FeatureItem(
                icon: Icons.trending_up_rounded,
                title: 'Portofolio Investasi',
                subtitle: 'Reksadana, saham, emas & simulasi',
                onTap: () => context.push(AppRouter.investasi),
              ),
              _FeatureItem(
                icon: Icons.handshake_outlined,
                title: 'Utang & Piutang',
                subtitle: 'Kewajiban & sisa tempo pelunasan',
                onTap: () => context.push(AppRouter.utang),
              ),
              _FeatureItem(
                icon: Icons.bar_chart_rounded,
                title: 'Laporan Finansial',
                subtitle: 'Analisis grafik & tren arus kas',
                onTap: () => context.push(AppRouter.reports),
              ),
              _FeatureItem(
                icon: Icons.calculate_outlined,
                title: 'Kalkulator Uang',
                subtitle: 'Hitung cepat format Rupiah',
                onTap: () => context.push(AppRouter.calculator),
              ),
              _FeatureItem(
                icon: Icons.smart_toy_outlined,
                title: 'AI Advisor',
                subtitle: 'Evaluasi pola pengeluaran',
                badge: 'Segera',
                onTap: () => QuickFeatureModals.showAIAdvisorModal(context),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 3. DATA & PENGATURAN
          _buildSectionHeader(context, 'DATA & PENGATURAN'),
          const SizedBox(height: 8),
          _buildFeatureGroup(
            context,
            isDark,
            items: [
              _FeatureItem(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Kelola Rekening & Dompet',
                subtitle: 'Bank, e-wallet & kas tunai',
                onTap: () => context.push(AppRouter.manageAccounts),
              ),
              _FeatureItem(
                icon: Icons.category_outlined,
                title: 'Kelola Kategori',
                subtitle: 'Kustomisasi pos transaksi',
                onTap: () => context.push(AppRouter.manageCategories),
              ),
              _FeatureItem(
                icon: Icons.cloud_sync_outlined,
                title: 'Cadangkan & Pulihkan',
                subtitle: 'Ekspor database offline JSON',
                onTap: () => context.push(AppRouter.backup),
              ),
            ],
          ),
        ],
      ),
    );
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

  Widget _buildFeatureGroup(
    BuildContext context,
    bool isDark, {
    required List<_FeatureItem> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.dividerOf(context).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;

          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(18) : Radius.zero,
                  bottom: isLast ? const Radius.circular(18) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Modern unified neutral icon box
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF232A38)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.icon,
                          size: 19,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Title & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  item.title,
                                  style: AppTypography.titleSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimaryOf(context),
                                  ),
                                ),
                                if (item.badge != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.badge!,
                                      style: AppTypography.labelSmall.copyWith(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle,
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 11.5,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Chevron
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.textSecondaryOf(context).withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 68,
                  endIndent: 16,
                  color: AppColors.dividerOf(context).withValues(alpha: 0.5),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });
}
