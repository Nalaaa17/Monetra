import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/debt_model.dart';
import '../../../shared/providers/repository_providers.dart';

final debtRefreshProvider = StateProvider<int>((ref) => 0);

final debtTypeTabProvider = StateProvider<String>((ref) => 'debt'); // 'debt' or 'receivable'

final debtsListProvider = FutureProvider.family<List<DebtModel>, String>((ref, type) async {
  ref.watch(debtRefreshProvider);
  final repo = ref.watch(debtRepositoryProvider);
  return repo.getAllDebts(type: type);
});

class DebtOverallSummary {
  final int totalDebtRemaining;
  final int totalReceivableRemaining;
  final int activeDebtCount;
  final int activeReceivableCount;

  const DebtOverallSummary({
    required this.totalDebtRemaining,
    required this.totalReceivableRemaining,
    required this.activeDebtCount,
    required this.activeReceivableCount,
  });
}

final debtOverallSummaryProvider = FutureProvider<DebtOverallSummary>((ref) async {
  ref.watch(debtRefreshProvider);
  final repo = ref.watch(debtRepositoryProvider);
  final all = await repo.getAllDebts();

  int debtRem = 0;
  int recRem = 0;
  int activeDebt = 0;
  int activeRec = 0;

  for (final DebtModel d in all) {
    if (!d.isSettled) {
      if (d.isDebt) {
        debtRem += d.remainingAmount;
        activeDebt++;
      } else {
        recRem += d.remainingAmount;
        activeRec++;
      }
    }
  }

  return DebtOverallSummary(
    totalDebtRemaining: debtRem,
    totalReceivableRemaining: recRem,
    activeDebtCount: activeDebt,
    activeReceivableCount: activeRec,
  );
});

