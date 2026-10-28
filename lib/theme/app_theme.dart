import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  /// Matches Wise Owl logo
  static const teal = Color(0xFF1A7570);
  static const tealDark = Color(0xFF0F4F4B);
  static const mint = Color(0xFF5EEAD4);
  static const gold = Color(0xFFF4D06F);
  static const coral = Color(0xFFE56B5D);
  static const logoBg = Color(0xFFF2EEE6);
  static const mist = Color(0xFFEEF6F4);
  static const ink = Color(0xFF142423);
  static const slate = Color(0xFF5C6B6A);
}

class AppTheme {
  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: Brightness.light,
      primary: AppColors.teal,
      secondary: AppColors.gold,
      tertiary: AppColors.coral,
      surface: AppColors.mist,
    );

    return _build(base, Brightness.light);
  }

  static ThemeData dark() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: Brightness.dark,
      primary: AppColors.mint,
      secondary: AppColors.gold,
      tertiary: AppColors.coral,
      surface: const Color(0xFF0C1918),
    );

    return _build(base, Brightness.dark);
  }

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      brightness == Brightness.light
          ? ThemeData.light().textTheme
          : ThemeData.dark().textTheme,
    ).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    final display = GoogleFonts.soraTextTheme(textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Solid surface — fixes black/empty screens on pushed routes
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme.copyWith(
        displayLarge: display.displayLarge?.copyWith(fontWeight: FontWeight.w600),
        displayMedium: display.displayMedium?.copyWith(fontWeight: FontWeight.w600),
        headlineLarge: display.headlineLarge?.copyWith(fontWeight: FontWeight.w600),
        headlineMedium: display.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
        headlineSmall: display.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: display.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: brightness == Brightness.light
            ? Colors.white
            : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? Colors.white
            : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.outline.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF102120),
        indicatorColor: scheme.primary.withValues(alpha: 0.15),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: 0.15),
        thickness: 1,
      ),
    );
  }

  static BoxDecoration pageGradient(Brightness brightness) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: brightness == Brightness.light
            ? const [
                Color(0xFFEEF6F4),
                Color(0xFFE4F0ED),
                Color(0xFFF7F4E8),
              ]
            : const [
                Color(0xFF081413),
                Color(0xFF0C1918),
                Color(0xFF141810),
              ],
      ),
    );
  }
}
