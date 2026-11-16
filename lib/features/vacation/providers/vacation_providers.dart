import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/vacation.dart';
import '../../../data/repositories/vacation_repository.dart';

final vacationRefreshTriggerProvider = StateProvider<int>((ref) => 0);

final vacationRepositoryProvider = Provider<VacationRepository>((ref) {
  return VacationRepository();
});

final activeVacationsProvider = FutureProvider<List<VacationModel>>((ref) async {
  ref.watch(vacationRefreshTriggerProvider);
  final repo = ref.watch(vacationRepositoryProvider);
  return await repo.getActiveVacations();
});

final completedVacationsProvider = FutureProvider<List<VacationModel>>((ref) async {
  ref.watch(vacationRefreshTriggerProvider);
  final repo = ref.watch(vacationRepositoryProvider);
  return await repo.getCompletedVacations();
});

final vacationDetailProvider =
    FutureProvider.family<VacationDetail?, int>((ref, vacationId) async {
  ref.watch(vacationRefreshTriggerProvider);
  final repo = ref.watch(vacationRepositoryProvider);
  return await repo.getVacationDetail(vacationId);
});
