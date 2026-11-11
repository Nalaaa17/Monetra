import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/providers/repository_providers.dart';

// Trigger untuk refresh reaktif data Home Screen
final homeRefreshTriggerProvider = StateProvider<int>((ref) => 0);

final balanceSummaryProvider = FutureProvider<BalanceSummary>((ref) async {
  ref.watch(homeRefreshTriggerProvider);
  await ref.read(goalRepositoryProvider).syncRecurringGoals();
  await ref
      .read(recurringTransactionRepositoryProvider)
      .syncRecurringTransactions();
  final repo = ref.watch(accountRepositoryProvider);
  return await repo.getBalanceSummary();
});

final accountsWithBalanceProvider =
    FutureProvider<List<AccountWithBalance>>((ref) async {
  ref.watch(homeRefreshTriggerProvider);
  await ref.read(goalRepositoryProvider).syncRecurringGoals();
  await ref
      .read(recurringTransactionRepositoryProvider)
      .syncRecurringTransactions();
  final repo = ref.watch(accountRepositoryProvider);
  return await repo.getAllAccountsWithBalances();
});

final recentTransactionsProvider =
    FutureProvider<List<TransactionDetail>>((ref) async {
  ref.watch(homeRefreshTriggerProvider);
  await ref
      .read(recurringTransactionRepositoryProvider)
      .syncRecurringTransactions();
  final repo = ref.watch(transactionRepositoryProvider);
  return await repo.getRecentTransactionDetails(limit: 5);
});

