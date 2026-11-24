import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/services/biometric_service.dart';

class BiometricLockNotifier extends StateNotifier<bool> {
  BiometricLockNotifier() : super(false) {
    loadSetting();
  }

  Future<void> loadSetting() async {
    final enabled = await BiometricService.isBiometricLockEnabled();
    state = enabled;
  }

  Future<void> setEnabled(bool value) async {
    await BiometricService.setBiometricLockEnabled(value);
    state = value;
  }
}

final biometricLockEnabledProvider =
    StateNotifierProvider<BiometricLockNotifier, bool>((ref) {
  return BiometricLockNotifier();
});

class LockOnResumeNotifier extends StateNotifier<bool> {
  LockOnResumeNotifier() : super(true) {
    loadSetting();
  }

  Future<void> loadSetting() async {
    final enabled = await BiometricService.isLockOnResumeEnabled();
    state = enabled;
  }

  Future<void> setEnabled(bool value) async {
    await BiometricService.setLockOnResumeEnabled(value);
    state = value;
  }
}

final lockOnResumeEnabledProvider =
    StateNotifierProvider<LockOnResumeNotifier, bool>((ref) {
  return LockOnResumeNotifier();
});

/// Menyimpan status apakah layar aplikasi saat ini sedang terkunci
final isAppLockedProvider = StateProvider<bool>((ref) => false);

/// Menandai bahwa pengguna sedang mengakses menu catat cepat tanpa login penuh
final isQuickAccessActiveProvider = StateProvider<bool>((ref) => false);

/// Menyimpan informasi apakah hardware perangkat mendukung biometrik
final biometricHardwareSupportedProvider = FutureProvider<bool>((ref) async {
  return await BiometricService.isBiometricSupported();
});
