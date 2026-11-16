import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/profile_labels.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/profile_model.dart';
import '../../budget/providers/budget_providers.dart';
import '../../debts/providers/debt_providers.dart';
import '../../history/providers/history_providers.dart';
import '../../home/providers/home_providers.dart';
import '../../investasi/providers/investasi_providers.dart';

export '../../../data/models/profile_model.dart';
export '../../../core/utils/profile_labels.dart';

final profileRefreshTriggerProvider = StateProvider<int>((ref) => 0);

final activeProfileKeyProvider = FutureProvider<String>((ref) async {
  ref.watch(profileRefreshTriggerProvider);
  return await AppDatabase.getActiveProfileKey();
});

final profilesListProvider = FutureProvider<List<ProfileModel>>((ref) async {
  ref.watch(profileRefreshTriggerProvider);
  return await AppDatabase.getAllProfiles();
});

final activeProfileProvider = FutureProvider<ProfileModel>((ref) async {
  final activeKey = await ref.watch(activeProfileKeyProvider.future);
  final profile = await AppDatabase.getProfileByKey(activeKey);
  return profile ??
      ProfileModel(
        key: AppDatabase.defaultProfileKey,
        name: 'Pribadi',
        type: 'personal',
        iconCodePoint: 0xe491,
        colorHex: '0xFF10B981',
        createdAt: DateTime.now(),
      );
});

final profileLabelsProvider = Provider<ProfileLabels>((ref) {
  final profile = ref.watch(activeProfileProvider).valueOrNull;
  return ProfileLabels(profile);
});

/// Fungsi pengendali untuk beralih profil dan memicu sinkronisasi seluruh state aplikasi
Future<void> switchActiveProfile(WidgetRef ref, String targetKey) async {
  await AppDatabase.switchProfile(targetKey);
  ref.read(profileRefreshTriggerProvider.notifier).state++;
  ref.read(homeRefreshTriggerProvider.notifier).state++;
  ref.read(budgetRefreshTriggerProvider.notifier).state++;
  ref.read(debtRefreshProvider.notifier).state++;
  ref.read(investmentRefreshProvider.notifier).state++;
  ref.read(historyFilterProvider.notifier).state = const HistoryFilter();
}
