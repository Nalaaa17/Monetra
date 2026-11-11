import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/recurring_transaction_repository.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';

/// Daftar seluruh jadwal transaksi berulang, sekaligus menyinkronkan jadwal jatuh tempo.
final recurringTransactionsListProvider =
    FutureProvider<List<RecurringTransactionDetail>>((ref) async {
  ref.watch(homeRefreshTriggerProvider);
  final repo = ref.watch(recurringTransactionRepositoryProvider);
  await repo.syncRecurringTransactions();
  return await repo.getAllRecurringDetails();
});

/// Ringkasan estimasi arus kas bulanan dari jadwal transaksi berulang yang aktif.
final recurringSummaryProvider =
    Provider<AsyncValue<RecurringMonthlySummary>>((ref) {
  final listAsync = ref.watch(recurringTransactionsListProvider);
  return listAsync.whenData(RecurringTransactionRepository.summarizeRules);
});

