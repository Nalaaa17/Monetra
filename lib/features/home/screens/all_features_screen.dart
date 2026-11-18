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
    final profileName = activeProfile?.name ?? (isBusiness ? 'Bisnis' : 'Pribadi');

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
              isBusiness ? 'Mode Bisnis • $profileName' : 'Mode Pribadi • $profileName',
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

  // --------------------------------------------------------------------------
  // DAFTAR FITUR: KHUSUS PROFIL BISNIS
  // --------------------------------------------------------------------------
  List<Widget> _buildBusinessSections(BuildContext context, bool isDark) {
    return [
      // 1. OPERASIONAL & TRANSAKSI BISNIS
      _buildSectionHeader(context, 'OPERASIONAL & TRANSAKSI BISNIS'),
      const SizedBox(height: 8),
      _buildFeatureGroup(
        context,
        isDark,
        items: [
          _FeatureItem(
            icon: Icons.inventory_2_rounded,
            title: 'Katalog Produk & Jualan',
            subtitle: 'Daftar menu jualan & kasir cepat',
            onTap: () => context.push(AppRouter.menuCatalog),
          ),
          _FeatureItem(
            icon: Icons.calculate_rounded,
            title: 'Kalkulator HPP & Harga Jual',
            subtitle: 'Hitung modal resep FnB & margin keuntungan',
            onTap: () => context.push(AppRouter.hppCalculator),
          ),
          _FeatureItem(
            icon: Icons.local_offer_outlined,
            title: 'Kalkulator Diskon & Promo',
            subtitle: 'Simulasi promo coret & margin bundling paket',
            onTap: () => context.push(AppRouter.promoCalculator),
          ),
          _FeatureItem(
            icon: Icons.arrow_downward_rounded,
            title: 'Catat Omzet / Pemasukan',
            subtitle: 'Penjualan produk & pendapatan jasa usaha',
            onTap: () => context.push('${AppRouter.addTransaction}?type=income'),
          ),
          _FeatureItem(
            icon: Icons.arrow_upward_rounded,
            title: 'Catat Biaya Usaha',
            subtitle: 'Bahan baku, gaji karyawan & operasional',
            onTap: () => context.push('${AppRouter.addTransaction}?type=expense'),
          ),
          _FeatureItem(
            icon: Icons.swap_horiz_rounded,
            title: 'Transfer Kas Usaha',
            subtitle: 'Pindah dana antar kas toko & rekening bisnis',
            onTap: () => context.push(AppRouter.transfer),
          ),
          _FeatureItem(
            icon: Icons.repeat_rounded,
            title: 'Biaya Rutin Usaha',
            subtitle: 'Sewa tempat, tagihan & langganan rutin',
            onTap: () => context.push(AppRouter.recurring),
          ),
          _FeatureItem(
            icon: Icons.receipt_long_rounded,
            title: 'Buku Kas & Riwayat Mutasi',
            subtitle: 'Semua catatan mutasi omzet & biaya usaha',
            onTap: () => context.push(AppRouter.history),
          ),
        ],
      ),

      const SizedBox(height: 24),

      // 2. ANALISIS & PERFORMA BISNIS
      _buildSectionHeader(context, 'ANALISIS & PERFORMA BISNIS'),
      const SizedBox(height: 8),
      _buildFeatureGroup(
        context,
        isDark,
        items: [
          _FeatureItem(
            icon: Icons.bar_chart_rounded,
            title: 'Laporan Laba Rugi Usaha',
            subtitle: 'Analisis omzet, rasio biaya & tren laba',
            onTap: () => context.push(AppRouter.reports),
          ),
          _FeatureItem(
            icon: Icons.account_balance_outlined,
            title: 'Kalkulator Pajak UMKM 0.5%',
            subtitle: 'Simulasi PPh Final PP 55 & kuota bebas pajak',
            onTap: () => context.push(AppRouter.taxCalculator),
          ),
          _FeatureItem(
            icon: Icons.handshake_outlined,
            title: 'Utang Usaha & Modal',
            subtitle: 'Kewajiban tempo suplier & pinjaman usaha',
            onTap: () => context.push(AppRouter.utang),
          ),
          _FeatureItem(
            icon: Icons.pie_chart_outline_rounded,
            title: 'Batas Anggaran Biaya',
            subtitle: 'Plafon pengeluaran pos operasional usaha',
            onTap: () => context.push(AppRouter.budget),
          ),
          _FeatureItem(
            icon: Icons.calculate_outlined,
            title: 'Kalkulator Uang',
            subtitle: 'Hitung cepat format Rupiah & bagi nota',
            onTap: () => context.push(AppRouter.calculator),
          ),
          _FeatureItem(
            icon: Icons.smart_toy_outlined,
            title: 'AI Advisor Bisnis',
            subtitle: 'Analisis efisiensi biaya operasional',
            badge: 'Segera',
            onTap: () => QuickFeatureModals.showAIAdvisorModal(context),
          ),
        ],
      ),

      const SizedBox(height: 24),

      // 3. PENGATURAN USAHA
      _buildSectionHeader(context, 'DATA & PENGATURAN USAHA'),
      const SizedBox(height: 8),
      _buildFeatureGroup(
        context,
        isDark,
        items: [
          _FeatureItem(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Rekening & Kas Toko',
            subtitle: 'Kas tunai, bank operasional & QRIS usaha',
            onTap: () => context.push(AppRouter.manageAccounts),
          ),
          _FeatureItem(
            icon: Icons.category_outlined,
            title: 'Kategori Pos Usaha',
            subtitle: 'Kustomisasi pos belanja & pendapatan usaha',
            onTap: () => context.push(AppRouter.manageCategories),
          ),
          _FeatureItem(
            icon: Icons.switch_account_rounded,
            title: 'Ganti / Kelola Profil',
            subtitle: 'Beralih ke profil Pribadi atau usaha lain',
            onTap: () => context.push(AppRouter.profiles),
          ),
          _FeatureItem(
            icon: Icons.cloud_sync_outlined,
            title: 'Cadangkan Data Usaha',
            subtitle: 'Ekspor database offline JSON',
            onTap: () => context.push(AppRouter.backup),
          ),
          _FeatureItem(
            icon: Icons.fingerprint_rounded,
            title: 'Kunci Biometrik & PIN',
            subtitle: 'Jaga kerahasiaan pembukuan usaha',
            onTap: () => context.push(AppRouter.securitySettings),
          ),
        ],
      ),
    ];
  }

  // --------------------------------------------------------------------------
  // DAFTAR FITUR: KHUSUS PROFIL PRIBADI
  // --------------------------------------------------------------------------
  List<Widget> _buildPersonalSections(BuildContext context, bool isDark) {
    return [
      // 1. ARUS KAS & TRANSAKSI HARIAN
      _buildSectionHeader(context, 'ARUS KAS & PENGELUARAN HARIAN'),
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
            subtitle: 'Gaji, bonus & pendapatan pribadi',
            onTap: () => context.push('${AppRouter.addTransaction}?type=income'),
          ),
          _FeatureItem(
            icon: Icons.swap_horiz_rounded,
            title: 'Transfer Saldo',
            subtitle: 'Pindah dana antar rekening & e-wallet',
            onTap: () => context.push(AppRouter.transfer),
          ),
          _FeatureItem(
            icon: Icons.repeat_rounded,
            title: 'Transaksi Rutin',
            subtitle: 'Automasi langganan & setoran berkala',
            onTap: () => context.push(AppRouter.recurring),
          ),
          _FeatureItem(
            icon: Icons.receipt_long_rounded,
            title: 'Riwayat Transaksi',
            subtitle: 'Semua mutasi finansial harian',
            onTap: () => context.push(AppRouter.history),
          ),
        ],
      ),

      const SizedBox(height: 24),

      // 2. PERENCANAAN, TABUNGAN & INVESTASI
      _buildSectionHeader(context, 'TABUNGAN, INVESTASI & RENCANA'),
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
            subtitle: 'Impian, beli gadget & dana darurat',
            onTap: () => context.push(AppRouter.goals),
          ),
          _FeatureItem(
            icon: Icons.beach_access_rounded,
            title: 'Kantong Liburan',
            subtitle: 'Sisihkan bujet trip & catat pos liburan',
            onTap: () => context.push(AppRouter.vacations),
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
            subtitle: 'Catatan pinjaman teman & cicilan',
            onTap: () => context.push(AppRouter.utang),
          ),
          _FeatureItem(
            icon: Icons.bar_chart_rounded,
            title: 'Laporan Finansial',
            subtitle: 'Analisis grafik & tren arus kas pribadi',
            onTap: () => context.push(AppRouter.reports),
          ),
          _FeatureItem(
            icon: Icons.calculate_outlined,
            title: 'Kalkulator Uang',
            subtitle: 'Hitung cepat format Rupiah & bagi bill',
            onTap: () => context.push(AppRouter.calculator),
          ),
          _FeatureItem(
            icon: Icons.smart_toy_outlined,
            title: 'AI Advisor',
            subtitle: 'Evaluasi pola pengeluaran pribadi',
            badge: 'Segera',
            onTap: () => QuickFeatureModals.showAIAdvisorModal(context),
          ),
        ],
      ),

      const SizedBox(height: 24),

      // 3. DATA & PENGATURAN PRIBADI
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
            subtitle: 'Kustomisasi pos belanja & pemasukan',
            onTap: () => context.push(AppRouter.manageCategories),
          ),
          _FeatureItem(
            icon: Icons.switch_account_rounded,
            title: 'Profil Pribadi & Bisnis',
            subtitle: 'Buka profil usaha atau beralih akun',
            onTap: () => context.push(AppRouter.profiles),
          ),
          _FeatureItem(
            icon: Icons.cloud_sync_outlined,
            title: 'Cadangkan & Pulihkan',
            subtitle: 'Ekspor database offline JSON',
            onTap: () => context.push(AppRouter.backup),
          ),
          _FeatureItem(
            icon: Icons.fingerprint_rounded,
            title: 'Kunci Biometrik & PIN',
            subtitle: 'Sidik jari, wajah & kunci aplikasi',
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
