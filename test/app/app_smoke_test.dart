/// Smoke test: the whole app boots over a real encrypted DB, the launch
/// redirect works, and the screenshot harness renders real fonts.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/widgets/dev/widget_gallery_screen.dart';

import '../helpers/screen_harness.dart';
import '../helpers/test_container.dart';

void main() {
  final now = DateTime(2026, 6, 13, 9, 41);

  testWidgets('first launch redirects to onboarding', (tester) async {
    final h = (await tester.runAsync(() => TestHarness.create(now: now)))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await pumpApp(tester, h, AppRoutes.home, onboardingSeen: false);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('home tab renders inside the shell', (tester) async {
    await loadAppFonts();
    final h = (await tester.runAsync(() => TestHarness.create(now: now)))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await pumpApp(tester, h, AppRoutes.home);
    expect(find.text('Home'), findsWidgets);
    final file = await captureScreen(tester, 'smoke_home');
    expect(file.lengthSync(), greaterThan(10000));
  });

  testWidgets('gallery renders with real fonts', (tester) async {
    await loadAppFonts();
    final h = (await tester.runAsync(() => TestHarness.create(now: now)))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await pumpScreen(tester, h, const WidgetGalleryScreen());
    await captureScreen(tester, 'smoke_gallery');
  });
}
