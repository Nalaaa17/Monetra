import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.surface,
      cardColor: AppColors.surfaceCard,
      dividerColor: AppColors.divider,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.tertiary,
        error: AppColors.danger,
        surface: AppColors.surfaceCard,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        onPrimary: Colors.black,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      textTheme: baseTextTheme.copyWith(
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        bodySmall: baseTextTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        labelSmall: baseTextTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
      ).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceCard,
        indicatorColor: AppColors.primary.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryDark);
          }
          return const IconThemeData(color: AppColors.textSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            );
          }
          return const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        elevation: 4,
        shape: CircleBorder(),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.darkSurface,
      cardColor: AppColors.darkSurfaceCard,
      dividerColor: AppColors.darkDivider,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.tertiary,
        error: AppColors.danger,
        surface: AppColors.darkSurfaceCard,
        onSurface: AppColors.darkTextPrimary,
        onSurfaceVariant: AppColors.darkTextSecondary,
        onPrimary: Colors.black,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkDivider, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.darkTextPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
      ),
      textTheme: baseTextTheme.copyWith(
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: AppColors.darkTextSecondary),
        bodySmall: baseTextTheme.bodySmall?.copyWith(color: AppColors.darkTextSecondary),
        labelSmall: baseTextTheme.labelSmall?.copyWith(color: AppColors.darkTextSecondary),
      ).apply(
        bodyColor: AppColors.darkTextPrimary,
        displayColor: AppColors.darkTextPrimary,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.darkSurfaceCard,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurfaceCard,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurfaceCard,
        indicatorColor: AppColors.primary.withValues(alpha: 0.25),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary);
          }
          return const IconThemeData(color: AppColors.darkTextSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            );
          }
          return const TextStyle(
            color: AppColors.darkTextSecondary,
            fontSize: 12,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        elevation: 4,
        shape: CircleBorder(),
      ),
    );
  }
}
