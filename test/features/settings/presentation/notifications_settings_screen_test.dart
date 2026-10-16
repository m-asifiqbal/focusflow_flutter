/// Screen 31 — Settings › Notifications & Reminders: the mockup state
/// renders in light + dark; the master switch runs the permission flow
/// (system settings after a refusal) and shows the denied banner; digest,
/// module, quiet-hours and behaviour rows write the live settings; no
/// overflow at 360 pt / text scale 1.3.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../core/notifications/fake_gateway.dart';
import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';

/// The mockup PNG is 1170×3741 (390×1247 pt).
const _mockupTall = Size(390, 1247);

class _Gateway extends FakeGateway {
  int settingsOpened = 0;
  int requests = 0;

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Future<NotificationPermission> requestPermission({
    bool exactAlarms = true,
  }) async {
    requests++;
    return super.requestPermission(exactAlarms: exactAlarms);
  }
}

class _NoopEngine implements NotificationEngine {
  @override
  Future<void> start() async {}

  @override
  Future<void> onResume() async {}
}

void main() {
  late TestHarness h;
  late _Gateway gateway;

  Future<void> setUp(
    WidgetTester tester, {
    NotificationPermission permission = NotificationPermission.granted,
  }) async {
    await loadAppFonts();
    gateway = _Gateway()..state = permission;
    h = (await tester.runAsync(
      () => TestHarness.create(
        now: DateTime(2026, 6, 12, 9, 41),
        overrides: [
          notificationGatewayProvider.overrideWithValue(gateway),
          // The engine (and its wake timer) is covered by
          // test/core/notifications; here only the screen is under test.
          notificationEngineProvider.overrideWithValue(_NoopEngine()),
        ],
      ),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    // Mockup: weekly report on Sunday, quiet hours 10 PM – 7 AM.
    await tester.runAsync(
      () => h.updateSettings(
        (s) => s.copyWith(weeklyReport: true, quietHours: true),
      ),
    );
  }

  AppSettings settings() => h.read(settingsProvider);

  Future<void> open(WidgetTester tester, {Size size = _mockupTall}) =>
      pumpApp(tester, h, AppRoutes.settingsNotifications, size: size);

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.pump();
    await tester.tap(find.text(text).first);
    await settle(tester);
  }

  testWidgets('mockup state (light)', (tester) async {
    await setUp(tester);
    await open(tester);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('System permission granted'), findsOneWidget);
    for (final t in [
      '8:00 AM',
      '9:00 PM',
      'Sun',
      'Sound: Chime · Alarm-style for high priority',
      "At each habit's scheduled times",
      '10:00 PM',
      '7:00 AM',
      '10 min',
      'Title only',
      'Overdue count',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '31_settings_notifications');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/31_settings_notifications.png'),
    );
  });

  testWidgets('mockup state (dark)', (tester) async {
    await setUp(tester);
    await pumpApp(
      tester,
      h,
      AppRoutes.settingsNotifications,
      size: _mockupTall,
      dark: true,
    );
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '31_settings_notifications_dark');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/31_settings_notifications_dark.png'),
    );
  });

  testWidgets('denied: banner; switching on opens the system settings', (
    tester,
  ) async {
    await setUp(tester, permission: NotificationPermission.denied);
    await open(tester);
    expect(find.text('Blocked in system settings'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    await captureScreen(tester, '31_settings_notifications_denied');

    await tester.tap(find.text('Allow notifications'));
    await settle(tester);
    expect(gateway.settingsOpened, 1);
    expect(gateway.requests, 0);

    await tester.tap(find.text('Open settings'));
    await settle(tester);
    expect(gateway.settingsOpened, 2);
  });

  testWidgets('master switch off pauses; on asks when never asked', (
    tester,
  ) async {
    await setUp(tester, permission: NotificationPermission.notDetermined);
    await open(tester);
    expect(find.text('Tap to allow notifications'), findsOneWidget);
    await tester.tap(find.text('Allow notifications'));
    await settle(tester);
    expect(gateway.requests, 1);
    expect(find.text('System permission granted'), findsOneWidget);

    await tester.tap(find.text('Allow notifications'));
    await settle(tester);
    expect(settings().notificationsEnabled, isFalse);
    expect(find.text('All notifications are paused'), findsOneWidget);
  });

  testWidgets('digest sheet turns the morning briefing off and on', (
    tester,
  ) async {
    await setUp(tester);
    await open(tester);
    await tapText(tester, 'Morning briefing');
    await tapText(tester, 'Turn off morning briefing');
    expect(settings().morningBriefing, isFalse);
    expect(find.text('Off'), findsOneWidget);

    await tapText(tester, 'Morning briefing');
    expect(find.text('Turn off morning briefing'), findsNothing);
    await tapText(tester, 'Set 8:00 AM');
    expect(settings().morningBriefing, isTrue);
    expect(settings().morningBriefingMinutes, 8 * 60);
  });

  testWidgets('weekly report picks a day or Off', (tester) async {
    await setUp(tester);
    await open(tester);
    await tapText(tester, 'Weekly report');
    await tapText(tester, 'Friday');
    expect(settings().weeklyReportWeekday, DateTime.friday);
    expect(find.text('Fri'), findsOneWidget);
    await tapText(tester, 'Weekly report');
    await tapText(tester, 'Off');
    expect(settings().weeklyReport, isFalse);
  });

  testWidgets('module switches write their settings', (tester) async {
    await setUp(tester);
    await open(tester);
    await tapText(tester, 'Backup & sync status');
    expect(settings().notifySync, isTrue);
    await tapText(tester, 'Streak at risk');
    expect(settings().notifyStreakRisk, isFalse);
  });

  testWidgets('quiet hours pills: turn off, then on again from the row', (
    tester,
  ) async {
    await setUp(tester);
    await open(tester);
    await tapText(tester, '10:00 PM');
    expect(find.text('Quiet hours start'), findsOneWidget);
    await tapText(tester, 'Turn off quiet hours');
    expect(settings().quietHours, isFalse);
    expect(find.text('10:00 PM'), findsNothing);

    await tapText(tester, 'Quiet hours');
    await tapText(tester, 'Set 10:00 PM');
    expect(settings().quietHours, isTrue);
    expect(find.text('7:00 AM'), findsOneWidget);
  });

  testWidgets('behaviour options: snooze, lock screen, badge', (tester) async {
    await setUp(tester);
    await open(tester);
    await tapText(tester, 'Default snooze');
    await tapText(tester, '15 min');
    expect(settings().defaultSnoozeMinutes, 15);
    await tapText(tester, 'Show on lock screen');
    await tapText(tester, 'Hidden');
    expect(settings().lockScreenVisibility, LockScreenVisibility.hidden);
    await tapText(tester, 'App icon badge');
    await tapText(tester, 'Due today');
    expect(settings().badgeMode, BadgeMode.today);
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    await setUp(tester);
    await pumpApp(
      tester,
      h,
      AppRoutes.settingsNotifications,
      size: const Size(360, 800),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Quiet hours'), findsOneWidget);
    // Titles and values are never cut: a value that does not fit beside
    // its title moves under it.
    for (final t in [
      'App icon badge',
      'Overdue count',
      'Show on lock screen',
      'Title only',
      'Default snooze',
    ]) {
      final p = tester.renderObject<RenderParagraph>(find.text(t));
      expect(p.didExceedMaxLines, isFalse, reason: t);
    }
    await captureScreen(tester, '31_settings_notifications_narrow');
  });
}
