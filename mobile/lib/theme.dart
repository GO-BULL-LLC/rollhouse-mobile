import 'package:flutter/material.dart';

class RH {
  static const bg = Color(0xFF141210);
  static const surface = Color(0xFF1E1B18);
  static const surface2 = Color(0xFF2A2622);
  static const line = Color(0xFF34302B);
  static const red = Color(0xFFD93A2B);
  static const gold = Color(0xFFE3A72F);
  static const text = Color(0xFFF4EFE8);
  static const muted = Color(0xFFA59C90);
  static const green = Color(0xFF3DBE74);
  static const radius = 18.0;
}

ThemeData buildTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
  final scheme = const ColorScheme.dark(
    primary: RH.red,
    onPrimary: Colors.white,
    secondary: RH.gold,
    onSecondary: Color(0xFF1A1206),
    surface: RH.surface,
    onSurface: RH.text,
    error: Color(0xFFFF6B5B),
  );
  final text = base.textTheme.apply(bodyColor: RH.text, displayColor: RH.text);
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: RH.bg,
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 15, height: 1.45),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: RH.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: RH.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: RH.text),
    ),
    cardTheme: const CardThemeData(color: RH.surface, elevation: 0, margin: EdgeInsets.zero),
    dividerTheme: const DividerThemeData(color: RH.line, space: 1, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: RH.surface,
      indicatorColor: RH.red.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      height: 66,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: s.contains(WidgetState.selected) ? RH.text : RH.muted),
      ),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? RH.red : RH.muted)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RH.red,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: RH.text,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: RH.line),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RH.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: RH.muted),
      hintStyle: const TextStyle(color: Color(0xFF7A7268)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: RH.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: RH.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: RH.gold, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFF6B5B))),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: RH.surface2,
      contentTextStyle: TextStyle(color: RH.text, fontSize: 15),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: RH.surface, surfaceTintColor: Colors.transparent),
    chipTheme: base.chipTheme.copyWith(backgroundColor: RH.surface, side: const BorderSide(color: RH.line)),
  );
}
