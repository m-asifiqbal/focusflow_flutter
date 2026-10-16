/// Reminder editor (screen 13) permission states on Android 12+ / 14+:
/// "Reminders may be late — allow exact alarms" with an Allow button that
/// opens the system page, and alarm-style asking for full-screen intents
/// (with a hint while they stay off). Neither shows when allowed.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/router/app_routes.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../../../core/notifications/fake_gateway.dart';
import '../isolated_notifications.dart';

final _now = DateTime(2026, 10, 13, 9, 41);
const _exactText = 'Reminders may be late — allow exact alarms.';
const _fullScreenText =
    'Full-screen alarms are off — this reminder will show as a regular '
    'alert.';

Future<(TestHarness, FakeGateway)> _harness(
  WidgetTester tester, {
  required ExactAlarmPermission exact,
  required bool fullScreen,
}) async {
  final os = FakeGateway()
    ..exact = exact
    ..fullScreen = fullScreen;
  final h = (await tester.runAsync(
    () => TestHarness.create(
      now: _now,
      overrides: isolatedNotifications(gateway: os),
    ),
  ))!;
  addTearDown(() => tester.runAsync(h.dispose));
  return (h, os);
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );

void main() {
  testWidgets('exact alarms denied: banner + Allow opens the system page', (
    tester,
  ) async {
    final (h, os) = await _harness(
      tester,
      exact: ExactAlarmPermission.denied,
      fullScreen: false,
    );
    await pumpApp(
      tester,
      h,
      AppRoutes.newReminder(title: 'Pills'),
      size: const Size(390, 1400),
    );
    await settle(tester);
    expect(find.text(_exactText), findsOneWidget);
    await tester.tap(find.text('Allow'));
    await settle(tester);
    expect(os.exactRequests, 1);

    // Alarm-style asks for full-screen intents and explains the fallback.
    await _scrollTo(tester, find.text('Alarm-style (full screen)'));
    await tester.tap(find.text('Alarm-style (full screen)'));
    await settle(tester);
    expect(os.fullScreenRequests, 1);
    await _scrollTo(tester, find.text(_fullScreenText));
    expect(find.text(_fullScreenText), findsOneWidget);
  });

  testWidgets('everything allowed: no banners, nothing requested', (
    tester,
  ) async {
    final (h, os) = await _harness(
      tester,
      exact: ExactAlarmPermission.granted,
      fullScreen: true,
    );
    await pumpApp(
      tester,
      h,
      AppRoutes.newReminder(title: 'Pills'),
      size: const Size(390, 1400),
    );
    await settle(tester);
    expect(find.text(_exactText), findsNothing);
    await _scrollTo(tester, find.text('Alarm-style (full screen)'));
    await tester.tap(find.text('Alarm-style (full screen)'));
    await settle(tester);
    expect(os.fullScreenRequests, 0);
    expect(find.text(_fullScreenText), findsNothing);
  });
}
