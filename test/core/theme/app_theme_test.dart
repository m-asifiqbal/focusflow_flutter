/// AppTheme: themes are cached per (accent, brightness, system font) so
/// the same inputs give the identical ThemeData; the extensions have value
/// equality; "Use system font" drops the bundled families.
/// AppTextScaler: the app's text size composes with the system scaler.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_text_scaler.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/app_typography.dart';

/// Stand-in for Android 14's non-linear scaling: large text grows less.
class _NonLinear extends TextScaler {
  const _NonLinear();

  @override
  double scale(double fontSize) =>
      fontSize < 20 ? fontSize * 2 : 40 + (fontSize - 20) * 1.2;

  @override
  double get textScaleFactor => 2;
}

void main() {
  group('AppTheme cache', () {
    test('same inputs → identical instance', () {
      for (final accent in AccentColor.values) {
        expect(identical(AppTheme.light(accent), AppTheme.light(accent)), isTrue);
        expect(identical(AppTheme.dark(accent), AppTheme.dark(accent)), isTrue);
        expect(
          identical(
            AppTheme.light(accent, systemFont: true),
            AppTheme.light(accent, systemFont: true),
          ),
          isTrue,
        );
        expect(
          identical(AppTheme.vault(accent), AppTheme.vault(accent)),
          isTrue,
        );
      }
    });

    test('different inputs → different themes', () {
      final base = AppTheme.light(AccentColor.emerald);
      expect(identical(base, AppTheme.light(AccentColor.blue)), isFalse);
      expect(identical(base, AppTheme.dark(AccentColor.emerald)), isFalse);
      expect(
        identical(base, AppTheme.light(AccentColor.emerald, systemFont: true)),
        isFalse,
      );
      expect(identical(AppTheme.vault(AccentColor.emerald),
          AppTheme.dark(AccentColor.emerald)), isFalse);
      expect(
        AppTheme.light(AccentColor.blue).colorScheme.primary,
        AccentColor.blue.primary,
      );
    });

    test('page transitions stay registered', () {
      final t = AppTheme.light(AccentColor.emerald);
      expect(t.pageTransitionsTheme.builders[TargetPlatform.iOS], isNotNull);
      expect(
        t.pageTransitionsTheme.builders[TargetPlatform.android],
        isNotNull,
      );
    });
  });

  group('extension equality', () {
    test('FFColors / FFTextStyles compare by value', () {
      final a = FFColors.light(AccentColor.indigo);
      final b = FFColors.light(AccentColor.indigo);
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == FFColors.light(AccentColor.pink), isFalse);
      expect(a == FFColors.dark(AccentColor.indigo), isFalse);

      expect(FFTextStyles.from(a), FFTextStyles.from(b));
      expect(FFTextStyles.from(a).hashCode, FFTextStyles.from(b).hashCode);
      expect(
        FFTextStyles.from(a) == FFTextStyles.from(a, systemFont: true),
        isFalse,
      );
    });
  });

  group('Use system font', () {
    test('bundled families by default', () {
      final t = AppTheme.light(AccentColor.emerald);
      final text = t.extension<FFTextStyles>()!;
      expect(text.body.fontFamily, AppFonts.body);
      expect(text.largeTitle.fontFamily, AppFonts.heading);
      expect(t.textTheme.bodyLarge!.fontFamily, AppFonts.body);
    });

    test('system font drops them (platform default), mono unchanged', () {
      for (final t in [
        AppTheme.light(AccentColor.emerald, systemFont: true),
        AppTheme.dark(AccentColor.emerald, systemFont: true),
        AppTheme.vault(AccentColor.emerald, systemFont: true),
      ]) {
        final text = t.extension<FFTextStyles>()!;
        expect(text.body.fontFamily, isNull);
        expect(text.largeTitle.fontFamily, isNull);
        expect(text.mono.fontFamily, 'Menlo');
        expect(t.textTheme.bodyLarge!.fontFamily, isNot(AppFonts.body));
        expect(t.textTheme.headlineLarge!.fontFamily, isNot(AppFonts.heading));
      }
    });
  });

  group('AppTextScaler', () {
    test('factor 1 returns the system scaler untouched', () {
      const system = _NonLinear();
      expect(identical(AppTextScaler.compose(system, 1), system), isTrue);
    });

    test('multiplies the system scaler, keeping its non-linear curve', () {
      final s = AppTextScaler.compose(const TextScaler.linear(1.2), 0.9);
      expect(s.scale(10), closeTo(10 * 1.2 * 0.9, 1e-9));

      final nl = AppTextScaler.compose(const _NonLinear(), 0.85);
      expect(nl.scale(10), closeTo(20 * 0.85, 1e-9));
      expect(nl.scale(30), closeTo(52 * 0.85, 1e-9));
      // Large text still grows proportionally less than small text.
      expect(nl.scale(30) / 30, lessThan(nl.scale(10) / 10));
    });

    test('app enlargement alone stops at 2×, never below the system', () {
      final mild = AppTextScaler.compose(const TextScaler.linear(1.0), 1.3);
      expect(mild.scale(10), closeTo(13, 1e-9));

      final big = AppTextScaler.compose(const TextScaler.linear(1.8), 1.3);
      expect(big.scale(10), closeTo(20, 1e-9), reason: '1.8 × 1.3 → 2×');

      // The OS already asks for 3×: not capped below it.
      final huge = AppTextScaler.compose(const TextScaler.linear(3), 1.3);
      expect(huge.scale(10), closeTo(30, 1e-9));
      final shrink = AppTextScaler.compose(const TextScaler.linear(3), 0.85);
      expect(shrink.scale(10), closeTo(25.5, 1e-9));
    });

    test('value equality', () {
      expect(
        AppTextScaler.compose(const TextScaler.linear(1.1), 1.2),
        AppTextScaler.compose(const TextScaler.linear(1.1), 1.2),
      );
      expect(
        AppTextScaler.compose(const TextScaler.linear(1.1), 1.2) ==
            AppTextScaler.compose(const TextScaler.linear(1.1), 1.3),
        isFalse,
      );
    });
  });
}
