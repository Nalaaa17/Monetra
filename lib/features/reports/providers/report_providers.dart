import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';

final selectedReportDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

final monthlyReportProvider = FutureProvider<MonthlyReportSummary>((ref) async {
  ref.watch(homeRefreshTriggerProvider);
  final selectedDate = ref.watch(selectedReportDateProvider);
  final repo = ref.watch(reportRepositoryProvider);

  return await repo.getMonthlyReport(selectedDate.year, selectedDate.month);
});

final sixMonthTrendProvider =
    FutureProvider<List<MonthlyCashflowPoint>>((ref) async {
  ref.watch(homeRefreshTriggerProvider);
  final selectedDate = ref.watch(selectedReportDateProvider);
  final repo = ref.watch(reportRepositoryProvider);

  return await repo.getSixMonthTrend(selectedDate.year, selectedDate.month);
});

final touchedCategoryIndexProvider = StateProvider<int?>((ref) => null);

