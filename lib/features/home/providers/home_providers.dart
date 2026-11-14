import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/providers/repository_providers.dart';

// Trigger untuk refresh reaktif data Home Screen
final homeRefreshTriggerProvider = StateProvider<int>((ref) => 0);

// Status sembunyikan nominal saldo (fitur sensor saldo di hero card)
final isBalanceHiddenProvider = StateProvider<bool>((ref) => false);

// Bulan terpilih untuk Kalender Aktivitas Bulanan di Dashboard
final selectedCalendarMonthProvider = StateProvider<DateTime>(
  (ref) => DateTime(DateTime.now().year, DateTime.now().month, 1),
);

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

// Ringkasan Pemasukan & Pengeluaran Hari Ini
final todaySummaryProvider =
    FutureProvider<({int income, int expense})>((ref) async {
  ref.watch(homeRefreshTriggerProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  return await repo.getTodaySummary();
});

// Kalender Aktivitas Bulan Berjalan
final monthlyDailyActivityProvider =
    FutureProvider<Map<int, DailyActivityPoint>>((ref) async {
  ref.watch(homeRefreshTriggerProvider);
  final selectedDate = ref.watch(selectedCalendarMonthProvider);
  final repo = ref.watch(reportRepositoryProvider);
  return await repo.getDailyActivityForMonth(
    selectedDate.year,
    selectedDate.month,
  );
});

// Progres Alokasi Pengeluaran 50/30/20 (Kebutuhan, Keinginan, Tabungan)
final spendingAllocationProvider =
    FutureProvider<SpendingAllocation>((ref) async {
  ref.watch(homeRefreshTriggerProvider);
  final selectedDate = ref.watch(selectedCalendarMonthProvider);
  final repo = ref.watch(reportRepositoryProvider);
  return await repo.getSpendingAllocation(
    selectedDate.year,
    selectedDate.month,
  );
});


