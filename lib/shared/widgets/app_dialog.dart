import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// Tipe alert dialog di Monetra untuk menentukan palet warna & ikon ambient.
enum AppDialogType {
  danger, // Merah / Destructive (Hapus, Buang)
  warning, // Amber / Kehati-hatian (Saldo kurang, Konfirmasi penting)
  info, // Biru / Sky (Informasi, Alur baru)
  success, // Hijau / Emerald (Selesai, Pencapaian)
}

/// Dialog modern, elegan, dan obsidian-styled untuk seluruh aplikasi Monetra.
class AppDialog extends StatelessWidget {
  final AppDialogType type;
  final IconData? icon;
  final String title;
  final String? message;
  final Widget? contentCustom;
  final String confirmLabel;
  final String? cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  const AppDialog({
    super.key,
    this.type = AppDialogType.info,
    this.icon,
    required this.title,
    this.message,
    this.contentCustom,
    this.confirmLabel = 'Lanjutkan',
    this.cancelLabel = 'Batal',
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
  });

  /// Helper statis untuk konfirmasi umum (Yes / No).
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Lanjutkan',
    String cancelLabel = 'Batal',
    AppDialogType type = AppDialogType.warning,
    IconData? icon,
    Widget? contentCustom,
    bool isDestructive = false,
  }) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) => AppDialog(
        type: type,
        icon: icon,
        title: title,
        message: message,
        contentCustom: contentCustom,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.pop(ctx, true),
        onCancel: () => Navigator.pop(ctx, false),
      ),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
    return result == true;
  }

  /// Helper statis khusus konfirmasi Hapus (Destructive Delete).
  static Future<bool> delete(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Hapus',
    String cancelLabel = 'Batal',
    IconData icon = Icons.delete_outline_rounded,
    Widget? contentCustom,
  }) {
    return confirm(
      context,
      type: AppDialogType.danger,
      icon: icon,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: true,
      contentCustom: contentCustom,
    );
  }

  /// Helper statis untuk alert informasi / peringatan satu tombol.
  static Future<void> alert(
    BuildContext context, {
    required String title,
    required String message,
    String actionLabel = 'Mengerti',
    AppDialogType type = AppDialogType.info,
    IconData? icon,
    Widget? contentCustom,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) => AppDialog(
        type: type,
        icon: icon,
        title: title,
        message: message,
        contentCustom: contentCustom,
        confirmLabel: actionLabel,
        cancelLabel: null, // Tanpa tombol batal
        onConfirm: () => Navigator.pop(ctx),
      ),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
  }

  Color _getAccentColor() {
    switch (type) {
      case AppDialogType.danger:
        return AppColors.danger;
      case AppDialogType.warning:
        return const Color(0xFFF59E0B);
      case AppDialogType.info:
        return const Color(0xFF0284C7);
      case AppDialogType.success:
        return const Color(0xFF10B981);
    }
  }

  IconData _getDefaultIcon() {
    if (icon != null) return icon!;
    switch (type) {
      case AppDialogType.danger:
        return Icons.delete_outline_rounded;
      case AppDialogType.warning:
        return Icons.warning_amber_rounded;
      case AppDialogType.info:
        return Icons.info_outline_rounded;
      case AppDialogType.success:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _getAccentColor();
    final effectiveIcon = _getDefaultIcon();

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ambient Glow Icon Badge
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.withValues(alpha: 0.28),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.22),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      effectiveIcon,
                      color: accent,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Judul
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.2,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),

                // Pesan Deskripsi
                if (message != null && message!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],

                // Custom Slot / Widget Tambahan
                if (contentCustom != null) ...[
                  const SizedBox(height: 14),
                  contentCustom!,
                ],

                const SizedBox(height: 22),

                // Tombol Aksi
                Row(
                  children: [
                    if (cancelLabel != null) ...[
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: TextButton(
                            onPressed: onCancel ?? () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04),
                              foregroundColor: AppColors.textPrimaryOf(context),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                ),
                              ),
                            ),
                            child: Text(
                              cancelLabel!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: onConfirm ?? () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDestructive
                                ? AppColors.danger
                                : (type == AppDialogType.warning
                                    ? const Color(0xFFF59E0B)
                                    : (type == AppDialogType.danger
                                        ? AppColors.danger
                                        : (type == AppDialogType.success
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFF0284C7)))),
                            foregroundColor: (type == AppDialogType.warning &&
                                    !isDestructive)
                                ? Colors.black
                                : Colors.white,
                            elevation: 0,
                            shadowColor: accent.withValues(alpha: 0.35),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            confirmLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
