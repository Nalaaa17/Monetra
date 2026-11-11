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
        titleSpacing: 12,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 34,
              height: 34,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Monetra',
                          style: AppTypography.headlineMedium.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '• Halo!',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    DateFormatter.formatFull(DateTime.now()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Dark Mode Toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? AppColors.primary : AppColors.textPrimary,
            ),
            tooltip: isDark ? 'Mode Cerah' : 'Mode Gelap',
            onPressed: () {
              ref.read(themeModeProvider.notifier).state =
                  isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),

          // Menu Pengaturan & Kelola
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Pengaturan',
            onSelected: (val) {
              if (val == 'calculator') {
                context.push(AppRouter.calculator);
              } else if (val == 'recurring') {
                context.push(AppRouter.recurring);
              } else if (val == 'backup') {
                context.push(AppRouter.backup);
              } else if (val == 'accounts') {
                context.push(AppRouter.manageAccounts);
              } else if (val == 'categories') {
                context.push(AppRouter.manageCategories);
              } else if (val == 'about') {
                _showAboutMonetraDialog(context);
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'recurring',
                child: Row(
                  children: [
                    Icon(Icons.repeat_rounded, size: 18),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Transaksi Berulang',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'calculator',
                child: Row(
                  children: [
                    Icon(Icons.calculate_outlined, size: 18),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Kalkulator Uang',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'accounts',
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 18),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Kelola Dompet / Rekening',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'categories',
                child: Row(
                  children: [
                    Icon(Icons.category_outlined, size: 18),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Kelola Kategori',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.cloud_sync_outlined, size: 18),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Cadangan & Pemulihan Data',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Tentang Monetra',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
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
            // 1. Total Kekayaan Header Card dengan Animasi Count-Up
            balanceSummaryAsync.when(
              data: (summary) => _buildTotalWealthCard(context, summary),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Gagal memuat saldo: $err'),
            ),

            const SizedBox(height: 16),

            // 2. Dual Big Cards: Uang Harian vs Tabungan (PRD §3 & §6.4)
            balanceSummaryAsync.maybeWhen(
              data: (summary) =>
                  _buildDualCategoryCards(context, ref, summary),
              orElse: () => const SizedBox.shrink(),
            ),

            const SizedBox(height: 14),

            // 3. Tombol Aksi Cepat Transfer Saldo
            _buildQuickActionButtons(context),

            const SizedBox(height: 16),

            // Preview Goal Mendekati Jatuh Tempo (PRD §6.4)
            const HomeGoalPreviewSection(),

            const SizedBox(height: 6),

            // 4. Horizontal Accounts List
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

            // 5. Section Transaksi Terakhir
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
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        backgroundColor: Theme.of(context).cardColor,
        elevation: 4,
        onDestinationSelected: (index) {
          if (index == 1) {
            ref.read(historyFilterProvider.notifier).state =
                const HistoryFilter();
            context.push(AppRouter.history);
          } else if (index == 2) {
            context.push(AppRouter.goals);
          } else if (index == 3) {
            context.push(AppRouter.reports);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.primaryDark),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon:
                Icon(Icons.receipt_long_rounded, color: AppColors.primaryDark),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.track_changes_outlined),
            selectedIcon:
                Icon(Icons.track_changes_rounded, color: AppColors.primaryDark),
            label: 'Goal',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon:
                Icon(Icons.bar_chart_rounded, color: AppColors.primaryDark),
            label: 'Laporan',
          ),
        ],
      ),
      floatingActionButton: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: () => _showAddActionSheet(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          icon: const Icon(Icons.add_rounded, color: Colors.black, size: 22),
          label: const Text(
            'Catat Uang',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push(AppRouter.transfer),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              backgroundColor: Theme.of(context).cardColor,
              side: BorderSide(color: Theme.of(context).dividerColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.swap_horiz_rounded,
                color: Color(0xFF0284C7), size: 20),
            label: const Text(
              'Transfer Saldo',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF0284C7),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push(AppRouter.backup),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              backgroundColor: Theme.of(context).cardColor,
              side: BorderSide(color: Theme.of(context).dividerColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.cloud_upload_outlined,
                color: Color(0xFF059669), size: 18),
            label: const Text(
              'Cadangkan Data',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF059669),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalWealthCard(BuildContext context, BalanceSummary summary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasGoals = summary.allocatedInGoals > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2A2415), const Color(0xFF1E293B)]
              : [const Color(0xFFFFF9E6), const Color(0xFFFFF3CC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded,
                        color: AppColors.primaryDark, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasGoals ? 'Saldo Siap Pakai' : 'Total Saldo',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Image.asset(
                'assets/images/logo.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedCurrency(
              amount: summary.totalNetWorth,
              style: AppTypography.headlineLarge.copyWith(
                fontSize: 30,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
          ),
          if (hasGoals) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.28)
                    : Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => context.push(AppRouter.goals),
                        borderRadius: BorderRadius.circular(8),
                        child: _buildWealthSubMetric(
                          context: context,
                          icon: Icons.track_changes_rounded,
                          iconColor: const Color(0xFFD97706),
                          label: 'Dana Target',
                          amount: summary.allocatedInGoals,
                          valueColor: isDark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                    VerticalDivider(
                      width: 16,
                      thickness: 1,
                      color: Theme.of(context).dividerColor,
                    ),
                    Expanded(
                      child: _buildWealthSubMetric(
                        context: context,
                        icon: Icons.account_balance_rounded,
                        iconColor: AppColors.primaryDark,
                        label: 'Total Aset',
                        amount: summary.totalPhysicalNetWorth,
                        valueColor: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
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

  Widget _buildWealthSubMetric({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
    required int amount,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 11.5,
                    color: AppColors.textSecondaryOf(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  String _formatAccountGroupSubtitle(List<String> names) {
    if (names.isEmpty) return 'Belum ada akun';
    if (names.length <= 2) return names.join(' · ');
    return '${names.take(2).join(' · ')} +${names.length - 2}';
  }

  Widget _buildDualCategoryCards(
    BuildContext context,
    WidgetRef ref,
    BalanceSummary summary,
  ) {
    final dailySubtitle = _formatAccountGroupSubtitle(summary.dailyAccountNames);
    final savingsSubtitle =
        _formatAccountGroupSubtitle(summary.savingsAccountNames);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildCategoryGroupCard(
              context: context,
              title: 'Uang Harian',
              icon: Icons.bolt_rounded,
              iconColor: AppColors.primaryDark,
              iconBgColor: AppColors.primary.withValues(alpha: 0.15),
              amount: summary.dailySpendingBalance,
              subtitle: dailySubtitle,
              onTap: () {
                ref.read(historyFilterProvider.notifier).state =
                    const HistoryFilter(accountGroup: 'harian');
                context.push(AppRouter.history);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCategoryGroupCard(
              context: context,
              title: 'Tabungan',
              icon: Icons.lock_clock_rounded,
              iconColor: const Color(0xFF059669),
              iconBgColor: const Color(0xFF059669).withValues(alpha: 0.15),
              amount: summary.savingsBalance,
              subtitle: savingsSubtitle,
              onTap: () {
                ref.read(historyFilterProvider.notifier).state =
                    const HistoryFilter(accountGroup: 'tabungan');
                context.push(AppRouter.history);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGroupCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required int amount,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 15, color: iconColor),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 12.5,
                            color: AppColors.textSecondaryOf(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedCurrency(
                      amount: amount,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
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

  void _showAddActionSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFFAFAFA);

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Catat Aktivitas Finansial',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.headlineMedium.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pilih jenis pencatatan yang ingin Anda buat',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondaryOf(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 1. Opsi Catat Pengeluaran
                _buildModernActionTile(
                  context: context,
                  backgroundColor: cardBg,
                  iconBg: AppColors.danger.withValues(alpha: 0.15),
                  iconColor: AppColors.danger,
                  icon: Icons.arrow_upward_rounded,
                  title: 'Catat Pengeluaran',
                  badgeText: '💸 Keluar',
                  badgeColor: AppColors.danger,
                  subtitle: 'Belanja, jajan, bensin, tagihan & kebutuhan harian',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('${AppRouter.addTransaction}?type=expense');
                  },
                ),
                const SizedBox(height: 12),

                // 2. Opsi Catat Pemasukan
                _buildModernActionTile(
                  context: context,
                  backgroundColor: cardBg,
                  iconBg: const Color(0xFF059669).withValues(alpha: 0.15),
                  iconColor: const Color(0xFF059669),
                  icon: Icons.arrow_downward_rounded,
                  title: 'Catat Pemasukan',
                  badgeText: '💰 Masuk',
                  badgeColor: const Color(0xFF059669),
                  subtitle: 'Gaji, transferan masuk, bonus, piutang & profit usaha',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('${AppRouter.addTransaction}?type=income');
                  },
                ),
                const SizedBox(height: 12),

                // 3. Opsi Transfer Antar Akun
                _buildModernActionTile(
                  context: context,
                  backgroundColor: cardBg,
                  iconBg: const Color(0xFF0284C7).withValues(alpha: 0.15),
                  iconColor: const Color(0xFF0284C7),
                  icon: Icons.swap_horiz_rounded,
                  title: 'Transfer Antar Akun',
                  badgeText: '↔️ Pindah',
                  badgeColor: const Color(0xFF0284C7),
                  subtitle: 'Pindah uang, tarik tunai, tabungan (Mandiri / Seabank / Cash)',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(AppRouter.transfer);
                  },
                ),
                const SizedBox(height: 12),

                // 4. Opsi Transaksi Berulang Otomatis
                _buildModernActionTile(
                  context: context,
                  backgroundColor: cardBg,
                  iconBg: AppColors.primary.withValues(alpha: 0.18),
                  iconColor: isDark ? AppColors.primary : AppColors.primaryDark,
                  icon: Icons.repeat_rounded,
                  title: 'Transaksi Berulang',
                  badgeText: '🔄 Rutin',
                  badgeColor: isDark ? AppColors.primary : AppColors.primaryDark,
                  subtitle: 'Atur tagihan Wi-Fi, cicilan, sewa, atau gaji otomatis',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(AppRouter.recurring);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernActionTile({
    required BuildContext context,
    required Color backgroundColor,
    required Color iconBg,
    required Color iconColor,
    required IconData icon,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: badgeColor.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: badgeColor.withValues(alpha: 0.25),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: iconBg,
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 11,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondaryOf(context),
                size: 20,
              ),
            ],
          ),
        ),
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
