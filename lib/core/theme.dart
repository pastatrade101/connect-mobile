import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The look, in one place.
///
/// Taken from the Connect portal rather than invented: the same brand blue, the same
/// slate neutrals with a blue bias, and the same WhatsApp-derived chat surfaces — so
/// somebody moving between the browser and the phone recognises the product.
class Brand {
  const Brand._();

  static const blue = Color(0xFF1C84EE);
  static const blueDark = Color(0xFF1565C0);
  static const blueWash = Color(0xFFE8F1FD);

  static const ink = Color(0xFF101A2B);
  static const inkSoft = Color(0xFF3D4A5C);
  static const inkFaint = Color(0xFF6B7A8D);

  static const line = Color(0xFFE3E8EF);
  static const surface = Color(0xFFFFFFFF);
  static const ground = Color(0xFFF5F7FA);

  static const success = Color(0xFF0F7050);
  static const warning = Color(0xFFB58514);
  static const danger = Color(0xFFC0392B);

  // Chat surfaces, matching the portal's thread view.
  static const chatGround = Color(0xFFEFE7DE);
  static const bubbleIn = Color(0xFFFFFFFF);
  static const bubbleOut = Color(0xFFD9FDD3);
  static const chatBar = Color(0xFFF0F2F5);

  // Dark mode uses WhatsApp's own dark palette, as the portal does.
  static const darkGround = Color(0xFF0B141A);
  static const darkSurface = Color(0xFF141D2A);
  static const darkPanel = Color(0xFF202C33);
  static const darkLine = Color(0xFF2A3742);
  static const darkInk = Color(0xFFE9EDEF);
  static const darkInkSoft = Color(0xFF8696A0);
  static const darkBubbleOut = Color(0xFF005C4B);
}

ThemeData buildTheme({required Brightness brightness}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.blue,
    brightness: brightness,
    primary: dark ? const Color(0xFF63A8F0) : Brand.blue,
    surface: dark ? Brand.darkSurface : Brand.surface,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final onGround = dark ? Brand.darkInk : Brand.ink;
  final muted = dark ? Brand.darkInkSoft : Brand.inkFaint;

  return base.copyWith(
    scaffoldBackgroundColor: dark ? Brand.darkGround : Brand.ground,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? Brand.darkSurface : Brand.surface,
      foregroundColor: onGround,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: onGround,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: dark ? Brand.darkSurface : Brand.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: dark ? Brand.darkLine : Brand.line),
      ),
    ),
    dividerTheme: DividerThemeData(color: dark ? Brand.darkLine : Brand.line, thickness: 1, space: 1),
    textTheme: base.textTheme.apply(bodyColor: onGround, displayColor: onGround).copyWith(
          titleLarge: TextStyle(color: onGround, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4),
          titleMedium: TextStyle(color: onGround, fontSize: 16, fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(color: onGround, fontSize: 15, height: 1.4),
          bodySmall: TextStyle(color: muted, fontSize: 13, height: 1.35),
          labelSmall: TextStyle(color: muted, fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.6),
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: onGround,
        side: BorderSide(color: dark ? Brand.darkLine : Brand.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? Brand.darkPanel : Brand.ground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? Brand.darkLine : Brand.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? Brand.darkLine : Brand.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Brand.blue, width: 1.6),
      ),
      labelStyle: TextStyle(color: muted, fontSize: 14),
      hintStyle: TextStyle(color: muted, fontSize: 15),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? Brand.darkSurface : Brand.surface,
      indicatorColor: dark ? const Color(0xFF16283D) : Brand.blueWash,
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: muted),
      ),
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? Brand.darkPanel : Brand.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Initials for an avatar, from whatever name we actually have.
String initialsOf(String name) {
  final parts = name.trim().replaceAll(RegExp(r'^\+'), '').split(RegExp(r'\s+'));
  final letters = parts.where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join();
  return letters.isEmpty ? '#' : letters.toUpperCase();
}
