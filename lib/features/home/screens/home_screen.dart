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
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/widgets/animated_currency.dart';
import '../../goals/widgets/home_goal_preview_section.dart';
import '../../history/providers/history_providers.dart';
import '../../transaction/screens/edit_transaction_screen.dart';
import '../providers/home_providers.dart';
import '../widgets/hero_sekilas_card.dart';
import '../widgets/main_menu_grid.dart';
import '../widgets/spending_progress_card.dart';
import '../widgets/monthly_activity_calendar.dart';
import '../widgets/floating_bottom_bar.dart';
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 34,
              height: 34,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Text(
              'Monetra',
              style: AppTypography.headlineMedium.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          // Panduan / Info
          IconButton(
            icon: const Icon(Icons.menu_book_rounded, size: 21),
            tooltip: 'Panduan & Info',
            onPressed: () => _showAboutMonetraDialog(context),
          ),

          // Megaphone / AI Advisor Tips
          IconButton(
            icon: const Icon(Icons.campaign_outlined, size: 22),
            tooltip: 'Tips Finansial',
            onPressed: () => QuickFeatureModals.showAIAdvisorModal(context),
          ),

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
              } else if (val == 'advisor') {
                QuickFeatureModals.showAIAdvisorModal(context);
              } else if (val == 'about') {
                _showAboutMonetraDialog(context);
              }
            },
            itemBuilder: (ctx) => [
              _buildPopupMenuItem('transfer', Icons.swap_horiz_rounded,
                  'Transfer Saldo Antar Akun'),
              _buildPopupMenuItem('backup', Icons.cloud_sync_outlined,
                  'Cadangkan & Pulihkan Data'),
              const PopupMenuDivider(),
              _buildPopupMenuItem(
                  'recurring', Icons.repeat_rounded, 'Transaksi Berulang'),
              _buildPopupMenuItem(
                  'calculator', Icons.calculate_outlined, 'Kalkulator Uang'),
              _buildPopupMenuItem('goals', Icons.track_changes_outlined,
                  'Target Keuangan (Goals)'),
              _buildPopupMenuItem(
                  'reports', Icons.bar_chart_rounded, 'Laporan Finansial'),
              _buildPopupMenuItem('history', Icons.receipt_long_outlined,
                  'Riwayat Transaksi'),
              const PopupMenuDivider(),
              _buildPopupMenuItem('accounts',
                  Icons.account_balance_wallet_outlined, 'Kelola Dompet / Rekening'),
              _buildPopupMenuItem(
                  'categories', Icons.category_outlined, 'Kelola Kategori'),
              const PopupMenuDivider(),
              _buildPopupMenuItem('advisor', Icons.smart_toy_outlined,
                  'AI Advisor (Coming Soon)'),
              _buildPopupMenuItem(
                  'about', Icons.info_outline_rounded, 'Tentang Monetra'),
            ],
          ),

          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Saldo',
            onPressed: () {
              ref.read(homeRefreshTriggerProvider.notifier).state++;
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(homeRefreshTriggerProvider.notifier).state++;
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Greeting & Dashboard Title (sesuai gambar referensi)
            Text(
              'Dashboard',
              style: AppTypography.headlineLarge.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 26,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  '• Halo!',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Sahabat Monetra',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 13,
                  ),
                ),
                const Text(' ☀️', style: TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 16),

            // 1. Hero Card: Sekilas Hari Ini (Sesuai Referensi Gambar 1)
            balanceSummaryAsync.when(
              data: (summary) => HeroSekilasCard(summary: summary),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Gagal memuat saldo: $err'),
            ),
            const SizedBox(height: 18),

            // 2. Menu Utama Pintasan 8 Aksi Cepat (Sesuai Referensi Gambar 1)
            const MainMenuGrid(),
            const SizedBox(height: 18),

            // 3. Progres Pengeluaran (Aturan 50/30/20 - Sesuai Referensi Gambar 2)
            const SpendingProgressCard(),
            const SizedBox(height: 18),

            // 4. Aktivitas Bulan Ini (Kalender Keuangan - Sesuai Referensi Gambar 2)
            const MonthlyActivityCalendar(),
            const SizedBox(height: 20),

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
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Text('Error: $err'),
            ),

            const SizedBox(height: 24),

            // 9. Section Transaksi Terakhir
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Transaksi Terakhir',
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
                  return _buildEmptyTransactionsState(context);
                }
                return Column(
                  children: transactions
                      .map((tx) => _buildTransactionItem(context, tx))
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error transaksi: $err'),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: const FloatingBottomBar(selectedIndex: 0),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(
    String value,
    IconData icon,
    String title,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
          final hasTargetLock = item.allocatedInGoals > 0;

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
                          hasTargetLock ? 'Siap pakai' : 'Saldo',
                          style: AppTypography.labelSmall.copyWith(fontSize: 11.5),
                        ),
                        const SizedBox(height: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AnimatedCurrency(
                            amount: item.balance,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (hasTargetLock)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Target: ${CurrencyFormatter.format(item.allocatedInGoals)}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFFD97706),
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
    final isIncome = tx.isIncome;
    final sign = isIncome ? '+' : '-';
    final amountColor = isIncome ? AppColors.tertiary : AppColors.danger;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditTransactionScreen(detail: tx),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isIncome
                  ? AppColors.tertiary.withValues(alpha: 0.15)
                  : AppColors.danger.withValues(alpha: 0.12),
              child: Icon(
                isIncome
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: isIncome ? const Color(0xFF059669) : AppColors.danger,
                size: 20,
              ),
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

  Widget _buildEmptyTransactionsState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 48, color: AppColors.textSecondaryOf(context)),
          const SizedBox(height: 12),
          Text(
            'Belum ada transaksi hari ini',
            style: AppTypography.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Tekan tombol Catat Uang di bawah untuk mulai mencatat pengeluaran atau pemasukan.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
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
              'Versi 1.0.0 (Release)',
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
