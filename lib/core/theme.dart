import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light, dark, or whatever the phone is doing — remembered between launches.
///
/// A notifier rather than a state-management package: one value, read in one
/// place, changed from one screen.
class AppTheme {
  const AppTheme._();

  static final mode = ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    mode.value = _parse(prefs.getString('themeMode'));
  }

  static Future<void> set(ThemeMode next) async {
    mode.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', next.name);
  }

  static ThemeMode _parse(String? raw) => switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

/// The look, in one place.
///
/// Taken from the Connect portal rather than invented: the same brand blue, the same
/// slate neutrals with a blue bias, and the same WhatsApp-derived chat surfaces — so
/// somebody moving between the browser and the phone recognises the product.
class Brand {
  const Brand._();

  // ── light ───────────────────────────────────────────────────────────────────
  static const blue = Color(0xFF1C84EE);
  static const blueDark = Color(0xFF1565C0);
  static const blueWash = Color(0xFFE8F1FD);

  static const ink = Color(0xFF101A2B);
  static const inkSoft = Color(0xFF3D4A5C);
  static const inkFaint = Color(0xFF6B7A8D);

  static const line = Color(0xFFE3E8EF);
  static const surface = Color(0xFFFFFFFF);
  static const ground = Color(0xFFF5F7FA);

  static const success = Color(0xFF0E8A5F);
  static const warning = Color(0xFFB07100);
  static const danger = Color(0xFFD1352B);

  // Chat surfaces, matching the portal's thread view.
  static const chatGround = Color(0xFFEFE7DE);
  static const bubbleIn = Color(0xFFFFFFFF);
  static const bubbleOut = Color(0xFFD9FDD3);
  static const chatBar = Color(0xFFF0F2F5);

  // ── dark ────────────────────────────────────────────────────────────────────
  //
  // A settled black to sit on, three steps of surface above it, and accents that
  // are BRIGHTER than their light-mode twins rather than the same colour dimmed.
  // A #0E8A5F green is readable on white and nearly invisible on black; the dark
  // palette therefore has its own values, chosen for contrast on this ground.
  static const darkGround = Color(0xFF07090C);
  static const darkSurface = Color(0xFF12161C);
  static const darkPanel = Color(0xFF1A2029);
  static const darkLine = Color(0xFF283240);
  static const darkInk = Color(0xFFF3F6FA);
  static const darkInkSoft = Color(0xFF9BAABA);

  static const darkBlue = Color(0xFF4CA3FF);
  static const darkBlueWash = Color(0xFF10263D);
  static const darkSuccess = Color(0xFF35D48A);
  static const darkWarning = Color(0xFFFFB224);
  static const darkDanger = Color(0xFFFF6B61);

  static const darkChatGround = Color(0xFF0A0F14);
  static const darkBubbleIn = Color(0xFF1B242E);
  static const darkBubbleOut = Color(0xFF0B5C4A);
}

/// The ground the app sits on.
///
/// Flat in daylight; at night a slow gradient with a cool lift at the top and a
/// warmer one low down, so a screen of dark rows is not a flat black rectangle.
/// Kept deliberately low-contrast — this is depth behind the content, never
/// something that competes with it for attention.
BoxDecoration appBackground(BuildContext context) {
  if (Theme.of(context).brightness != Brightness.dark) {
    return const BoxDecoration(color: Brand.ground);
  }
  return const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: [0.0, 0.45, 1.0],
      colors: [
        Color(0xFF0B1524), // a blue lift where the header sits
        Color(0xFF07090C), // the settled black through the middle
        Color(0xFF12101B), // a violet warmth under the nav
      ],
    ),
  );
}

/// The same colour, in whichever theme is on screen.
///
/// Every accent in this app goes through here. Reading a raw `Brand.success` in a
/// widget is how you end up with dark green text on a black card — the light value
/// looks right in the editor and disappears on the device.
class Tone {
  const Tone._();

  static bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  static Color blue(BuildContext c) => isDark(c) ? Brand.darkBlue : Brand.blue;
  static Color blueWash(BuildContext c) => isDark(c) ? Brand.darkBlueWash : Brand.blueWash;
  static Color success(BuildContext c) => isDark(c) ? Brand.darkSuccess : Brand.success;
  static Color warning(BuildContext c) => isDark(c) ? Brand.darkWarning : Brand.warning;
  static Color danger(BuildContext c) => isDark(c) ? Brand.darkDanger : Brand.danger;

  static Color ink(BuildContext c) => isDark(c) ? Brand.darkInk : Brand.ink;
  static Color muted(BuildContext c) => isDark(c) ? Brand.darkInkSoft : Brand.inkFaint;
  static Color line(BuildContext c) => isDark(c) ? Brand.darkLine : Brand.line;
  static Color surface(BuildContext c) => isDark(c) ? Brand.darkSurface : Brand.surface;
  static Color panel(BuildContext c) => isDark(c) ? Brand.darkPanel : Brand.ground;
  static Color ground(BuildContext c) => isDark(c) ? Brand.darkGround : Brand.ground;

  static Color chatGround(BuildContext c) => isDark(c) ? Brand.darkChatGround : Brand.chatGround;
  static Color bubbleIn(BuildContext c) => isDark(c) ? Brand.darkBubbleIn : Brand.bubbleIn;
  static Color bubbleOut(BuildContext c) => isDark(c) ? Brand.darkBubbleOut : Brand.bubbleOut;

  /// A tint of an accent for chip and pill backgrounds — stronger in the dark,
  /// where a 6% wash simply vanishes.
  static Color wash(BuildContext c, Color accent) => accent.withValues(alpha: isDark(c) ? 0.20 : 0.10);
}

/// The floating bottom bar's measurements, in one place.
///
/// A scrolling screen has to leave room for a bar it does not own, and the two
/// numbers drifting apart is how the last row ends up hidden under it. Anything
/// that scrolls behind the nav pads by [clearance] rather than by a guess.
class NavBar {
  const NavBar._();

  /// The pill itself.
  static const height = 64.0;

  /// The round create button, and how far it rides above the pill's top edge.
  static const fabSize = 56.0;
  static const fabLift = 26.0;

  /// The pill's corner radius: a stadium, the roundest a bar this tall can be.
  static const radius = height / 2;

  /// Inset from the screen on the left, right and bottom — not from the safe
  /// area, which held the bar a whole home indicator up in the chin.
  ///
  /// The three are equal on purpose. One rounded rectangle only looks concentric
  /// inside another when the gap between them equals the difference in their
  /// radii, and it has to be the same gap on every side or the corners visibly
  /// converge on one edge. An iPhone's display corner is around 55, the bar's is
  /// [radius], so the gap that nests them is the difference. Too small a gutter
  /// and the bar's corners chase the device's; too large and it floats free of
  /// the curve entirely.
  static const gutter = 55 - radius;

  /// What a scrolling screen must keep clear at the bottom, measured from the
  /// screen edge. The bar now covers the home indicator itself, so this is the
  /// whole story — do not add the view padding on top of it.
  static const clearance = gutter + height + fabLift + 12;
}

ThemeData buildTheme({required Brightness brightness}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.blue,
    brightness: brightness,
    primary: dark ? Brand.darkBlue : Brand.blue,
    surface: dark ? Brand.darkSurface : Brand.surface,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final onGround = dark ? Brand.darkInk : Brand.ink;
  final muted = dark ? Brand.darkInkSoft : Brand.inkFaint;

  return base.copyWith(
    scaffoldBackgroundColor: dark ? Brand.darkGround : Brand.ground,
    // One transition for the whole app, on both platforms, so a pushed screen
    // always arrives the same way. iOS keeps its edge-swipe back gesture; Android
    // stops using the old bottom-up slide, which reads as slow next to it.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: _FadeThroughTransitions(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
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
    textTheme: base.textTheme
        .apply(bodyColor: onGround, displayColor: onGround)
        .copyWith(
          titleLarge: TextStyle(
            color: onGround,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          titleMedium: TextStyle(color: onGround, fontSize: 16, fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(color: onGround, fontSize: 15, height: 1.4),
          bodySmall: TextStyle(color: muted, fontSize: 13, height: 1.35),
          labelSmall: TextStyle(
            color: muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
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
        borderSide: BorderSide(color: dark ? Brand.darkBlue : Brand.blue, width: 1.6),
      ),
      labelStyle: TextStyle(color: muted, fontSize: 14),
      hintStyle: TextStyle(color: muted, fontSize: 15),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? Brand.darkSurface : Brand.surface,
      indicatorColor: dark ? Brand.darkBlueWash : Brand.blueWash,
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

/// A push that fades forward and lifts slightly, rather than sliding a whole
/// screen across. Short on purpose: 220ms is about the point where a transition
/// stops feeling like polish and starts feeling like waiting.
class _FadeThroughTransitions extends PageTransitionsBuilder {
  const _FadeThroughTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.035), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
