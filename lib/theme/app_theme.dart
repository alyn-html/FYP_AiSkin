import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/theme_store.dart';

class AppColors {
  static bool get _dark => ThemeStore.instance.isDark.value;

  // Card/surface background — was a literal Colors.white across every screen.
  // Screens that still use Colors.white directly for cards won't react to dark mode
  // until those are switched to AppColors.surface — a follow-up pass, file by file.
  static Color get surface => _dark ? _darkSurface : _lightSurface;

  static Color get cream => _dark ? _darkCream : _lightCream;
  static Color get textDark => _dark ? _darkTextDark : _lightTextDark;
  static Color get coral => _dark ? _darkCoral : _lightCoral;
  static Color get coralDeep => _dark ? _darkCoralDeep : _lightCoralDeep;
  static Color get rose => _dark ? _darkRose : _lightRose;
  static Color get green => _dark ? _darkGreen : _lightGreen;
  static Color get purple => _dark ? _darkPurple : _lightPurple;

  // Light palette (original)
  static const _lightCream = Color(0xFFFFF7E8);
  static const _lightTextDark = Color(0xFF3D2C2C);
  static const _lightCoral = Color(0xFFF28B8F);
  static const _lightCoralDeep = Color(0xFFE8737A);
  static const _lightRose = Color(0xFFC0A0A0);
  static const _lightGreen = Color(0xFFA8D08D);
  static const _lightPurple = Color(0xFFB890C8);
  static const _lightSurface = Colors.white;

  // Dark palette — dark brown/near-black base with a purple undertone, brighter accent pops.
  static const _darkCream = Color(0xFF1C1418);
  static const _darkTextDark = Color(0xFFF5E6E8);
  static const _darkCoral = Color(0xFFFF8FA3);
  static const _darkCoralDeep = Color(0xFFFF6B85);
  static const _darkRose = Color(0xFFD9A8B0);
  static const _darkGreen = Color(0xFFA8D08D);
  static const _darkPurple = Color(0xFFD4A5E8);
  static const _darkSurface = Color(0xFF2E2029);
}

ThemeData buildAppTheme() {
  final baseText = GoogleFonts.nunitoTextTheme();
  final displayText = GoogleFonts.frauncesTextTheme();
  final dark = ThemeStore.instance.isDark.value;
  final brightness = dark ? Brightness.dark : Brightness.light;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: AppColors.cream,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.coral,
      brightness: brightness,
      primary: AppColors.coral,
      surface: AppColors.cream,
    ),
    textTheme: baseText.copyWith(
      headlineLarge: displayText.headlineLarge?.copyWith(color: AppColors.textDark),
      headlineMedium: displayText.headlineMedium?.copyWith(color: AppColors.textDark),
      titleLarge: displayText.titleLarge?.copyWith(color: AppColors.textDark),
      bodyLarge: baseText.bodyLarge?.copyWith(color: AppColors.textDark),
      bodyMedium: baseText.bodyMedium?.copyWith(color: AppColors.textDark),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.textDark,
      elevation: 0,
    ),
  );
}