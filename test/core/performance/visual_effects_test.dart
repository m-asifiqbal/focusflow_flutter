/// Reduced visual effects for weak phones: the device rule, how the setting
/// and the device combine, and that the three costly widgets (tab-bar blur,
/// card → page transition, shimmer) really draw their cheap form — and only
/// then.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/performance/device_performance.dart';
import 'package:focusflow/core/router/open_origin.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/widgets/ff_bottom_nav.dart';
import 'package:focusflow/core/widgets/ff_effects.dart';
import 'package:focusflow/core/widgets/ff_open_origin.dart';
import 'package:focusflow/core/widgets/ff_skeleton.dart';
import 'package:focusflow/shared/providers/performance_provider.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../widgets/ff_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DevicePerformance.classify', () {
    bool low({bool lowRam = false, int ramMb = 6000, int sdk = 34}) =>
        DevicePerformance.classify(
          isLowRamDevice: lowRam,
          physicalRamMb: ramMb,
          sdkInt: sdk,
        );

    test('a capable phone keeps full effects', () {
      expect(low(), isFalse);
      expect(low(ramMb: 8192), isFalse);
      expect(low(ramMb: 4096), isFalse);
    });

    test('the low-RAM flag, ≤ 3 GB or an old Android reduce them', () {
      expect(low(lowRam: true), isTrue);
      expect(low(ramMb: 2048), isTrue);
      expect(low(ramMb: DevicePerformance.lowEndMemoryMb), isTrue);
      expect(low(ramMb: DevicePerformance.lowEndMemoryMb + 1), isFalse);
      expect(low(sdk: DevicePerformance.minCapableSdk - 1), isTrue);
      expect(low(sdk: DevicePerformance.minCapableSdk), isFalse);
    });

    test('an unknown memory size (0) is not taken for a weak phone', () {
      expect(low(ramMb: 0), isFalse);
    });

    test('reading the device never throws (no native side here)', () async {
      final d = await DevicePerformance.detect();
      expect(d.lowEnd, isFalse, reason: 'unknown counts as capable');
    });
  });

  group('reducedEffectsProvider', () {
    ProviderContainer make(PerformanceMode mode, {required bool lowEnd}) {
      final c = ProviderContainer(
        overrides: [
          devicePerformanceProvider.overrideWithValue(
            DevicePerformance(lowEnd: lowEnd),
          ),
          settingsProvider.overrideWith(
            () => _FixedSettings(AppSettings(performanceMode: mode)),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('Automatic follows the device', () {
      expect(
        make(PerformanceMode.auto, lowEnd: true).read(reducedEffectsProvider),
        isTrue,
      );
      expect(
        make(PerformanceMode.auto, lowEnd: false).read(reducedEffectsProvider),
        isFalse,
      );
    });

    test('Full and Reduced force it, whatever the device', () {
      for (final lowEnd in [true, false]) {
        expect(
          make(
            PerformanceMode.full,
            lowEnd: lowEnd,
          ).read(reducedEffectsProvider),
          isFalse,
        );
        expect(
          make(
            PerformanceMode.reduced,
            lowEnd: lowEnd,
          ).read(reducedEffectsProvider),
          isTrue,
        );
      }
    });

    test('the setting is automatic by default and survives JSON', () {
      expect(const AppSettings().performanceMode, PerformanceMode.auto);
      for (final m in PerformanceMode.values) {
        final back = AppSettings.fromJson(
          const AppSettings().copyWith(performanceMode: m).toJson(),
        );
        expect(back.performanceMode, m);
      }
      expect(
        AppSettings.fromJson({'performanceMode': 'turbo'}).performanceMode,
        PerformanceMode.auto,
        reason: 'garbage falls back to the default',
      );
    });
  });

  group('FFEffects', () {
    testWidgets('is full unless an FFEffects above says otherwise', (
      tester,
    ) async {
      bool? seen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = FFEffects.reducedOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(seen, isFalse);

      await tester.pumpWidget(
        FFEffects(
          reduced: true,
          child: Builder(
            builder: (context) {
              seen = FFEffects.reducedOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, isTrue);
    });
  });

  group('tab bar', () {
    Future<void> pump(WidgetTester tester, {required bool reduced}) => pumpFF(
      tester,
      FFEffects(
        reduced: reduced,
        child: FFBottomNav(currentIndex: 0, onTap: (_) {}, onFab: () {}),
      ),
      textScale: 1,
      scroll: false,
    );

    testWidgets('blurs what is behind it by default', (tester) async {
      await pump(tester, reduced: false);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('draws a plain, more opaque glass when reduced', (
      tester,
    ) async {
      await pump(tester, reduced: true);
      expect(find.byType(BackdropFilter), findsNothing);
      // Still the whole bar: four tabs and the +.
      for (final label in ['Home', 'Library', 'Insights', 'Settings']) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      expect(find.bySemanticsLabel('Quick add'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final glass = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.gradient)
          .whereType<LinearGradient>()
          .firstWhere(
            (g) =>
                g.begin == Alignment.topCenter &&
                g.end == Alignment.bottomCenter,
          );
      for (final c in glass.colors) {
        expect(c.a, greaterThanOrEqualTo(0.94), reason: 'opaque: no blur');
      }
    });
  });

  group('card → page transition', () {
    Future<bool> tapRecordsOrigin(
      WidgetTester tester, {
      required bool reduced,
    }) async {
      await pumpFF(
        tester,
        FFEffects(
          reduced: reduced,
          child: const FFOpenOriginTracker(
            child: SizedBox(width: 200, height: 80, child: Text('card')),
          ),
        ),
        textScale: 1,
        scroll: false,
      );
      FFOpenOrigin.claim(MaterialPageRoute<void>(builder: (_) => Container()));
      await tester.tap(find.text('card'));
      await tester.pump();
      final route = MaterialPageRoute<void>(builder: (_) => Container());
      return FFOpenOrigin.claim(route) != null;
    }

    testWidgets('a tapped card is the page\'s origin by default', (
      tester,
    ) async {
      expect(await tapRecordsOrigin(tester, reduced: false), isTrue);
    });

    testWidgets('reduced: the page just slides in', (tester) async {
      expect(await tapRecordsOrigin(tester, reduced: true), isFalse);
    });
  });

  group('shimmer', () {
    Future<void> pump(WidgetTester tester, {required bool reduced}) => pumpFF(
      tester,
      FFEffects(
        reduced: reduced,
        child: const FFShimmer(child: FFSkeleton(width: 120, height: 14)),
      ),
      textScale: 1,
    );

    Finder sweep() => find.descendant(
      of: find.byType(FFShimmer),
      matching: find.byType(ShaderMask),
    );

    testWidgets('sweeps by default', (tester) async {
      await pump(tester, reduced: false);
      expect(sweep(), findsOneWidget);
      // Dispose the repeating controller before the test ends.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('is a still placeholder when reduced', (tester) async {
      await pump(tester, reduced: true);
      expect(sweep(), findsNothing);
      expect(find.byType(FFSkeleton), findsOneWidget);
      // Nothing keeps animating (a repeating shimmer would never settle).
      await tester.pumpAndSettle();
    });
  });
}

/// A [SettingsController] that starts from fixed settings (no preferences).
class _FixedSettings extends SettingsController {
  _FixedSettings(this._initial);

  final AppSettings _initial;

  @override
  AppSettings build() => _initial;
}
