/// Screen 01 — Onboarding: page 1 matches the mockup (light + dark);
/// Get Started advances and Continue (last page) goes to Sign in; Skip and
/// Restore leave too; every exit persists onboardingSeen; no overflow at
/// 360 pt / text scale 1.3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../helpers/screen_harness.dart';
import '../../helpers/test_container.dart';

void main() {
  late TestHarness h;

  Future<void> open(
    WidgetTester tester, {
    bool dark = false,
    Size size = kMockupSize,
    double textScale = 1,
  }) async {
    await loadAppFonts();
    h = (await tester.runAsync(
      () => TestHarness.create(now: DateTime(2026, 6, 12, 9, 41)),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    // iPhone safe areas of the mockup (47 pt status bar, 34 pt indicator).
    tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    tester.view.viewPadding = const FakeViewPadding(
      top: 47 * 3,
      bottom: 34 * 3,
    );
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await pumpApp(
      tester,
      h,
      AppRoutes.onboarding,
      onboardingSeen: false,
      dark: dark,
      size: size,
      textScale: textScale,
    );
  }

  bool seen() => h.read(settingsProvider).onboardingSeen;
  String location() =>
      h.read(routerProvider).routerDelegate.currentConfiguration.uri.toString();

  testWidgets('mockup state (light)', (tester) async {
    await open(tester);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    for (final t in [
      'Skip',
      'Notes',
      'Tasks',
      'Habits',
      'Reminders',
      'Vault',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Already have a backup? Restore'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '01_onboarding');
  });

  testWidgets('mockup state (dark)', (tester) async {
    await open(tester, dark: true);
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '01_onboarding_dark');
  });

  testWidgets('Get Started advances; Continue goes to sign-in', (tester) async {
    await open(tester);
    await tester.tap(find.text('Get Started'));
    await settle(tester);
    expect(find.text('Biometric'), findsOneWidget);
    await captureScreen(tester, '01_onboarding_page2');
    await tester.tap(find.text('Get Started'));
    await settle(tester);
    expect(find.text('Continue'), findsOneWidget);
    await captureScreen(tester, '01_onboarding_page3');
    expect(seen(), isFalse);
    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(seen(), isTrue);
    expect(location(), AppRoutes.signIn);
  });

  testWidgets('Skip marks seen and opens sign-in', (tester) async {
    await open(tester);
    await tester.tap(find.text('Skip'));
    await settle(tester);
    expect(seen(), isTrue);
    expect(location(), AppRoutes.signIn);
  });

  testWidgets('Restore opens sign-in with the restore intent', (tester) async {
    await open(tester);
    await tester.tap(find.text('Already have a backup? Restore'));
    await settle(tester);
    expect(seen(), isTrue);
    expect(location(), AppRoutes.signInRestore);
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    await open(tester, size: const Size(360, 740), textScale: 1.3);
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '01_onboarding_small');
  });

  testWidgets('reduce motion stops the floating chips', (tester) async {
    await loadAppFonts();
    h = (await tester.runAsync(
      () => TestHarness.create(now: DateTime(2026, 6, 12, 9, 41)),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await h.updateSettings((s) => s.copyWith(reduceMotion: true));
    await pumpApp(tester, h, AppRoutes.onboarding, onboardingSeen: false);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
