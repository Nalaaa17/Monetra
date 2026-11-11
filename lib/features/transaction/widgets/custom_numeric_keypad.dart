import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

class CustomNumericKeypad extends StatelessWidget {
  final ValueChanged<String> onKeyPress;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  /// Menerapkan input tombol keypad ('0'-'9' atau '000') ke string nominal mentah.
  static String applyKey(
    String currentRaw,
    String key, {
    int maxLength = 10,
  }) {
    final base = currentRaw.isEmpty ? '0' : currentRaw;
    if (base == '0') {
      if (key == '000' || key == '0') return '0';
      return key;
    }
    if (base.length + key.length > maxLength) return base;
    return base + key;
  }

  /// Menghapus 1 digit terakhir dari string nominal mentah.
  static String applyBackspace(String currentRaw) {
    if (currentRaw.length <= 1) return '0';
    return currentRaw.substring(0, currentRaw.length - 1);
  }

  const CustomNumericKeypad({
    super.key,
    required this.onKeyPress,
    required this.onBackspace,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, -4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow(context, ['1', '2', '3']),
          const SizedBox(height: 8),
          _buildRow(context, ['4', '5', '6']),
          const SizedBox(height: 8),
          _buildRow(context, ['7', '8', '9']),
          const SizedBox(height: 8),
          _buildBottomRow(context),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<String> keys) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildKeyButton(
              context: context,
              child: Text(
                key,
                style: AppTypography.titleLarge.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                onKeyPress(key);
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomRow(BuildContext context) {
    return Row(
      children: [
        // 000 (Rupiah shortcut)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildKeyButton(
              context: context,
              child: Text(
                '000',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.primaryDark,
                ),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                onKeyPress('000');
              },
            ),
          ),
        ),
        // 0
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildKeyButton(
              context: context,
              child: Text(
                '0',
                style: AppTypography.titleLarge.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                onKeyPress('0');
              },
            ),
          ),
        ),
        // Backspace
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildKeyButton(
              context: context,
              child: Icon(
                Icons.backspace_outlined,
                size: 22,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                onBackspace();
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                onClear();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeyButton({
    required BuildContext context,
    required Widget child,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btnBg = isDark ? const Color(0xFF334155) : const Color(0xFFF9FAFB);

    return Material(
      color: btnBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.primary.withValues(alpha: 0.2),
        highlightColor: AppColors.primary.withValues(alpha: 0.1),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

