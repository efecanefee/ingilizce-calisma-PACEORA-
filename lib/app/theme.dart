import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paceora renk paleti: Lime Spark + Graphite
abstract class AppColors {
  // Marka renkleri
  static const limeSpark = Color(0xFFC6F432);
  static const limeDim = Color(0xFF9BC427);
  static const limeDark = Color(0xFF5A7414);

  // Graphite tonları
  static const graphite900 = Color(0xFF15171A);
  static const graphite800 = Color(0xFF1C1E22);
  static const graphite700 = Color(0xFF24272C);
  static const graphite600 = Color(0xFF2E3238);
  static const graphite400 = Color(0xFF6B7280);
  static const graphite200 = Color(0xFFD1D5DB);
  static const graphite100 = Color(0xFFE8EAED);
  static const graphite50 = Color(0xFFF7F8F9);

  // Durum renkleri
  static const success = Color(0xFF4ADE80);
  static const successDark = Color(0xFF166534);
  static const error = Color(0xFFF87171);
  static const errorDark = Color(0xFF991B1B);
  static const warning = Color(0xFFFBBF24);
}

ThemeData _base(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final colorScheme = isDark
      ? const ColorScheme.dark(
          primary: AppColors.limeSpark,
          onPrimary: AppColors.graphite900,
          secondary: AppColors.limeDim,
          onSecondary: AppColors.graphite900,
          surface: AppColors.graphite800,
          onSurface: AppColors.graphite50,
          surfaceContainerHighest: AppColors.graphite600,
          surfaceContainerHigh: AppColors.graphite700,
          surfaceContainer: AppColors.graphite700,
          surfaceContainerLow: AppColors.graphite800,
          surfaceContainerLowest: AppColors.graphite900,
          error: AppColors.error,
          onError: AppColors.graphite900,
          outline: AppColors.graphite400,
          outlineVariant: AppColors.graphite600,
        )
      : const ColorScheme.light(
          primary: AppColors.limeDark,
          onPrimary: Colors.white,
          secondary: AppColors.limeDim,
          onSecondary: AppColors.graphite900,
          surface: AppColors.graphite50,
          onSurface: AppColors.graphite900,
          surfaceContainerHighest: AppColors.graphite200,
          surfaceContainerHigh: AppColors.graphite100,
          surfaceContainer: Colors.white,
          surfaceContainerLow: Colors.white,
          surfaceContainerLowest: Colors.white,
          error: AppColors.errorDark,
          onError: Colors.white,
          outline: AppColors.graphite400,
          outlineVariant: AppColors.graphite200,
        );

  final textTheme = GoogleFonts.interTextTheme(
    ThemeData(brightness: brightness).textTheme,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor:
        isDark ? AppColors.graphite900 : AppColors.graphite50,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? AppColors.graphite900 : AppColors.graphite50,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: isDark ? AppColors.limeSpark : AppColors.limeDark,
        foregroundColor: isDark ? AppColors.graphite900 : Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? AppColors.limeSpark : AppColors.limeDark,
          width: 2,
        ),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: isDark ? AppColors.limeSpark : AppColors.limeDark,
      linearTrackColor: colorScheme.surfaceContainerHighest,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: colorScheme.outlineVariant),
    ),
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
  );
}

final lightTheme = _base(Brightness.light);
final darkTheme = _base(Brightness.dark);
