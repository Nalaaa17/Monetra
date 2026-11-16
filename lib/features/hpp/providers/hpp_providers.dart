import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/account.dart';
import '../../../data/models/category.dart';
import '../../../data/models/menu_item.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';

export '../../../data/models/menu_item.dart';
export '../utils/hpp_engine.dart';

final menuRefreshTriggerProvider = StateProvider<int>((ref) => 0);

final menusListProvider = FutureProvider<List<MenuItem>>((ref) async {
  ref.watch(menuRefreshTriggerProvider);
  final repo = ref.watch(menuRepositoryProvider);
  return await repo.getAllMenus();
});

final catalogAccountsProvider = FutureProvider<List<Account>>((ref) async {
  ref.watch(homeRefreshTriggerProvider);
  final repo = ref.watch(accountRepositoryProvider);
  return await repo.getAllAccounts();
});

final catalogCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  ref.watch(homeRefreshTriggerProvider);
  final repo = ref.watch(categoryRepositoryProvider);
  return await repo.getAllCategories();
});
