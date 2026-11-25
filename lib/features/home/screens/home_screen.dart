import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/bank_logo_helper.dart';
import '../../../core/utils/color_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/icon_helper.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/widgets/animated_currency.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../../goals/widgets/home_goal_preview_section.dart';
import '../../history/providers/history_providers.dart';
import '../../onboarding/providers/onboarding_providers.dart';
import '../../profile/providers/profile_provider.dart';
import '../../profile/widgets/profile_switcher_sheet.dart';
import '../../security/providers/security_providers.dart';
import '../../transaction/screens/edit_transaction_screen.dart';
import '../providers/home_providers.dart';
import '../widgets/hero_sekilas_card.dart';
import '../widgets/main_menu_grid.dart';
import '../widgets/quick_feature_modals.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceSummaryAsync = ref.watch(balanceSummaryProvider);
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final recentTransactionsAsync = ref.watch(recentTransactionsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final userName = ref.watch(userNameProvider);
    final activeProfile = ref.watch(activeProfileProvider).valueOrNull;
    final profileLabels = ref.watch(profileLabelsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            // Dropdown Switcher Profil di Header Home
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => ProfileSwitcherSheet.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      profileLabels.iconData,
                      size: 16,
                      color: ColorHelper.fromHex(
                        activeProfile?.colorHex ?? '0xFF10B981',
                      ),
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        activeProfile?.name ?? 'Pribadi',
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 18,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Dark Mode Toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
              color: isDark ? AppColors.primary : AppColors.textPrimary,
              size: 21,
            ),
            tooltip: isDark ? 'Mode Cerah' : 'Mode Gelap',
            onPressed: () {
              ref.read(themeModeProvider.notifier).state =
                  isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),

          // Menu Lengkap Semua Fitur Monetra (Titik 3)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Semua Fitur Monetra',
            onSelected: (val) {
              if (val == 'transfer') {
                context.push(AppRouter.transfer);
              } else if (val == 'backup') {
                context.push(AppRouter.backup);
              } else if (val == 'recurring') {
                context.push(AppRouter.recurring);
              } else if (val == 'calculator') {
                context.push(AppRouter.calculator);
              } else if (val == 'goals') {
                context.push(AppRouter.goals);
              } else if (val == 'reports') {
                context.push(AppRouter.reports);
              } else if (val == 'history') {
                ref.read(historyFilterProvider.notifier).state =
                    const HistoryFilter();
                context.push(AppRouter.history);
              } else if (val == 'accounts') {
                context.push(AppRouter.manageAccounts);
              } else if (val == 'categories') {
                context.push(AppRouter.manageCategories);
              } else if (val == 'profiles') {
                context.push(AppRouter.profiles);
              } else if (val == 'advisor') {
                QuickFeatureModals.showAIAdvisorModal(context);
              } else if (val == 'lock') {
                ref.read(isQuickAccessActiveProvider.notifier).state = false;
                ref.read(isAppLockedProvider.notifier).state = true;
              } else if (val == 'about') {
                _showAboutMonetraDialog(context);
              }
            },
            itemBuilder: (ctx) => [
              _buildPopupMenuItem('transfer', Icons.swap_horiz_rounded,
                  const Color(0xFF3B82F6), 'Transfer Saldo'),
              _buildPopupMenuItem('backup', Icons.cloud_sync_outlined,
                  const Color(0xFF10B981), 'Cadangkan & Pulihkan'),
              const PopupMenuDivider(),
              _buildPopupMenuItem('recurring', Icons.repeat_rounded,
                  const Color(0xFF8B5CF6), 'Transaksi Berulang'),
              _buildPopupMenuItem('calculator', Icons.calculate_outlined,
                  const Color(0xFF8B5CF6), 'Kalkulator'),
              _buildPopupMenuItem('goals', Icons.track_changes_rounded,
                  const Color(0xFF10B981), 'Target Tabungan'),
              _buildPopupMenuItem('reports', Icons.bar_chart_rounded,
                  const Color(0xFF3B82F6), 'Laporan Keuangan'),
              _buildPopupMenuItem('history', Icons.receipt_long_rounded,
                  const Color(0xFF0EA5E9), 'Riwayat Transaksi'),
              const PopupMenuDivider(),
              _buildPopupMenuItem(
                  'accounts',
                  Icons.account_balance_wallet_outlined,
                  const Color(0xFF3B82F6),
                  'Kelola Rekening'),
              _buildPopupMenuItem('categories', Icons.category_outlined,
                  const Color(0xFFF59E0B), 'Kelola Kategori'),
              _buildPopupMenuItem('profiles', Icons.switch_account_rounded,
                  const Color(0xFF8B5CF6), 'Kelola Profil'),
              const PopupMenuDivider(),
              _buildPopupMenuItem('lock', Icons.lock_outline_rounded,
                  const Color(0xFF0EA5E9), 'Kunci Layar'),
              _buildPopupMenuItem('about', Icons.info_outline_rounded,
                  const Color(0xFF64748B), 'Tentang Monetra'),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.read(homeRefreshTriggerProvider.notifier).state++;
          await Future.wait([
            ref.refresh(balanceSummaryProvider.future),
            ref.refresh(accountsWithBalanceProvider.future),
            ref.refresh(recentTransactionsProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Greeting Ringkas & Bersih
            Text(
              'Halo, $userName',
              style: AppTypography.headlineLarge.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 24,
                letterSpacing: -0.4,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),

            // 1. Hero Card: Sekilas Hari Ini (Sesuai Referensi Gambar 1)
            balanceSummaryAsync.when(
              data: (summary) => HeroSekilasCard(summary: summary),
              loading: () => const HeroCardSkeleton(),
              error: (err, _) => Text('Gagal memuat saldo: $err'),
            ),
            const SizedBox(height: 18),

            // 2. Menu Utama Pintasan 8 Aksi Cepat (Sesuai Referensi Gambar 1)
            const MainMenuGrid(),
            const SizedBox(height: 18),

            // Preview Goal Mendekati Jatuh Tempo (PRD §6.4)
            const HomeGoalPreviewSection(),
            const SizedBox(height: 12),

            // 8. Horizontal Accounts List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Dompet & Rekening',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleLarge,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => context.push(AppRouter.manageAccounts),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Kelola'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            accountsAsync.when(
              data: (accounts) =>
                  _buildAccountsHorizontalList(context, ref, accounts),
              loading: () => const HorizontalAccountsSkeleton(),
              error: (err, _) => Text('Error: $err'),
            ),

            const SizedBox(height: 24),

            // 9. Section Transaksi Terakhir
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    profileLabels.recentTransactionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleLarge,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    ref.read(historyFilterProvider.notifier).state =
                        const HistoryFilter();
                    context.push(AppRouter.history);
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Lihat Semua'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            recentTransactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return _buildEmptyTransactionsState(context, profileLabels);
                }
                return Column(
                  children: transactions
                      .map((tx) => _buildTransactionItem(context, tx))
                      .toList(),
                );
              },
              loading: () => const TransactionListSkeleton(),
              error: (err, _) => Text('Error transaksi: $err'),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(
    String value,
    IconData icon,
    Color color,
    String title,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsHorizontalList(
    BuildContext context,
    WidgetRef ref,
    List<AccountWithBalance> accounts,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = accounts[index];
          final color = ColorHelper.parseHex(item.colorHex);
          final hasLock = item.totalAllocated > 0;

          return Material(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                ref.read(historyFilterProvider.notifier).state =
                    HistoryFilter(accountId: item.id);
                context.push(AppRouter.history);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 174,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        BankLogoHelper.buildAccountBadge(
                          context: context,
                          accountName: item.name,
                          accountColor: color,
                          logoKey: item.logoKey,
                          iconCodePoint: item.iconCodePoint,
                          size: 28,
                          iconSize: 16,
                          borderRadius: 8,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasLock ? 'Total Fisik' : 'Saldo',
                          style: AppTypography.labelSmall.copyWith(fontSize: 11.5),
                        ),
                        const SizedBox(height: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AnimatedCurrency(
                            amount: item.physicalBalance,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (hasLock)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Bebas: ${CurrencyFormatter.format(item.balance)}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFF0284C7),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, TransactionDetail tx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = tx.isIncome;
    final sign = isIncome ? '+' : '-';
    final amountColor = isIncome ? const Color(0xFF10B981) : AppColors.danger;
    final catColor = tx.categoryColorHex != null
        ? ColorHelper.parseHex(tx.categoryColorHex!)
        : amountColor;
    final catIcon = tx.categoryIconCodePoint != null
        ? IconHelper.getIcon(tx.categoryIconCodePoint!)
        : (isIncome
            ? Icons.savings_outlined
            : Icons.shopping_bag_outlined);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          AppRouter.buildSmoothRoute(EditTransactionScreen(detail: tx)),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context)
                .dividerColor
                .withValues(alpha: isDark ? 0.35 : 0.6),
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: isDark ? 0.18 : 0.13),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    catIcon,
                    color: catColor,
                    size: 21,
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: amountColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.cardOf(context),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isIncome ? Icons.add_rounded : Icons.remove_rounded,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.note?.isNotEmpty == true
                        ? tx.note!
                        : (tx.categoryName ??
                            (isIncome ? 'Pemasukan' : 'Pengeluaran')),
                    style: AppTypography.titleMedium.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${tx.accountName} • ${DateFormatter.formatShort(tx.date)}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$sign${CurrencyFormatter.format(tx.amount)}',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTransactionsState(BuildContext context, ProfileLabels profileLabels) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context)
              .dividerColor
              .withValues(alpha: isDark ? 0.35 : 0.6),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 28,
              color: isDark ? AppColors.primary : AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profileLabels.emptyTransactionMsg,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profileLabels.isBusiness
                ? 'Tap tombol + di bawah untuk catat omzet atau biaya.'
                : 'Tap tombol + di bawah untuk mulai mencatat.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutMonetraDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Monetra',
              style: AppTypography.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Versi 1.1.1 (Release)',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Aplikasi Pencatatan Keuangan Pribadi (Multi-Wallet & Offline-First) yang dirancang untuk rotasi uang harian dan target tabungan Anda.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.lock_outline_rounded,
                      size: 14, color: AppColors.primaryDark),
                  SizedBox(width: 6),
                  Text(
                    '100% Offline & Tersimpan di HP Anda',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
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
}
