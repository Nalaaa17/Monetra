import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/color_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/icon_helper.dart';
import '../../../data/models/category.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/repositories/transfer_repository.dart';
import '../../../shared/providers/repository_providers.dart';
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
    ref.read(historyFilterProvider.notifier).update(
          (state) => state.copyWith(clearSearch: true),
        );
    setState(() => _isSearching = false);
  }

  void _onSearchChanged(String value) {
    ref.read(historyFilterProvider.notifier).update(
          (state) => state.copyWith(searchQuery: value),
        );
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
    final messenger = ScaffoldMessenger.of(context);
    var undoHandled = false;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Urungkan',
          textColor: AppColors.primary,
          onPressed: () {
            if (undoHandled) return;
            undoHandled = true;
            onUndo();
          },
        ),
      ),
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
                  hintText: 'Cari catatan, kategori, akun, nominal...',
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
          _buildFilterBar(
            context,
            accountsAsync,
            categoriesAsync,
            filter,
          ),

          // 2. Konten Riwayat Harian
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.read(homeRefreshTriggerProvider.notifier).state++;
              },
              child: historyGroupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    if (filter.hasAnyFilter) {
                      return _buildEmptySearchState(context);
                    }
                    return _buildEmptyHistoryState(context);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return DailyTransactionGroupCard(
                        group: group,
                        onItemTap: (tx) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
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
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error riwayat: $e')),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRouter.addTransaction),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.black, size: 28),
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    AsyncValue accountsAsync,
    AsyncValue<List<Category>> categoriesAsync,
    HistoryFilter filter,
  ) {
    final filterNotifier = ref.read(historyFilterProvider.notifier);
    final allCategories = categoriesAsync.valueOrNull ?? const <Category>[];
    final selectedCategory = filter.categoryId != null
        ? allCategories.where((c) => c.id == filter.categoryId).firstOrNull
        : null;
    final dateRangeLabel = filter.hasDateRange
        ? '${DateFormatter.formatShort(filter.startDate!).split(' ').take(2).join(' ')} - ${DateFormatter.formatShort(filter.endDate!).split(' ').take(2).join(' ')}'
        : 'Tanggal';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Filter Jenis Transaksi
            FilterChip(
              label: const Text('Semua'),
              selected: !filter.hasAnyFilter,
              onSelected: (_) => _resetAllFilters(),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('💸 Pengeluaran'),
              selected: filter.type == 'expense',
              selectedColor: AppColors.danger.withValues(alpha: 0.15),
              onSelected: (val) {
                final clearCat = val &&
                    selectedCategory != null &&
                    selectedCategory.type != 'expense';
                filterNotifier.state = filter.copyWith(
                  type: val ? 'expense' : null,
                  clearType: !val,
                  clearCategory: clearCat,
                );
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('💰 Pemasukan'),
              selected: filter.type == 'income',
              selectedColor: AppColors.tertiary.withValues(alpha: 0.15),
              onSelected: (val) {
                final clearCat = val &&
                    selectedCategory != null &&
                    selectedCategory.type != 'income';
                filterNotifier.state = filter.copyWith(
                  type: val ? 'income' : null,
                  clearType: !val,
                  clearCategory: clearCat,
                );
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('↔️ Transfer'),
              selected: filter.type == 'transfer',
              selectedColor: AppColors.secondary.withValues(alpha: 0.15),
              onSelected: (val) {
                filterNotifier.state = filter.copyWith(
                  type: val ? 'transfer' : null,
                  clearType: !val,
                  clearCategory: val,
                );
              },
            ),
            const SizedBox(width: 8),

            // Filter Rentang Tanggal (PRD §4.2)
            FilterChip(
              avatar: const Icon(Icons.date_range_rounded, size: 16),
              label: Text(dateRangeLabel),
              selected: filter.hasDateRange,
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
              onSelected: (_) => _showDateRangeFilterSheet(context, filter),
            ),
            const SizedBox(width: 8),

            // Filter Kategori (PRD §4.2)
            FilterChip(
              avatar: selectedCategory != null
                  ? Icon(
                      IconHelper.getIcon(selectedCategory.iconCodePoint),
                      size: 16,
                      color: ColorHelper.parseHex(selectedCategory.colorHex),
                    )
                  : const Icon(Icons.category_outlined, size: 16),
              label: Text(selectedCategory?.name ?? 'Kategori'),
              selected: selectedCategory != null,
              selectedColor: selectedCategory != null
                  ? ColorHelper.parseHex(selectedCategory.colorHex)
                      .withValues(alpha: 0.18)
                  : null,
              onSelected: (_) =>
                  _showCategoryFilterSheet(context, allCategories, filter),
            ),

            if (filter.accountGroup != null) ...[
              const SizedBox(width: 8),
              InputChip(
                label: Text(
                  filter.accountGroup == 'tabungan'
                      ? 'Tabungan'
                      : 'Uang Harian',
                ),
                selected: true,
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                onDeleted: () {
                  filterNotifier.state =
                      filter.copyWith(clearAccountGroup: true);
                },
                onPressed: () {
                  filterNotifier.state =
                      filter.copyWith(clearAccountGroup: true);
                },
              ),
            ],

            const SizedBox(width: 12),
            Container(width: 1, height: 24, color: Theme.of(context).dividerColor),
            const SizedBox(width: 12),

            // Filter Akun/Dompet
            accountsAsync.maybeWhen(
              data: (accounts) => Row(
                children: accounts.map<Widget>((acc) {
                  final isSelected = filter.accountId == acc.id;
                  final color = ColorHelper.parseHex(acc.colorHex);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(acc.name),
                      selected: isSelected,
                      selectedColor: color.withValues(alpha: 0.15),
                      onSelected: (val) {
                        filterNotifier.state = filter.copyWith(
                          accountId: val ? acc.id : null,
                          clearAccount: !val,
                          clearAccountGroup: val,
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _showDateRangeFilterSheet(
    BuildContext context,
    HistoryFilter filter,
  ) {
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
                  Text('Filter Rentang Tanggal', style: AppTypography.titleLarge),
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
                leading: const Icon(Icons.today_rounded,
                    color: AppColors.primaryDark),
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
                leading: const Icon(Icons.view_week_rounded,
                    color: AppColors.primaryDark),
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
                leading: const Icon(Icons.calendar_month_rounded,
                    color: AppColors.primaryDark),
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
                leading: const Icon(Icons.date_range_rounded,
                    color: Color(0xFF0284C7)),
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
                              clearType:
                                  selected && filter.type == 'transfer',
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: Color(0xFF0284C7)),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Detail Transfer',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              CurrencyFormatter.format(tr.amount),
              style: AppTypography.headlineLarge.copyWith(
                fontSize: 24,
                color: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(height: 12),
            Text('Dari: ${tr.fromAccountName}', style: AppTypography.titleMedium),
            Text('Ke: ${tr.toAccountName}', style: AppTypography.titleMedium),
            const SizedBox(height: 8),
            Text('Tanggal: ${DateFormatter.formatFull(tr.date)}',
                style: AppTypography.bodyMedium),
            if (tr.note?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text('Catatan: ${tr.note}', style: AppTypography.bodyMedium),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditTransferScreen(detail: tr),
                ),
              );
            },
            child: const Text('Ubah'),
          ),
          TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: ctx,
                builder: (c) => AlertDialog(
                  title: const Text('Hapus Transfer?'),
                  content: const Text(
                    'Saldo yang dipindahkan akan dikembalikan ke akun asal.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(c, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Hapus'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                final repo = ref.read(transferRepositoryProvider);
                await repo.deleteTransfer(tr.id);
                ref.read(homeRefreshTriggerProvider.notifier).state++;
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Hapus', style: TextStyle(color: AppColors.danger)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
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
              style: AppTypography.headlineMedium.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Coba kata kunci lain atau reset filter yang aktif.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _resetAllFilters,
              icon: const Icon(Icons.filter_alt_off_rounded),
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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                size: 64,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum Ada Catatan Transaksi',
              textAlign: TextAlign.center,
              style: AppTypography.headlineMedium.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Catatan kamu di sini akan otomatis rapi per tanggal, lengkap dengan total pengeluaran dan pemasukan seperti di Notes HP.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push(AppRouter.addTransaction),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Catat Transaksi Pertama',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
