import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

enum AppSnackBarType {
  success,
  error,
  warning,
  info,
}

/// Helper untuk menampilkan toast / SnackBar modern, mengambang (floating), dan elegan.
class AppSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    AppSnackBarType type = AppSnackBarType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 1600),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color iconColor;
    Color iconBgColor;
    IconData icon;

    switch (type) {
      case AppSnackBarType.success:
        iconColor = const Color(0xFF10B981);
        iconBgColor = const Color(0xFF10B981).withValues(alpha: 0.16);
        icon = Icons.check_circle_rounded;
        break;
      case AppSnackBarType.error:
        iconColor = AppColors.danger;
        iconBgColor = AppColors.danger.withValues(alpha: 0.16);
        icon = Icons.error_rounded;
        break;
      case AppSnackBarType.warning:
        iconColor = const Color(0xFFF59E0B);
        iconBgColor = const Color(0xFFF59E0B).withValues(alpha: 0.16);
        icon = Icons.warning_rounded;
        break;
      case AppSnackBarType.info:
        iconColor = const Color(0xFF0284C7);
        iconBgColor = const Color(0xFF0284C7).withValues(alpha: 0.16);
        icon = Icons.info_rounded;
        break;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    onAction();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: iconColor,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message: message, type: AppSnackBarType.success);
  }

  static void showError(BuildContext context, String message) {
    show(context, message: message, type: AppSnackBarType.error);
  }

  static void showWarning(BuildContext context, String message) {
    show(context, message: message, type: AppSnackBarType.warning);
  }

  static void showInfo(BuildContext context, String message) {
    show(context, message: message, type: AppSnackBarType.info);
  }
}
