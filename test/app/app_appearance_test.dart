/// App-wide appearance wiring (app.dart): text size composes with the
/// system scaler, reduce motion is OS || app, the haptics switch reaches
/// the design system, and only appearance settings rebuild the theme —
/// writing an unrelated setting keeps the identical ThemeData.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/app.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_typography.dart';
import 'package:focusflow/core/widgets/ff_haptics.dart';

import '../helpers/screen_harness.dart';
import '../helpers/test_container.dart';

void main() {
  group('AppAppearanceScope', () {
    Future<BuildContext> pumpScope(
      WidgetTester tester, {
      required TextScaler system,
      required bool osReduceMotion,
      required double textScale,
      required bool reduceMotion,
      bool haptics = true,
    }) async {
      late BuildContext inner;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            textScaler: system,
            disableAnimations: osReduceMotion,
          ),
          child: AppAppearanceScope(
            textScale: textScale,
            reduceMotion: reduceMotion,
            hapticsEnabled: haptics,
            child: Builder(
              builder: (context) {
                inner = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return inner;
    }

    testWidgets('text size multiplies the system scale (no 2.0 clamp below '
        'the system)', (tester) async {
      var ctx = await pumpScope(
        tester,
        system: const TextScaler.linear(1.2),
        osReduceMotion: false,
        textScale: 1.1,
        reduceMotion: false,
      );
      expect(MediaQuery.textScalerOf(ctx).scale(10), closeTo(13.2, 1e-9));

      ctx = await pumpScope(
        tester,
        system: const TextScaler.linear(2.5),
        osReduceMotion: false,
        textScale: 0.9,
        reduceMotion: false,
      );
      // Old code clamped to 2.0 → 20.
      expect(MediaQuery.textScalerOf(ctx).scale(10), closeTo(22.5, 1e-9));

      ctx = await pumpScope(
        tester,
        system: const TextScaler.linear(1.4),
        osReduceMotion: false,
        textScale: 1,
        reduceMotion: false,
      );
      expect(MediaQuery.textScalerOf(ctx), const TextScaler.linear(1.4));
    });

    testWidgets('reduce motion is on when the OS or the app asks', (
      tester,
    ) async {
      for (final (os, app, expected) in [
        (false, false, false),
        (true, false, true),
        (false, true, true),
        (true, true, true),
      ]) {
        final ctx = await pumpScope(
          tester,
          system: TextScaler.noScaling,
          osReduceMotion: os,
          textScale: 1,
          reduceMotion: app,
        );
        expect(
          MediaQuery.disableAnimationsOf(ctx),
          expected,
          reason: 'os=$os app=$app',
        );
      }
    });

    testWidgets('provides the haptics switch', (tester) async {
      var ctx = await pumpScope(
        tester,
        system: TextScaler.noScaling,
        osReduceMotion: false,
        textScale: 1,
        reduceMotion: false,
        haptics: false,
      );
      expect(FFHaptics.enabledOf(ctx), isFalse);
      ctx = await pumpScope(
        tester,
        system: TextScaler.noScaling,
        osReduceMotion: false,
        textScale: 1,
        reduceMotion: false,
      );
      expect(FFHaptics.enabledOf(ctx), isTrue);
    });
  });

  group('FocusFlowApp', () {
    late TestHarness h;

    Future<void> setUp(WidgetTester tester) async {
      h = (await tester.runAsync(
        () => TestHarness.create(now: DateTime(2026, 6, 12, 9, 41)),
      ))!;
      addTearDown(() => tester.runAsync(h.dispose));
      await pumpApp(tester, h, AppRoutes.settingsAppearance);
    }

    MaterialApp app(WidgetTester tester) =>
        tester.widget<MaterialApp>(find.byType(MaterialApp));

    BuildContext screen(WidgetTester tester) =>
        tester.element(find.text('Appearance').first);

    testWidgets('an unrelated setting keeps the identical theme', (
      tester,
    ) async {
      await setUp(tester);
      final before = app(tester);
      final themeBefore = Theme.of(screen(tester));

      await tester.runAsync(
        () => h.updateSettings(
          (s) => s.copyWith(
            lastSyncAt: () => DateTime(2026, 6, 12, 9, 40),
            notifySync: true,
            weekStartsOn: DateTime.sunday,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(identical(app(tester), before), isTrue, reason: 'no rebuild');
      expect(identical(app(tester).theme, before.theme), isTrue);
      expect(identical(Theme.of(screen(tester)), themeBefore), isTrue);
    });

    testWidgets('appearance settings apply live', (tester) async {
      await setUp(tester);
      final before = app(tester).theme;

      await tester.runAsync(
        () => h.updateSettings((s) => s.copyWith(accent: AccentColor.blue)),
      );
      await settle(tester);
      expect(identical(app(tester).theme, before), isFalse);
      expect(
        Theme.of(screen(tester)).colorScheme.primary,
        AccentColor.blue.primary,
      );

      await tester.runAsync(
        () => h.updateSettings(
          (s) => s.copyWith(
            useSystemFont: true,
            textScale: 1.3,
            reduceMotion: true,
            hapticsEnabled: false,
          ),
        ),
      );
      await settle(tester);
      final ctx = screen(tester);
      expect(Theme.of(ctx).extension<FFTextStyles>()!.body.fontFamily, isNull);
      expect(MediaQuery.textScalerOf(ctx).scale(10), closeTo(13, 1e-9));
      expect(MediaQuery.disableAnimationsOf(ctx), isTrue);
      expect(FFHaptics.enabledOf(ctx), isFalse);
    });
  });
}
