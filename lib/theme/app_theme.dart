import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Theme-aware palette. Colours resolve against [AppColors.isDark], which the
/// app sets from the active [ThemeController] before building the tree. All
/// members are getters (not const) so a single toggle recolours the whole app.
class AppColors {
  static bool isDark = false;

  // Brand accents (mostly shared; primary brightens slightly in dark).
  static Color get primary => isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
  static Color get primaryLight => const Color(0xFF60A5FA);
  static Color get purple => const Color(0xFFA78BFA);
  static Color get green => const Color(0xFF22C55E);
  static Color get red => const Color(0xFFEF4444);
  static Color get slate => const Color(0xFF64748B);

  // Neutrals flip with the theme.
  static Color get background => isDark ? const Color(0xFF0B1120) : const Color(0xFFFFFFFF);
  static Color get surface => isDark ? const Color(0xFF141C2E) : const Color(0xFFF8FAFC);
  // A slightly raised surface for cards that sit on top of `surface`.
  static Color get surfaceHigh => isDark ? const Color(0xFF1B2436) : const Color(0xFFFFFFFF);
  static Color get border => isDark ? const Color(0xFF25304A) : const Color(0xFFE2E8F0);
  static Color get textPrimary => isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  static Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color get textMuted => isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  // Depth. Soft, low-opacity shadows read as premium; borders alone read flat.
  static Color get _shadowColor => isDark ? Colors.black.withOpacity(0.45) : const Color(0xFF0F172A).withOpacity(0.07);
  static List<BoxShadow> get softShadow => [
        BoxShadow(color: _shadowColor, blurRadius: 12, offset: const Offset(0, 4), spreadRadius: -6),
      ];
  static List<BoxShadow> get cardShadow => [
        BoxShadow(color: _shadowColor, blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -10),
      ];
}

/// Corner-radius scale. Use these instead of ad-hoc numbers so the whole app
/// shares one rhythm: [chip] pills, [sm] inputs/small cards, [md] cards,
/// [lg] sheets/hero cards.
class AppRadius {
  static const double chip = 999;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
}

class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    // Resolve palette for this theme (AppColors.isDark is also set globally by
    // the app shell before build; this keeps ThemeData self-consistent).
    final bg = isDark ? const Color(0xFF0B1120) : const Color(0xFFFFFFFF);
    final surface = isDark ? const Color(0xFF141C2E) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF25304A) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textMuted = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    final primary = isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        surface: surface,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: bg,
      textTheme: GoogleFonts.interTextTheme(TextTheme(
        displayLarge: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -1.5),
        displayMedium: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -1.0),
        displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5),
        headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textPrimary),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textSecondary),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: textMuted),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.1),
        labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textSecondary),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted, letterSpacing: 0.5),
      )),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: border, width: 1.5),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.inter(fontSize: 15, color: textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    );
  }
}
