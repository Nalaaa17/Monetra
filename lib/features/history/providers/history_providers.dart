import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';

class HistoryFilter {
  final int? accountId;
  final String? type; // 'expense' | 'income' | null (semua)

  const HistoryFilter({this.accountId, this.type});

  HistoryFilter copyWith({int? accountId, String? type, bool clearAccount = false, bool clearType = false}) {
    return HistoryFilter(
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      type: clearType ? null : (type ?? this.type),
    );
  }
}

final historyFilterProvider = StateProvider<HistoryFilter>((ref) {
  return const HistoryFilter();
});

final groupedHistoryTransactionsProvider =
    FutureProvider<List<DailyTransactionsGroup>>((ref) async {
  ref.watch(homeRefreshTriggerProvider);
  final filter = ref.watch(historyFilterProvider);
  final repo = ref.watch(transactionRepositoryProvider);

  return await repo.getGroupedTransactionsByDate(
    accountId: filter.accountId,
    type: filter.type,
  );
});

