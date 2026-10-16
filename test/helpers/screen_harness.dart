/// Screen-level widget test helpers.
///
/// - [loadAppFonts]: registers the bundled fonts (Lexend Deca, Nunito Sans,
///   Font Awesome) so text and icons render for real instead of as boxes.
/// - [pumpApp]: the whole app (router, theme, startup host) at a location,
///   over a [TestHarness] graph — use for screen tests.
/// - [pumpScreen]: a single widget inside the themed app chrome.
/// - [captureScreen]: writes the current frame as a PNG (1170×2532 for the
///   default 390×844 @3x surface — the same size as `design/NN_*.png`) to
///   `build/screens/<name>.png`, for side-by-side comparison with mockups.
///
/// ```dart
/// testWidgets('notes list', (tester) async {
///   await loadAppFonts();
///   final h = await tester.runAsync(() => TestHarness.create(now: now));
///   await pumpApp(tester, h!, AppRoutes.notes);
///   await captureScreen(tester, '07_notes_list');
/// });
/// ```
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/app.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import 'test_container.dart';

/// The mockups' canvas: iPhone 390×844 pt @3x.
const Size kMockupSize = Size(390, 844);

bool _fontsLoaded = false;

/// Loads every bundled font family once per test isolate.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  const families = {
    'LexendDeca': [
      'assets/fonts/LexendDeca-Regular.ttf',
      'assets/fonts/LexendDeca-Medium.ttf',
      'assets/fonts/LexendDeca-SemiBold.ttf',
      'assets/fonts/LexendDeca-Bold.ttf',
    ],
    'NunitoSans': [
      'assets/fonts/NunitoSans-Regular.ttf',
      'assets/fonts/NunitoSans-Italic.ttf',
      'assets/fonts/NunitoSans-Medium.ttf',
      'assets/fonts/NunitoSans-SemiBold.ttf',
      'assets/fonts/NunitoSans-Bold.ttf',
      'assets/fonts/NunitoSans-ExtraBold.ttf',
    ],
    'FontAwesomeSolid': ['assets/fonts/fontawesome/fa-solid-900.ttf'],
    'FontAwesomeRegular': ['assets/fonts/fontawesome/fa-regular-400.ttf'],
    'FontAwesomeBrands': ['assets/fonts/fontawesome/fa-brands-400.ttf'],
  };
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    for (final path in e.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
  _fontsLoaded = true;
}

void _setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Pumps the full app at [location] over [h]'s provider graph. Onboarding
/// is marked as seen unless [onboardingSeen] is false.
Future<void> pumpApp(
  WidgetTester tester,
  TestHarness h,
  String location, {
  Size size = kMockupSize,
  bool dark = false,
  double textScale = 1,
  bool onboardingSeen = true,
}) async {
  _setSurface(tester, size);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.platformDispatcher.platformBrightnessTestValue = dark
      ? Brightness.dark
      : Brightness.light;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  if (onboardingSeen) {
    await h.updateSettings((s) => s.copyWith(onboardingSeen: true));
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: h.container,
      child: const FocusFlowApp(),
    ),
  );
  h.read(routerProvider).go(location);
  await settle(tester);
}

/// Pumps [child] as the home of a themed MaterialApp over [h]'s graph.
Future<void> pumpScreen(
  WidgetTester tester,
  TestHarness h,
  Widget child, {
  Size size = kMockupSize,
  bool dark = false,
  double textScale = 1,
}) async {
  _setSurface(tester, size);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: h.container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(AccentColor.emerald),
        darkTheme: AppTheme.dark(AccentColor.emerald),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: app!,
        ),
        home: child,
      ),
    ),
  );
  await settle(tester);
}

/// Lets database streams emit (real async) and animations finish.
/// Drift queries run outside the fake-async zone, so alternate real waits
/// with pumps instead of a plain `pumpAndSettle`.
Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
  // Pages now leave with real transitions, so the last screen's providers
  // are disposed late — one frame per dependency level — and Drift closes
  // every dropped stream with a zero-length timer. Keep pumping tiny steps
  // while frames are still being requested, then one more to run the timers
  // the last frame created; otherwise the test ends with timers pending.
  var extra = 0;
  while (tester.binding.hasScheduledFrame && extra++ < 24) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  await tester.pump(const Duration(milliseconds: 1));
}

/// Writes the current frame to `build/screens/<name>.png`. Returns the file.
Future<File> captureScreen(WidgetTester tester, String name) async {
  await tester.pump();
  final view = tester.binding.renderViews.first;
  // ignore: invalid_use_of_protected_member
  final layer = view.debugLayer! as OffsetLayer;
  final logical = view.size;
  late File file;
  await tester.runAsync(() async {
    // The root layer already scales logical → physical pixels.
    final image = await layer.toImage(
      Offset.zero & (logical * tester.view.devicePixelRatio),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    file = File('build/screens/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
  return file;
}

extension TestHarnessSettings on TestHarness {
  /// Updates persisted settings through the real SettingsController.
  Future<void> updateSettings(AppSettings Function(AppSettings) change) =>
      container.read(settingsProvider.notifier).update(change);
}
