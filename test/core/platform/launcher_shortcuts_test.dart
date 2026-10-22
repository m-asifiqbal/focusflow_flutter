/// App-icon long-press shortcuts: the key ↔ route contract with the native
/// definitions (shortcuts.xml / Info.plist), the platform channel (initial
/// shortcut once, then pushed ones) and opening each on top of the app.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/platform/launcher_shortcuts.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/habits/presentation/screens/habits_list_screen.dart';
import 'package:focusflow/features/notifications_center/presentation/screens/notification_center_screen.dart';

import '../../features/reminders/isolated_notifications.dart';
import '../../helpers/screen_harness.dart';
import '../../helpers/test_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keys match the native shortcut ids and each has a route', () {
    // These strings are also in android/.../res/xml/shortcuts.xml (extra
    // "shortcut") and ios/Runner/Info.plist (UIApplicationShortcutItemType).
    expect(
      {for (final s in LauncherShortcut.values) s.key: s.route},
      {
        'notifications': AppRoutes.notificationCenter,
        'new_note': AppRoutes.newNote,
        'new_reminder': AppRoutes.newReminderPath,
        'habits': AppRoutes.habits,
      },
    );
    expect(LauncherShortcut.fromKey('new_note'), LauncherShortcut.newNote);
    expect(LauncherShortcut.fromKey('bogus'), isNull);
    expect(LauncherShortcut.fromKey(null), isNull);
  });

  group('channel', () {
    const channel = MethodChannel(LauncherShortcuts.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('initial returns the launching shortcut', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getInitial');
        return 'new_reminder';
      });
      expect(
        await const LauncherShortcuts().initial(),
        LauncherShortcut.newReminder,
      );
    });

    test(
      'initial is null without a shortcut, unknown key or platform',
      () async {
        messenger.setMockMethodCallHandler(channel, (_) async => null);
        expect(await const LauncherShortcuts().initial(), isNull);
        messenger.setMockMethodCallHandler(channel, (_) async => 'bogus');
        expect(await const LauncherShortcuts().initial(), isNull);
        messenger.setMockMethodCallHandler(channel, null);
        expect(await const LauncherShortcuts().initial(), isNull);
      },
    );

    test('listen receives shortcuts pushed by the platform', () async {
      final got = <LauncherShortcut>[];
      const LauncherShortcuts().listen(got.add);
      Future<void> push(String key) => messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall('onShortcut', key)),
        (_) {},
      );
      await push('habits');
      await push('bogus');
      await push('notifications');
      expect(got, [LauncherShortcut.habits, LauncherShortcut.notifications]);
      const LauncherShortcuts().stopListening();
    });
  });

  group('opening', () {
    late TestHarness h;

    Future<void> boot(WidgetTester tester) async {
      await loadAppFonts();
      h = (await tester.runAsync(
        () => TestHarness.create(
          now: DateTime(2026, 6, 12, 9),
          overrides: isolatedNotifications(),
        ),
      ))!;
      addTearDown(() => tester.runAsync(h.dispose));
      await pumpApp(tester, h, AppRoutes.home);
    }

    testWidgets('each shortcut opens its page over Home', (tester) async {
      await boot(tester);
      final router = h.read(routerProvider);

      openLauncherShortcut(router, LauncherShortcut.notifications);
      await settle(tester);
      expect(router.state.uri.toString(), AppRoutes.notificationCenter);
      expect(find.byType(NotificationCenterScreen), findsOneWidget);

      // From a full-screen page the tab page is reached with `go`, not a
      // second shell (the blank-screen rule in open_location.dart).
      openLauncherShortcut(router, LauncherShortcut.habits);
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(router.state.uri.toString(), AppRoutes.habits);
      expect(find.byType(HabitsListScreen).hitTestable(), findsOneWidget);

      openLauncherShortcut(router, LauncherShortcut.newNote);
      await settle(tester);
      expect(router.state.uri.path, AppRoutes.newNote);

      // Same page again: nothing stacks up.
      final depth = router.routerDelegate.currentConfiguration.matches.length;
      openLauncherShortcut(router, LauncherShortcut.newNote);
      await settle(tester);
      expect(router.routerDelegate.currentConfiguration.matches.length, depth);

      openLauncherShortcut(router, LauncherShortcut.newReminder);
      await settle(tester);
      expect(router.state.uri.path, AppRoutes.newReminderPath);
      expect(tester.takeException(), isNull);
    });
  });
}
