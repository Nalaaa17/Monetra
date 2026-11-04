import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';

final goalsListProvider = FutureProvider<List<GoalDetail>>((ref) async {
  ref.watch(homeRefreshTriggerProvider);
  final repo = ref.watch(goalRepositoryProvider);
  return await repo.getAllGoals();
});

final upcomingUrgentGoalsProvider =
    FutureProvider<List<GoalDetail>>((ref) async {
  ref.watch(homeRefreshTriggerProvider);
  final repo = ref.watch(goalRepositoryProvider);
  return await repo.getUpcomingUrgentGoals(limit: 2);
});

