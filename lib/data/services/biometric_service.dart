import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import '../database/app_database.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static bool isAuthenticating = false;

  /// Memeriksa apakah perangkat memiliki sensor biometrik atau mendukung kunci perangkat
  static Future<bool> isBiometricSupported() async {
    try {
      final canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canAuthenticateWithBiometrics || isDeviceSupported;
    } catch (e) {
      debugPrint('Error checking biometric support: $e');
      return false;
    }
  }

  /// Mengambil daftar biometrik yang tersedia di perangkat (Fingerprint, Face, dll.)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Meminta autentikasi biometrik (sidik jari/wajah) atau PIN perangkat
  static Future<bool> authenticate({
    String localizedReason = 'Pindai sidik jari atau gunakan PIN perangkat untuk membuka Monetra',
  }) async {
    if (isAuthenticating) return false;
    try {
      isAuthenticating = true;
      final didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return didAuthenticate;
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    } finally {
      isAuthenticating = false;
    }
  }

  /// Membatalkan proses autentikasi yang sedang aktif jika ada
  static Future<void> cancelAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Pengaturan Tersimpan di Database
  // ---------------------------------------------------------------------------

  static const String keyBiometricEnabled = 'biometric_lock_enabled';
  static const String keyLockOnResume = 'biometric_lock_on_resume';

  static Future<bool> isBiometricLockEnabled() async {
    try {
      final val = await AppDatabase.getGlobalSetting(keyBiometricEnabled);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<void> setBiometricLockEnabled(bool enabled) async {
    await AppDatabase.setGlobalSetting(
      keyBiometricEnabled,
      enabled ? 'true' : 'false',
    );
  }

  static Future<bool> isLockOnResumeEnabled() async {
    try {
      final val = await AppDatabase.getGlobalSetting(keyLockOnResume);
      return val != 'false'; // Default aktif jika kunci biometrik dinyalakan
    } catch (_) {
      return true;
    }
  }

  static Future<void> setLockOnResumeEnabled(bool enabled) async {
    await AppDatabase.setGlobalSetting(
      keyLockOnResume,
      enabled ? 'true' : 'false',
    );
  }
}
