import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../data/services/biometric_service.dart';
import '../../security/providers/security_providers.dart';

class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBiometricEnabled = ref.watch(biometricLockEnabledProvider);
    final isLockOnResume = ref.watch(lockOnResumeEnabledProvider);
    final hardwareSupportedAsync = ref.watch(
      biometricHardwareSupportedProvider,
    );

    return Scaffold(
      backgroundColor: AppColors.surfaceOf(context),
      appBar: AppBar(
        title: Text(
          'Keamanan & Biometrik',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Status Hardware Biometrik
          hardwareSupportedAsync.when(
            data: (isSupported) =>
                _buildHardwareStatusCard(context, isSupported, isDark),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),

          // 2. Section Pengaturan Kunci
          _buildSectionHeader(context, 'PENGATURAN KUNCI APLIKASI'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: isBiometricEnabled,
                  activeThumbColor: AppColors.primary,
                  secondary: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.fingerprint_rounded,
                      color: isDark ? AppColors.primary : AppColors.primaryDark,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Kunci Sidik Jari / PIN',
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Wajibkan autentikasi saat Monetra dibuka',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 12,
                    ),
                  ),
                  onChanged: (val) async {
                    if (val) {
                      // Verifikasi sidik jari/PIN terlebih dahulu sebelum mengaktifkan
                      final ok = await BiometricService.authenticate(
                        localizedReason: 'Konfirmasi sidik jari atau PIN untuk mengaktifkan kunci aplikasi',
                      );
                      if (ok) {
                        await ref
                            .read(biometricLockEnabledProvider.notifier)
                            .setEnabled(true);
                        if (context.mounted) {
                          AppSnackBar.showSuccess(
                            context,
                            'Kunci biometrik berhasil diaktifkan',
                          );
                        }
                      }
                    } else {
                      // Mematikan kunci
                      final ok = await BiometricService.authenticate(
                        localizedReason: 'Konfirmasi sidik jari atau PIN untuk menonaktifkan kunci aplikasi',
                      );
                      if (ok) {
                        await ref
                            .read(biometricLockEnabledProvider.notifier)
                            .setEnabled(false);
                        if (context.mounted) {
                          AppSnackBar.showInfo(
                            context,
                            'Kunci biometrik dinonaktifkan',
                          );
                        }
                      }
                    }
                  },
                ),
                if (isBiometricEnabled) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    value: isLockOnResume,
                    activeThumbColor: AppColors.primary,
                    secondary: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.screen_lock_portrait_rounded,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Kunci Saat Keluar (Background)',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Kunci otomatis saat Anda beralih ke aplikasi lain',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 12,
                      ),
                    ),
                    onChanged: (val) async {
                      await ref
                          .read(lockOnResumeEnabledProvider.notifier)
                          .setEnabled(val);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Section Uji Coba Sensor
          _buildSectionHeader(context, 'PENGUJIAN SENSOR'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await BiometricService.authenticate(
                localizedReason: 'Uji coba verifikasi biometrik Monetra',
              );
              if (context.mounted) {
                if (ok) {
                  AppSnackBar.showSuccess(
                    context,
                    'Sensor biometrik berfungsi normal',
                  );
                } else {
                  AppSnackBar.showWarning(
                    context,
                    'Verifikasi dibatalkan atau tidak cocok',
                  );
                }
              }
            },
            icon: const Icon(Icons.touch_app_rounded, size: 20),
            label: const Text('Tes Sensor Biometrik Sekarang'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? AppColors.primary : AppColors.primaryDark,
              side: BorderSide(
                color: isDark ? AppColors.primary : AppColors.primaryDark,
                width: 1.2,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 4. Informasi Keamanan & Enkripsi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: isDark ? AppColors.primary : AppColors.primaryDark,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Autentikasi diproses langsung oleh modul keamanan perangkat keras (Hardware TEE).',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareStatusCard(
    BuildContext context,
    bool isSupported,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isSupported
            ? const Color(0xFF059669).withValues(alpha: 0.1)
            : Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSupported
              ? const Color(0xFF059669).withValues(alpha: 0.25)
              : Colors.amber.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSupported
                ? Icons.verified_user_rounded
                : Icons.lock_outline_rounded,
            color: isSupported
                ? const Color(0xFF059669)
                : Colors.amber.shade700,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSupported
                  ? 'Sensor biometrik aktif & siap digunakan'
                  : 'Menggunakan PIN / Pola kunci layar',
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: isSupported
                    ? (isDark
                          ? Colors.greenAccent.shade200
                          : const Color(0xFF059669))
                    : (isDark ? Colors.amber.shade200 : Colors.amber.shade900),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: AppTypography.labelSmall.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondaryOf(context),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
