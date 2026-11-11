import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/bank_brands.dart';
import 'color_helper.dart';

class BankLogoHelper {
  /// Mengembalikan metadata merk bank/e-wallet yang paling cocok
  static BankBrand? resolveBrand(String accountName, {String? logoKey}) {
    return BankBrands.resolve(logoKey: logoKey, accountName: accountName);
  }

  /// Mengembalikan path asset logo resmi bank/dompet jika tersedia
  static String? getAssetLogo(String accountName, {String? logoKey}) {
    return resolveBrand(accountName, logoKey: logoKey)?.assetPath;
  }

  /// Menampilkan logo resmi bank/dompet dalam badge terstandar,
  /// atau emblem monogram estetik jika akun memakai nama kustom non-merk.
  static Widget buildAccountBadge({
    required BuildContext context,
    required String accountName,
    required Color accountColor,
    String? logoKey,
    int? iconCodePoint,
    double size = 38,
    double iconSize = 20,
    double borderRadius = 12,
    bool showBackground = true,
  }) {
    final brand = resolveBrand(accountName, logoKey: logoKey);

    if (brand != null) {
      return buildBrandBadge(
        context: context,
        brand: brand,
        borderColor: accountColor,
        size: size,
        borderRadius: borderRadius,
        fallback: _buildCustomEmblem(
          accountName: accountName,
          accountColor: accountColor,
          size: size,
          borderRadius: borderRadius,
        ),
      );
    }

    return _buildCustomEmblem(
      accountName: accountName,
      accountColor: accountColor,
      size: size,
      borderRadius: borderRadius,
    );
  }

  /// Menampilkan widget logo dari sebuah [BankBrand]
  static Widget buildBrandBadge({
    required BuildContext context,
    required BankBrand brand,
    Color? borderColor,
    double size = 38,
    double borderRadius = 12,
    Widget? fallback,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCash = brand.key == 'cash';
    final effectiveColor =
        borderColor ?? ColorHelper.parseHex(brand.colorHex);
    final innerPad = isCash ? 0.0 : (size <= 20 ? 2.5 : (size * 0.13).clamp(3.0, 7.0));

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(innerPad),
      decoration: BoxDecoration(
        color: isCash
            ? Colors.transparent
            : (isDark ? Colors.white.withValues(alpha: 0.96) : Colors.white),
        borderRadius: BorderRadius.circular(borderRadius),
        border: isCash
            ? null
            : Border.all(
                color: effectiveColor.withValues(alpha: 0.25),
                width: size <= 20 ? 0.6 : 1,
              ),
        boxShadow: isCash || size <= 20
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                )
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular((borderRadius - 2).clamp(2.0, 24.0)),
        child: SizedBox.expand(
          child: brand.isSvg
              ? SvgPicture.asset(
                  brand.assetPath,
                  width: size - innerPad * 2,
                  height: size - innerPad * 2,
                  fit: BoxFit.contain,
                  placeholderBuilder: (_) =>
                      fallback ?? _shimmerPlaceholder(size, effectiveColor),
                )
              : Image.asset(
                  brand.assetPath,
                  width: size - innerPad * 2,
                  height: size - innerPad * 2,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) =>
                      fallback ??
                      _buildCustomEmblem(
                        accountName: brand.displayName,
                        accountColor: effectiveColor,
                        size: size,
                        borderRadius: borderRadius,
                      ),
                ),
        ),
      ),
    );
  }

  static Widget _shimmerPlaceholder(double size, Color color) {
    return Container(
      width: size,
      height: size,
      color: color.withValues(alpha: 0.1),
    );
  }

  /// Emblem monogram gradien berwarna — memastikan akun dengan nama bebas
  /// sekalipun tetap memiliki badge logo yang rapi dan berkarakter.
  static Widget _buildCustomEmblem({
    required String accountName,
    required Color accountColor,
    required double size,
    required double borderRadius,
  }) {
    final initials = _extractInitials(accountName);
    final darker = HSLColor.fromColor(accountColor)
        .withLightness((HSLColor.fromColor(accountColor).lightness - 0.12).clamp(0.15, 0.85))
        .toColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accountColor, darker],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: size <= 20
            ? null
            : [
                BoxShadow(
                  color: accountColor.withValues(alpha: 0.28),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: (size * 0.36).clamp(7.0, 18.0),
            letterSpacing: initials.length > 1 ? 0.5 : 0,
          ),
        ),
      ),
    );
  }

  static String _extractInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return '?';
    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    if (clean.length >= 2) {
      return clean.substring(0, 2).toUpperCase();
    }
    return clean[0].toUpperCase();
  }
}
