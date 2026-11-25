import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../core/utils/color_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/icon_helper.dart';
import '../../../data/models/category.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/repositories/transfer_repository.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../../home/providers/home_providers.dart';
import '../../transaction/screens/edit_transaction_screen.dart';
import '../../transaction/screens/edit_transfer_screen.dart';
import '../providers/history_providers.dart';
import '../widgets/daily_transaction_group_card.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _isSearching = false;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(historyFilterProvider).searchQuery;
    _isSearching = initialQuery.isNotEmpty;
    _searchController = TextEditingController(text: initialQuery);
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _stopSearch() {
    _searchController.clear();
    ref
        .read(historyFilterProvider.notifier)
        .update((state) => state.copyWith(clearSearch: true));
    setState(() => _isSearching = false);
  }

  void _onSearchChanged(String value) {
    ref
        .read(historyFilterProvider.notifier)
        .update((state) => state.copyWith(searchQuery: value));
    setState(() {});
  }

  void _resetAllFilters() {
    _searchController.clear();
    ref.read(historyFilterProvider.notifier).state = const HistoryFilter();
    setState(() => _isSearching = false);
  }

  Future<void> _deleteTransactionWithUndo(TransactionDetail tx) async {
    final txRepo = ref.read(transactionRepositoryProvider);
    await txRepo.deleteTransaction(tx.id);
    ref.read(homeRefreshTriggerProvider.notifier).state++;
    if (!mounted) return;

    final label = tx.note?.isNotEmpty == true
        ? tx.note!
        : (tx.categoryName ?? (tx.isIncome ? 'Pemasukan' : 'Pengeluaran'));

    _showUndoDeleteSnackBar(
      message: 'Transaksi "$label" dihapus',
      onUndo: () async {
        await txRepo.insertTransaction(tx.transaction);
        ref.read(homeRefreshTriggerProvider.notifier).state++;
      },
    );
  }

  Future<void> _deleteTransferWithUndo(TransferDetail tr) async {
    final trRepo = ref.read(transferRepositoryProvider);
    await trRepo.deleteTransfer(tr.id);
    ref.read(homeRefreshTriggerProvider.notifier).state++;
    if (!mounted) return;

    _showUndoDeleteSnackBar(
      message: 'Transfer ${tr.fromAccountName} → ${tr.toAccountName} dihapus',
      onUndo: () async {
        await trRepo.insertTransfer(tr.transfer);
        ref.read(homeRefreshTriggerProvider.notifier).state++;
      },
    );
  }

  void _showUndoDeleteSnackBar({
    required String message,
    required Future<void> Function() onUndo,
  }) {
    var undoHandled = false;
    AppSnackBar.show(
      context,
      message: message,
      type: AppSnackBarType.info,
      duration: const Duration(milliseconds: 2000),
      actionLabel: 'Urungkan',
      onAction: () {
        if (undoHandled) return;
        undoHandled = true;
        onUndo();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyGroupsAsync = ref.watch(groupedHistoryTransactionsProvider);
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final categoriesAsync = ref.watch(historyCategoriesProvider);
    final filter = ref.watch(historyFilterProvider);

    return Scaffold(
      appBar: _isSearching
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Tutup Pencarian',
                onPressed: _stopSearch,
              ),
              title: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari transaksi...',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 15,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              actions: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Hapus Kata Kunci',
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                      _searchFocusNode.requestFocus();
                    },
                  ),
              ],
            )
          : AppBar(
              title: Text(
                'Catatan Riwayat',
                style: AppTypography.headlineMedium.copyWith(fontSize: 18),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  tooltip: 'Cari Transaksi',
                  onPressed: _startSearch,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Segarkan',
                  onPressed: () {
                    ref.read(homeRefreshTriggerProvider.notifier).state++;
                  },
                ),
              ],
            ),
      body: Column(
        children: [
          // 1. Filter Horizontal Bar
          _buildFilterBar(context, accountsAsync, categoriesAsync, filter),

          // 2. Konten Riwayat Harian
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.read(homeRefreshTriggerProvider.notifier).state++;
                await Future.wait([
                  ref.refresh(groupedHistoryTransactionsProvider.future),
                  ref.refresh(accountsWithBalanceProvider.future),
                ]);
              },
              child: historyGroupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: filter.hasAnyFilter
                              ? _buildEmptySearchState(context)
                              : _buildEmptyHistoryState(context),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return DailyTransactionGroupCard(
                        group: group,
                        onItemTap: (tx) {
                          Navigator.push(
                            context,
                            AppRouter.buildSmoothRoute(
                              EditTransactionScreen(detail: tx),
                            ),
                          );
                        },
                        onTransferTap: (tr) =>
                            _showTransferDetailDialog(context, tr),
                        onItemDelete: _deleteTransactionWithUndo,
                        onTransferDelete: _deleteTransferWithUndo,
                      );
                    },
                  );
                },
                loading: () => const HistoryListSkeleton(),
                error: (e, _) => Center(child: Text('Error riwayat: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    AsyncValue<List<AccountWithBalance>> accountsAsync,
    AsyncValue<List<Category>> categoriesAsync,
    HistoryFilter filter,
  ) {
    final filterNotifier = ref.read(historyFilterProvider.notifier);
    final allCategories = categoriesAsync.valueOrNull ?? const <Category>[];
    final selectedCategory = filter.categoryId != null
        ? allCategories.where((c) => c.id == filter.categoryId).firstOrNull
        : null;

    final accountsList =
        accountsAsync.valueOrNull ?? const <AccountWithBalance>[];
    AccountWithBalance? selectedAccount;
    if (filter.accountId != null) {
      for (final a in accountsList) {
        if (a.id == filter.accountId) {
          selectedAccount = a;
          break;
        }
      }
    }

    // Hitung label tanggal
    String dateRangeLabel = 'Tanggal';
    if (filter.hasDateRange) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final s = filter.startDate!;
      final e = filter.endDate!;
      if (s == today && e == today) {
        dateRangeLabel = 'Hari Ini';
      } else if (s == today.subtract(const Duration(days: 6)) && e == today) {
        dateRangeLabel = '7 Hari Terakhir';
      } else if (s == DateTime(now.year, now.month, 1) &&
          e == DateTime(now.year, now.month + 1, 0)) {
        dateRangeLabel = 'Bulan Ini';
      } else {
        dateRangeLabel =
            '${DateFormatter.formatShort(s).split(' ').take(2).join(' ')} - ${DateFormatter.formatShort(e).split(' ').take(2).join(' ')}';
      }
    }

    // Hitung label akun
    String accountLabel = 'Semua Akun';
    if (selectedAccount != null) {
      accountLabel = selectedAccount.name;
    } else if (filter.accountGroup != null) {
      accountLabel =
          filter.accountGroup == 'tabungan' ? 'Tabungan' : 'Uang Harian';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Segmented Control Jenis Transaksi (Termasuk 🌴 Liburan)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTypeSegment(
                    context,
                    label: 'Semua',
                    isSelected: filter.type == null,
                    activeColor: AppColors.primary,
                    onTap: () {
                      filterNotifier.state = filter.copyWith(
                        type: null,
                        clearType: true,
                      );
                    },
                  ),
                  _buildTypeSegment(
                    context,
                    label: 'Pengeluaran',
                    isSelected: filter.type == 'expense',
                    activeColor: AppColors.danger,
                    onTap: () {
                      final clearCat = selectedCategory != null &&
                          selectedCategory.type != 'expense';
                      filterNotifier.state = filter.copyWith(
                        type: 'expense',
                        clearCategory: clearCat,
                      );
                    },
                  ),
                  _buildTypeSegment(
                    context,
                    label: 'Pemasukan',
                    isSelected: filter.type == 'income',
                    activeColor: const Color(0xFF059669),
                    onTap: () {
                      final clearCat = selectedCategory != null &&
                          selectedCategory.type != 'income';
                      filterNotifier.state = filter.copyWith(
                        type: 'income',
                        clearCategory: clearCat,
                      );
                    },
                  ),
                  _buildTypeSegment(
                    context,
                    label: 'Transfer',
                    isSelected: filter.type == 'transfer',
                    activeColor: const Color(0xFF0284C7),
                    onTap: () {
                      filterNotifier.state = filter.copyWith(
                        type: 'transfer',
                        clearCategory: true,
                      );
                    },
                  ),
                  _buildTypeSegment(
                    context,
                    label: '🌴 Liburan',
                    isSelected: filter.type == 'vacation',
                    activeColor: const Color(0xFF0284C7),
                    onTap: () {
                      filterNotifier.state = filter.copyWith(
                        type: 'vacation',
                        clearCategory: true,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 2. Baris Dropdown Filter (Tanggal, Akun, Kategori, + Reset)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Dropdown Tanggal
                _buildFilterDropdownPill(
                  context,
                  icon: const Icon(Icons.calendar_month_rounded, size: 15),
                  label: dateRangeLabel,
                  isActive: filter.hasDateRange,
                  activeColor: AppColors.primary,
                  onTap: () => _showDateRangeFilterSheet(context, filter),
                  onClear: filter.hasDateRange
                      ? () => filterNotifier.state =
                            filter.copyWith(clearDateRange: true)
                      : null,
                ),
                const SizedBox(width: 8),

                // Dropdown Akun / Rekening
                _buildFilterDropdownPill(
                  context,
                  icon: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 15,
                  ),
                  label: accountLabel,
                  isActive:
                      filter.accountId != null || filter.accountGroup != null,
                  activeColor: selectedAccount != null
                      ? ColorHelper.parseHex(selectedAccount.colorHex)
                      : AppColors.primary,
                  onTap: () =>
                      _showAccountFilterSheet(context, accountsAsync, filter),
                  onClear:
                      (filter.accountId != null || filter.accountGroup != null)
                          ? () => filterNotifier.state = filter.copyWith(
                                clearAccount: true,
                                clearAccountGroup: true,
                              )
                          : null,
                ),
                const SizedBox(width: 8),

                // Dropdown Kategori
                _buildFilterDropdownPill(
                  context,
                  icon: selectedCategory != null
                      ? Icon(
                          IconHelper.getIcon(selectedCategory.iconCodePoint),
                          size: 15,
                          color: ColorHelper.parseHex(
                            selectedCategory.colorHex,
                          ),
                        )
                      : const Icon(Icons.category_outlined, size: 15),
                  label: selectedCategory?.name ?? 'Kategori',
                  isActive: selectedCategory != null,
                  activeColor: selectedCategory != null
                      ? ColorHelper.parseHex(selectedCategory.colorHex)
                      : AppColors.primary,
                  onTap: () =>
                      _showCategoryFilterSheet(context, allCategories, filter),
                  onClear: selectedCategory != null
                      ? () => filterNotifier.state =
                            filter.copyWith(clearCategory: true)
                      : null,
                ),

                // Tombol Reset Cepat jika filter aktif
                if (filter.hasAnyFilter) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _resetAllFilters,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.refresh_rounded,
                            size: 14,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Reset',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSegment(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? activeColor.withValues(alpha: 0.2)
                  : activeColor.withValues(alpha: 0.12))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.45)
                : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
              color: isSelected
                  ? (isDark ? Colors.white : activeColor)
                  : AppColors.textSecondaryOf(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdownPill(
    BuildContext context, {
    required Widget icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark
                  ? activeColor.withValues(alpha: 0.18)
                  : activeColor.withValues(alpha: 0.1))
              : (isDark ? const Color(0xFF1E222A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.5)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 115),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive
                      ? (isDark ? Colors.white : activeColor)
                      : AppColors.textPrimaryOf(context),
                ),
              ),
            ),
            const SizedBox(width: 4),
            if (isActive && onClear != null)
              GestureDetector(
                onTap: onClear,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: isActive
                        ? (isDark ? Colors.white70 : activeColor)
                        : Colors.grey,
                  ),
                ),
              )
            else
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.textSecondaryOf(context),
              ),
          ],
        ),
      ),
    );
  }

  void _showAccountFilterSheet(
    BuildContext context,
    AsyncValue<List<AccountWithBalance>> accountsAsync,
    HistoryFilter filter,
  ) {
    final notifier = ref.read(historyFilterProvider.notifier);
    final accounts =
        accountsAsync.valueOrNull ?? const <AccountWithBalance>[];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filter Akun & Dompet', style: AppTypography.titleLarge),
                  if (filter.accountId != null || filter.accountGroup != null)
                    TextButton(
                      onPressed: () {
                        notifier.state = filter.copyWith(
                          clearAccount: true,
                          clearAccountGroup: true,
                        );
                        Navigator.pop(ctx);
                      },
                      child: const Text('Reset'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Filter Grup Cepat (Uang Harian & Tabungan)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.wallet_rounded, size: 16),
                      label: const Text('Uang Harian'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: filter.accountGroup == 'harian'
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : null,
                        side: BorderSide(
                          color: filter.accountGroup == 'harian'
                              ? AppColors.primary
                              : Theme.of(ctx).dividerColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        notifier.state = filter.copyWith(
                          accountGroup: filter.accountGroup == 'harian'
                              ? null
                              : 'harian',
                          clearAccountGroup: filter.accountGroup == 'harian',
                          clearAccount: true,
                        );
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.savings_rounded, size: 16),
                      label: const Text('Tabungan'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: filter.accountGroup == 'tabungan'
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : null,
                        side: BorderSide(
                          color: filter.accountGroup == 'tabungan'
                              ? AppColors.primary
                              : Theme.of(ctx).dividerColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        notifier.state = filter.copyWith(
                          accountGroup: filter.accountGroup == 'tabungan'
                              ? null
                              : 'tabungan',
                          clearAccountGroup: filter.accountGroup == 'tabungan',
                          clearAccount: true,
                        );
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Daftar Akun / Rekening',
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.textSecondaryOf(ctx),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (accounts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Belum ada akun terdaftar.'),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: accounts.length + 1,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final isAllSelected = filter.accountId == null &&
                            filter.accountGroup == null;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: isAllSelected
                                ? AppColors.primary.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.all_inclusive_rounded,
                              color: isAllSelected
                                  ? AppColors.primary
                                  : Colors.grey,
                              size: 20,
                            ),
                          ),
                          title: const Text('Semua Akun'),
                          trailing: isAllSelected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                )
                              : null,
                          onTap: () {
                            notifier.state = filter.copyWith(
                              clearAccount: true,
                              clearAccountGroup: true,
                            );
                            Navigator.pop(ctx);
                          },
                        );
                      }

                      final acc = accounts[index - 1];
                      final isSelected = filter.accountId == acc.id;
                      final color = ColorHelper.parseHex(acc.colorHex);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: color.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Icon(
                            IconHelper.getIcon(acc.iconCodePoint),
                            color: color,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          acc.name,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${acc.category == 'tabungan' ? 'Tabungan' : 'Uang Harian'} • ${CurrencyFormatter.format(acc.balance)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                              )
                            : null,
                        onTap: () {
                          notifier.state = filter.copyWith(
                            accountId: acc.id,
                            clearAccountGroup: true,
                          );
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDateRangeFilterSheet(BuildContext context, HistoryFilter filter) {
    final notifier = ref.read(historyFilterProvider.notifier);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Rentang Tanggal',
                    style: AppTypography.titleLarge,
                  ),
                  if (filter.hasDateRange)
                    TextButton(
                      onPressed: () {
                        notifier.state = filter.copyWith(clearDateRange: true);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Reset'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(
                  Icons.today_rounded,
                  color: AppColors.primaryDark,
                ),
                title: const Text('Hari Ini'),
                onTap: () {
                  notifier.state = filter.copyWith(
                    startDate: today,
                    endDate: today,
                  );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.view_week_rounded,
                  color: AppColors.primaryDark,
                ),
                title: const Text('7 Hari Terakhir'),
                onTap: () {
                  notifier.state = filter.copyWith(
                    startDate: today.subtract(const Duration(days: 6)),
                    endDate: today,
                  );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.primaryDark,
                ),
                title: const Text('Bulan Ini'),
                onTap: () {
                  notifier.state = filter.copyWith(
                    startDate: DateTime(now.year, now.month, 1),
                    endDate: DateTime(now.year, now.month + 1, 0),
                  );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.history_toggle_off_rounded,
                  color: AppColors.primaryDark,
                ),
                title: const Text('Bulan Lalu'),
                onTap: () {
                  notifier.state = filter.copyWith(
                    startDate: DateTime(now.year, now.month - 1, 1),
                    endDate: DateTime(now.year, now.month, 0),
                  );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.date_range_rounded,
                  color: Color(0xFF0284C7),
                ),
                title: const Text('Pilih Tanggal Custom...'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDateRange: filter.hasDateRange
                        ? DateTimeRange(
                            start: filter.startDate!,
                            end: filter.endDate!,
                          )
                        : DateTimeRange(
                            start: today.subtract(const Duration(days: 6)),
                            end: today,
                          ),
                  );
                  if (picked != null) {
                    notifier.state = filter.copyWith(
                      startDate: picked.start,
                      endDate: picked.end,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryFilterSheet(
    BuildContext context,
    List<Category> categories,
    HistoryFilter filter,
  ) {
    final notifier = ref.read(historyFilterProvider.notifier);
    final relevantCats = filter.type == 'expense' || filter.type == 'income'
        ? categories.where((c) => c.type == filter.type).toList()
        : categories;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filter Kategori', style: AppTypography.titleLarge),
                  if (filter.categoryId != null)
                    TextButton(
                      onPressed: () {
                        notifier.state = filter.copyWith(clearCategory: true);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Semua'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (relevantCats.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Belum ada kategori tersedia.'),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                  ),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: relevantCats.map((cat) {
                        final isSelected = filter.categoryId == cat.id;
                        final catColor = ColorHelper.parseHex(cat.colorHex);
                        return ChoiceChip(
                          selected: isSelected,
                          avatar: Icon(
                            IconHelper.getIcon(cat.iconCodePoint),
                            size: 16,
                            color: isSelected ? Colors.black : catColor,
                          ),
                          label: Text(cat.name),
                          selectedColor: AppColors.primary,
                          onSelected: (selected) {
                            notifier.state = filter.copyWith(
                              categoryId: selected ? cat.id : null,
                              clearCategory: !selected,
                              clearType: selected && filter.type == 'transfer',
                            );
                            Navigator.pop(ctx);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransferDetailDialog(BuildContext context, TransferDetail tr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, _, _) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon Header
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.swap_horiz_rounded,
                          color: Color(0xFF0284C7),
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Detail Transfer',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 4),

                    Text(
                      CurrencyFormatter.format(tr.amount),
                      style: AppTypography.headlineMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rekening Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DARI',
                                  style: AppTypography.labelSmall.copyWith(
                                    fontSize: 10,
                                    letterSpacing: 0.8,
                                    color: AppColors.textSecondaryOf(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr.fromAccountName,
                                  style: AppTypography.titleSmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'TUJUAN',
                                  style: AppTypography.labelSmall.copyWith(
                                    fontSize: 10,
                                    letterSpacing: 0.8,
                                    color: AppColors.textSecondaryOf(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr.toAccountName,
                                  style: AppTypography.titleSmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Info Tanggal & Catatan
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tanggal',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                        Text(
                          DateFormatter.formatFull(tr.date),
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (tr.note?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Catatan',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              tr.note!,
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Actions Row
                    Row(
                      children: [
                        // Tombol Hapus (Destructive)
                        IconButton(
                          onPressed: () async {
                            final confirm = await AppDialog.delete(
                              context,
                              title: 'Hapus Transfer?',
                              message:
                                  'Saldo ${CurrencyFormatter.format(tr.amount)} akan otomatis dikembalikan ke rekening ${tr.fromAccountName}.',
                              confirmLabel: 'Hapus Transfer',
                            );

                            if (confirm == true) {
                              final repo = ref.read(transferRepositoryProvider);
                              await repo.deleteTransfer(tr.id);
                              ref.read(homeRefreshTriggerProvider.notifier).state++;
                              if (ctx.mounted) Navigator.pop(ctx);
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                          color: AppColors.danger,
                          tooltip: 'Hapus Transfer',
                        ),
                        const SizedBox(width: 6),
                        // Tombol Ubah
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  AppRouter.buildSmoothRoute(
                                    EditTransferScreen(detail: tr),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Ubah'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Tombol Tutup
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Tutup'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptySearchState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 56,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Tidak Ada Hasil Ditemukan',
              style: AppTypography.headlineMedium.copyWith(fontSize: 17),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Coba sesuaikan filter atau kata kunci pencarian Anda.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 13,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _resetAllFilters,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset Pencarian & Filter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistoryState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                size: 52,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Catatan Transaksi',
              textAlign: TextAlign.center,
              style: AppTypography.headlineMedium.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              'Mulai catat transaksi pengeluaran dan pemasukan harian Anda.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 13,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push(AppRouter.addTransaction),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Catat Transaksi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
