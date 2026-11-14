import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/investment_model.dart';
import '../../../shared/providers/repository_providers.dart';

export '../../../data/models/investment_model.dart';

final investmentRefreshProvider = StateProvider<int>((ref) => 0);

final investmentCategoryFilterProvider = StateProvider<String?>((ref) => null);

final investmentsListProvider = FutureProvider<List<InvestmentModel>>((ref) async {
  ref.watch(investmentRefreshProvider);
  final category = ref.watch(investmentCategoryFilterProvider);
  final repo = ref.watch(investmentRepositoryProvider);
  return repo.getAllInvestments(category: category);
});

final investmentSummaryProvider = FutureProvider<InvestmentSummary>((ref) async {
  ref.watch(investmentRefreshProvider);
  final repo = ref.watch(investmentRepositoryProvider);
  return repo.getSummary();
});

