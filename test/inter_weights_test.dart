// Weight must change the FACE, not just the request.
//
// This exists because of a regression that looked correct in code and wrong on
// screen. The google_fonts package registers every weight as its OWN family —
// Inter_regular, Inter_600, Inter_700 — so a role built by GoogleFonts.inter…
// carries a family holding a single face. `style.copyWith(fontWeight: w700)`
// then asks that family for a weight it does not contain and the text draws
// Regular while the code says bold. Measured at the time: bodyMedium.copyWith(
// w700) came back as family Inter_regular. There are 107 fontWeight: call sites
// in lib/, and every one of them was affected.
//
// Inter is now declared in pubspec.yaml as ONE family holding four weights, so a
// weight resolves the way Flutter's font matching expects. These tests fail if
// anyone reintroduces a per-variant family.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makutano_connect/core/theme.dart';

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    final label = brightness == Brightness.light ? 'light' : 'dark';
    final theme = buildTheme(brightness: brightness);

    test('$label: every text role is on the one Inter family', () {
      final t = theme.textTheme;
      final roles = <String, TextStyle?>{
        'displaySmall': t.displaySmall,
        'headlineMedium': t.headlineMedium,
        'headlineSmall': t.headlineSmall,
        'titleLarge': t.titleLarge,
        'titleMedium': t.titleMedium,
        'titleSmall': t.titleSmall,
        'bodyLarge': t.bodyLarge,
        'bodyMedium': t.bodyMedium,
        'bodySmall': t.bodySmall,
        'labelLarge': t.labelLarge,
        'labelMedium': t.labelMedium,
        'labelSmall': t.labelSmall,
      };
      for (final entry in roles.entries) {
        expect(entry.value?.fontFamily, 'Inter', reason: '${entry.key} is not on the Inter family');
      }
    });

    test('$label: asking for a weight afterwards keeps the family', () {
      // The exact operation that was broken.
      final bolded = theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w700);
      expect(bolded.fontFamily, 'Inter');
      expect(bolded.fontWeight, FontWeight.w700);
    });

    test('$label: the styles that live outside the TextTheme name the family too', () {
      // These inherit nothing from textTheme, so each has to say Inter itself.
      expect(theme.appBarTheme.titleTextStyle?.fontFamily, 'Inter');
      expect(theme.inputDecorationTheme.labelStyle?.fontFamily, 'Inter');
      expect(theme.inputDecorationTheme.hintStyle?.fontFamily, 'Inter');
      expect(theme.snackBarTheme.contentTextStyle?.fontFamily, 'Inter');
      expect(
        theme.filledButtonTheme.style?.textStyle?.resolve({})?.fontFamily,
        'Inter',
      );
      expect(
        theme.outlinedButtonTheme.style?.textStyle?.resolve({})?.fontFamily,
        'Inter',
      );
      expect(
        theme.navigationBarTheme.labelTextStyle?.resolve({})?.fontFamily,
        'Inter',
      );
    });
  }

  test('numbers that change do not move the text beside them', () {
    final theme = buildTheme(brightness: Brightness.light);
    // Proportional digits give a 1 less width than a 4, so a live counter
    // shifts its neighbours as it ticks.
    expect(theme.textTheme.displaySmall?.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(theme.textTheme.headlineMedium?.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(
      theme.textTheme.bodyMedium!.tnum.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  test('the scale still ranks: each step is heavier or larger than the next', () {
    final t = buildTheme(brightness: Brightness.light).textTheme;
    expect(t.displaySmall!.fontSize!, greaterThan(t.headlineMedium!.fontSize!));
    expect(t.headlineMedium!.fontSize!, greaterThan(t.titleLarge!.fontSize!));
    expect(t.titleLarge!.fontSize!, greaterThan(t.titleMedium!.fontSize!));
    expect(t.titleMedium!.fontSize!, greaterThan(t.titleSmall!.fontSize!));
    expect(t.bodyMedium!.fontSize!, greaterThan(t.bodySmall!.fontSize!));
    expect(t.labelMedium!.fontSize!, greaterThan(t.labelSmall!.fontSize!));
    // Weight has to carry hierarchy too, not only size.
    expect(t.titleMedium!.fontWeight, FontWeight.w600);
    expect(t.bodyMedium!.fontWeight ?? FontWeight.w400, FontWeight.w400);
  });
}
