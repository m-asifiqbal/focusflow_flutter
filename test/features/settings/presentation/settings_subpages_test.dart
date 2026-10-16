/// Settings sub-pages — General, Home layout, Gestures, Sounds & haptics:
/// render (light + dark captures), write the live settings, no overflow
/// at 360 pt / text scale 1.3.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';

void main() {
  late TestHarness h;

  Future<void> setUp(WidgetTester tester) async {
    await loadAppFonts();
    h = (await tester.runAsync(
      () => TestHarness.create(now: DateTime(2026, 6, 12, 9, 41)),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
  }

  AppSettings settings() => h.read(settingsProvider);

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester);
  }

  const pages = {
    'general': AppRoutes.settingsGeneral,
    'home_layout': AppRoutes.settingsHomeLayout,
    'gestures': AppRoutes.settingsGestures,
    'sounds_haptics': AppRoutes.settingsSoundsHaptics,
  };

  for (final MapEntry(key: name, value: route) in pages.entries) {
    testWidgets('$name renders light, dark and small', (tester) async {
      await setUp(tester);
      await pumpApp(tester, h, route);
      expect(tester.takeException(), isNull);
      await captureScreen(tester, 'settings_$name');
      await pumpApp(tester, h, route, dark: true);
      expect(tester.takeException(), isNull);
      await captureScreen(tester, 'settings_${name}_dark');
      await pumpApp(
        tester,
        h,
        route,
        size: const Size(360, 800),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('general: date format and start screen persist', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settingsGeneral);
    expect(find.text('Jun 12, 2026'), findsOneWidget);
    await tap(tester, find.text('Date format'));
    await tap(tester, find.text('2026-06-12'));
    expect(settings().dateFormat, 'yyyy-MM-dd');
    await tap(tester, find.text('Start screen'));
    await tap(tester, find.text('Insights').last);
    expect(settings().startScreen, StartScreen.insights);
  });

  testWidgets('general: date format sheet is honest about "coming soon"', (
    tester,
  ) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settingsGeneral);
    await tap(tester, find.text('Date format'));
    expect(find.textContaining('coming update'), findsOneWidget);
  });

  testWidgets('general: reset settings asks, then restores preferences only', (
    tester,
  ) async {
    await setUp(tester);
    await tester.runAsync(
      () => h.updateSettings(
        (s) => s.copyWith(
          themeMode: ThemeMode.dark,
          startScreen: StartScreen.library,
          clipboardClearSeconds: 0,
          vaultAutoLockMinutes: 30,
          autoBackupDrive: false,
        ),
      ),
    );
    await pumpApp(tester, h, AppRoutes.settingsGeneral);

    // Cancel keeps everything.
    await tap(tester, find.text('Reset settings'));
    expect(find.text('Reset settings?'), findsOneWidget);
    await tap(tester, find.text('Cancel'));
    expect(settings().themeMode, ThemeMode.dark);

    await tap(tester, find.text('Reset settings'));
    await tap(tester, find.text('Reset').last);
    expect(settings().themeMode, ThemeMode.system);
    expect(settings().startScreen, StartScreen.home);
    expect(settings().onboardingSeen, isTrue);
    expect(settings().clipboardClearSeconds, 0);
    expect(settings().vaultAutoLockMinutes, 30);
    expect(settings().autoBackupDrive, isFalse);
    expect(find.text('Settings reset'), findsOneWidget);
  });

  testWidgets('home layout: hide, move and reset sections', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settingsHomeLayout);
    await tap(tester, find.text('Recent notes'));
    expect(settings().hiddenHomeSections, {HomeSection.notes});
    expect(settings().visibleHomeSections, isNot(contains(HomeSection.notes)));

    // Accessibility path: "Move … up".
    final semantics = tester.ensureSemantics();
    final node = tester.getSemantics(find.text('Habit tracker'));
    final action = node.getSemanticsData().customSemanticsActionIds!.first;
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(
        type: SemanticsAction.customAction,
        viewId: tester.view.viewId,
        nodeId: node.id,
        arguments: action,
      ),
    );
    await settle(tester);
    expect(settings().homeSections.last, HomeSection.notes);
    semantics.dispose();

    await tap(tester, find.text('Reset'));
    expect(settings().homeSections, HomeSection.values);
    expect(settings().hiddenHomeSections, isEmpty);

    await tap(tester, find.text('Daily focus goal'));
    await tap(tester, find.text('10 tasks'));
    expect(settings().dailyFocusGoal, 10);
  });

  testWidgets('gestures: pickers write swipe actions; demo is safe', (
    tester,
  ) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settingsGestures);
    expect(find.text('Archive + Delete'), findsOneWidget);
    await tap(tester, find.text('Swipe right'));
    await tap(tester, find.text('Pin').last);
    expect(settings().swipeRight, SwipeAction.pin);
    await tap(tester, find.text('Swipe left'));
    await tap(tester, find.text('Nothing').last);
    expect(settings().swipeLeft, SwipeAction.none);
    await tester.fling(
      find.text('Review weekly plan'),
      const Offset(400, 0),
      1200,
    );
    await settle(tester);
    expect(find.text('Pin — just a preview'), findsOneWidget);
  });

  testWidgets('sounds & haptics: switches and reminder sound', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settingsSoundsHaptics);
    await tap(tester, find.text('In-app sounds'));
    expect(settings().soundsEnabled, isFalse);
    await tap(tester, find.text('Haptic feedback'));
    expect(settings().hapticsEnabled, isFalse);
    await tap(tester, find.text('Reminder sound'));
    await tap(tester, find.text('Bell'));
    expect(settings().remindersDefaultSound, 'bell');
  });
}
