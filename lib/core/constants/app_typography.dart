import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextStyle get headlineLarge => GoogleFonts.plusJakartaSans(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      );

  static TextStyle get headlineMedium => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get titleLarge => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get titleMedium => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get bodyLarge => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get bodyMedium => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get labelSmall => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      );
}
