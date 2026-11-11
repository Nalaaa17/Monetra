import 'package:flutter/material.dart';

class ColorHelper {
  ColorHelper._();

  /// Mem-parse string warna hex dengan aman untuk format `0xFFRRGGBB`,
  /// `#RRGGBB`, `#AARRGGBB`, atau `RRGGBB` tanpa pernah melempar FormatException.
  static Color parseHex(
    String? hex, {
    Color fallback = const Color(0xFF00D09E),
  }) {
    if (hex == null) return fallback;
    final trimmed = hex.trim();
    if (trimmed.isEmpty) return fallback;

    var cleaned = trimmed.toUpperCase();
    if (cleaned.startsWith('#')) {
      cleaned = cleaned.substring(1);
    } else if (cleaned.startsWith('0X')) {
      cleaned = cleaned.substring(2);
    }

    if (cleaned.length == 6) {
      cleaned = 'FF$cleaned';
    }
    if (cleaned.length != 8) return fallback;

    final parsed = int.tryParse(cleaned, radix: 16);
    if (parsed == null) return fallback;
    return Color(parsed);
  }
}

