import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Warm editorial palette - cream surfaces, terracotta accent, warm charcoal
/// text - meant to read like a fashion lookbook rather than a stock
/// Material app. Headings use a serif display face; everything else uses a
/// clean grotesque for readability.
class AppTheme {
  AppTheme._();

  static const _cream = Color(0xFFFBF5EC);
  static const _surface = Color(0xFFFFFCF7);
  static const _surfaceDim = Color(0xFFF1E4D2);
  static const _terracotta = Color(0xFFB75B39);
  static const _terracottaDark = Color(0xFF8C4128);
  static const _onTerracotta = Color(0xFFFFF8F1);
  static const _charcoal = Color(0xFF2A2420);
  static const _warmGrey = Color(0xFF6B5F53);
  static const _outline = Color(0xFFDCCDB6);

  static const _darkSurface = Color(0xFF211C18);
  static const _darkSurfaceDim = Color(0xFF2B2521);
  static const _darkOnSurface = Color(0xFFF1E6D8);

  static TextTheme _textTheme(ColorScheme scheme) {
    final base = GoogleFonts.workSansTextTheme().apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final display = GoogleFonts.fraunces(fontWeight: FontWeight.w600);
    return base.copyWith(
      displayLarge: display.copyWith(fontSize: 40, color: scheme.onSurface),
      displayMedium: display.copyWith(fontSize: 32, color: scheme.onSurface),
      headlineLarge: display.copyWith(fontSize: 28, color: scheme.onSurface),
      headlineMedium: display.copyWith(fontSize: 24, color: scheme.onSurface),
      headlineSmall: display.copyWith(fontSize: 20, color: scheme.onSurface),
      titleLarge: display.copyWith(fontSize: 18, color: scheme.onSurface),
    );
  }

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: _terracotta,
      onPrimary: _onTerracotta,
      primaryContainer: Color(0xFFF3D9C6),
      onPrimaryContainer: Color(0xFF5C2811),
      secondary: _warmGrey,
      onSecondary: Colors.white,
      secondaryContainer: _surfaceDim,
      onSecondaryContainer: _charcoal,
      surface: _surface,
      onSurface: _charcoal,
      surfaceContainerHighest: _surfaceDim,
      onSurfaceVariant: _warmGrey,
      outline: _outline,
      error: Color(0xFFB3261E),
    );
    return _build(scheme, _cream);
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: Color(0xFFE0906D),
      onPrimary: Color(0xFF4A2110),
      primaryContainer: _terracottaDark,
      onPrimaryContainer: Color(0xFFFFDCC7),
      secondary: Color(0xFFD3C2AC),
      onSecondary: Color(0xFF3A2F22),
      secondaryContainer: _darkSurfaceDim,
      onSecondaryContainer: _darkOnSurface,
      surface: _darkSurface,
      onSurface: _darkOnSurface,
      surfaceContainerHighest: _darkSurfaceDim,
      onSurfaceVariant: Color(0xFFC9B9A6),
      outline: Color(0xFF524539),
      error: Color(0xFFE6857C),
    );
    return _build(scheme, const Color(0xFF1A1613));
  }

  static ThemeData _build(ColorScheme scheme, Color scaffoldBackground) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: _textTheme(scheme),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scaffoldBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.workSans(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        labelStyle: GoogleFonts.workSans(color: scheme.onSurface),
        secondaryLabelStyle: GoogleFonts.workSans(color: scheme.onPrimaryContainer),
        shape: StadiumBorder(side: BorderSide(color: scheme.outline)),
        side: BorderSide.none,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: GoogleFonts.workSans(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, space: 32),
    );
  }
}
