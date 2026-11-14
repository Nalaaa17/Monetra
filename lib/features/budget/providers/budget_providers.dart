import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/category_budget.dart';
import '../../../shared/providers/repository_providers.dart';

final selectedBudgetMonthProvider = StateProvider<DateTime>(
  (ref) => DateTime(DateTime.now().year, DateTime.now().month, 1),
);

final budgetRefreshTriggerProvider = StateProvider<int>((ref) => 0);

final categoryBudgetsProvider =
    FutureProvider<List<CategoryBudget>>((ref) async {
  ref.watch(budgetRefreshTriggerProvider);
  final selectedMonth = ref.watch(selectedBudgetMonthProvider);
  final repo = ref.watch(budgetRepositoryProvider);
  return await repo.getCategoryBudgets(
    selectedMonth.year,
    selectedMonth.month,
  );
});

final overallBudgetSummaryProvider =
    FutureProvider<OverallBudgetSummary>((ref) async {
  ref.watch(budgetRefreshTriggerProvider);
  final selectedMonth = ref.watch(selectedBudgetMonthProvider);
  final repo = ref.watch(budgetRepositoryProvider);
  return await repo.getOverallBudgetSummary(
    selectedMonth.year,
    selectedMonth.month,
  );
});

