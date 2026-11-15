import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';

class UserNameNotifier extends StateNotifier<String> {
  UserNameNotifier() : super('Sahabat Monetra') {
    loadName();
  }

  Future<void> loadName() async {
    try {
      final saved = await AppDatabase.getSetting('user_name');
      if (saved != null && saved.trim().isNotEmpty) {
        state = saved.trim();
      }
    } catch (_) {}
  }

  Future<void> setUserName(String name) async {
    final trimmed = name.trim();
    final finalName = trimmed.isNotEmpty ? trimmed : 'Sahabat Monetra';
    try {
      await AppDatabase.setSetting('user_name', finalName);
    } catch (_) {}
    state = finalName;
  }
}

final userNameProvider = StateNotifierProvider<UserNameNotifier, String>((ref) {
  return UserNameNotifier();
});

class OnboardingService {
  static Future<bool> isCompleted() async {
    try {
      final val = await AppDatabase.getSetting('onboarding_completed');
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<void> markCompleted({String? userName}) async {
    try {
      await AppDatabase.setSetting('onboarding_completed', 'true');
      if (userName != null && userName.trim().isNotEmpty) {
        await AppDatabase.setSetting('user_name', userName.trim());
      }
    } catch (_) {}
  }
}
