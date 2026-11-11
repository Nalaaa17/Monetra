import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/category.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';

class HistoryFilter {
  final int? accountId;
  final String? accountGroup; // 'harian' | 'tabungan' | null
  final int? categoryId;
  final String? type; // 'expense' | 'income' | 'transfer' | null (semua)
  final DateTime? startDate;
  final DateTime? endDate;
  final String searchQuery;

  const HistoryFilter({
    this.accountId,
    this.accountGroup,
    this.categoryId,
    this.type,
    this.startDate,
    this.endDate,
    this.searchQuery = '',
  });

  bool get hasDateRange => startDate != null && endDate != null;

  bool get hasAnyFilter =>
      accountId != null ||
      accountGroup != null ||
      categoryId != null ||
      type != null ||
      hasDateRange ||
      searchQuery.trim().isNotEmpty;

  HistoryFilter copyWith({
    int? accountId,
    String? accountGroup,
    int? categoryId,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    bool clearAccount = false,
    bool clearAccountGroup = false,
    bool clearCategory = false,
    bool clearType = false,
    bool clearDateRange = false,
    bool clearSearch = false,
  }) {
    return HistoryFilter(
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      accountGroup:
          clearAccountGroup ? null : (accountGroup ?? this.accountGroup),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      type: clearType ? null : (type ?? this.type),
      startDate: clearDateRange ? null : (startDate ?? this.startDate),
      endDate: clearDateRange ? null : (endDate ?? this.endDate),
      searchQuery: clearSearch ? '' : (searchQuery ?? this.searchQuery),
    );
  }
}

final historyFilterProvider = StateProvider<HistoryFilter>((ref) {
  return const HistoryFilter();
});

final historyCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  ref.watch(homeRefreshTriggerProvider);
  final repo = ref.watch(categoryRepositoryProvider);
  return await repo.getAllCategories(onlyActive: false);
});

final groupedHistoryTransactionsProvider =
    FutureProvider<List<DailyTransactionsGroup>>((ref) async {
  ref.watch(homeRefreshTriggerProvider);
  final filter = ref.watch(historyFilterProvider);
  final repo = ref.watch(transactionRepositoryProvider);

  List<int>? groupAccountIds;
  if (filter.accountId == null && filter.accountGroup != null) {
    final accountRepo = ref.watch(accountRepositoryProvider);
    final accounts = await accountRepo.getAllAccounts();
    groupAccountIds = accounts
        .where((a) => a.category == filter.accountGroup && a.id != null)
        .map((a) => a.id!)
        .toList();
  }

  return await repo.getGroupedTransactionsByDate(
    accountId: filter.accountId,
    accountIds: groupAccountIds,
    categoryId: filter.categoryId,
    type: filter.type,
    startDate: filter.startDate,
    endDate: filter.endDate,
    searchQuery: filter.searchQuery,
  );
});
