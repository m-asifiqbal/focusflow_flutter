/// Screen 27 — Notification center: mockup data (light + dark captures),
/// filter chips, Read all, inline Done / Snooze through the shared
/// notification actions, swipe-dismiss with Undo, tap opens the item (back
/// returns here) or, for a row without one, its list in its tab, the empty
/// state and no overflow at 360 pt / text scale 1.3.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/backup/presentation/screens/backup_sync_screen.dart';
import 'package:focusflow/features/habits/presentation/screens/habits_list_screen.dart';
import 'package:focusflow/features/notifications_center/presentation/screens/notification_center_screen.dart';
import 'package:focusflow/features/notifications_center/presentation/widgets/inbox_row.dart';
import 'package:focusflow/features/tasks/presentation/screens/tasks_list_screen.dart';
import 'package:focusflow/features/vault/presentation/screens/vault_screen.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../../reminders/isolated_notifications.dart';
import 'notification_center_seed.dart';

void main() {
  late TestHarness h;
  late InboxSeed seed;

  Future<void> boot(WidgetTester tester, {bool withData = true}) async {
    await loadAppFonts();
    h = (await tester.runAsync(
      () =>
          TestHarness.create(now: inboxNow, overrides: isolatedNotifications()),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    if (withData) seed = (await tester.runAsync(() => seedInboxMockup(h)))!;
  }

  Future<int> unread(WidgetTester tester) async => (await tester.runAsync(
    () => h.read(inboxRepositoryProvider).watchUnreadCount().first,
  ))!;

  testWidgets('renders the mockup data (light)', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.notificationCenter);
    await captureScreen(tester, '27_notification_center');

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Read all'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('EARLIER'), findsOneWidget);
    expect(find.text('Call the bank about card'), findsOneWidget);
    expect(find.text('now'), findsOneWidget);
    expect(find.text('8:00'), findsOneWidget);
    expect(find.text('7:45'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Snooze 10m'), findsOneWidget);
    expect(find.text('Reschedule'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Yesterday'), findsNWidgets(2));
    expect(find.text('Mon'), findsOneWidget);
    expect(find.byType(InboxRow), findsNWidgets(6));
  });

  testWidgets('dark mode capture', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.notificationCenter, dark: true);
    expect(find.byType(InboxRow), findsNWidgets(6));
    await captureScreen(tester, '27_notification_center_dark');
  });

  testWidgets('filter chips show one kind', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.notificationCenter);
    await tester.tap(find.text('Tasks'));
    await settle(tester);
    expect(find.byType(InboxRow), findsOneWidget);
    expect(find.text('2 tasks are overdue'), findsOneWidget);
  });

  testWidgets('Read all marks every entry read', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.notificationCenter);
    expect(await unread(tester), 3);
    await tester.tap(find.text('Read all'));
    await settle(tester);
    expect(await unread(tester), 0);
  });

  testWidgets('Done completes the reminder with Undo', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.notificationCenter);
    await tester.tap(find.text('Done'));
    await settle(tester);
    final r = await tester.runAsync(
      () => h.read(remindersRepositoryProvider).getReminder(seed.reminderId),
    );
    expect(r!.isCompleted, isTrue);
    expect(find.text('"Call the bank about card" done'), findsOneWidget);
    expect(await unread(tester), 2);
    await tester.tap(find.text('UNDO'));
    await settle(tester);
    final back = await tester.runAsync(
      () => h.read(remindersRepositoryProvider).getReminder(seed.reminderId),
    );
    expect(back!.isCompleted, isFalse);
  });

  testWidgets('Snooze snoozes the reminder by the default', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.notificationCenter);
    await tester.tap(find.text('Snooze 10m'));
    await settle(tester);
    final r = await tester.runAsync(
      () => h.read(remindersRepositoryProvider).getReminder(seed.reminderId),
    );
    expect(r!.snoozedUntil, inboxNow.add(const Duration(minutes: 10)));
    expect(find.text('Snoozed for 10 min'), findsOneWidget);
  });

  testWidgets('swipe dismisses with Undo', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.notificationCenter);
    await tester.drag(
      find.text('Weak password detected'),
      const Offset(-500, 0),
    );
    await settle(tester);
    expect(find.text('Weak password detected'), findsNothing);
    expect(find.text('Notification dismissed'), findsOneWidget);
    await tester.tap(find.text('UNDO'));
    await settle(tester);
    expect(find.text('Weak password detected'), findsOneWidget);
  });

  testWidgets('tapping a row opens the item', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.notificationCenter);
    await tester.tap(find.text('Due at 10:00 AM'));
    await settle(tester);
    // `state.uri` follows imperative pushes; `currentConfiguration.uri`
    // stays on the base location in go_router 18.
    final loc = h.read(routerProvider).state.uri.toString();
    expect(loc, AppRoutes.reminder(seed.reminderId));
    expect(await unread(tester), 2);
  });

  // Regression: these rows have no item, so they open a tab page (a list).
  // Pushing one over this full-screen route stacked a second tab shell with
  // the same page key and left a blank screen. Opened the way the app does
  // it: Home → bell → notification centre → tap.
  group('a row without an item opens its list', () {
    // (row, where it goes, the screen, whether it is a drill-in). The Tasks /
    // Habits / Backup pages live in the tab shell, so the tab is switched to;
    // the vault is a root-level page, so it is pushed and back returns here.
    final cases = <(String, String, Type, bool)>[
      ('2 tasks are overdue', AppRoutes.tasks, TasksListScreen, false),
      ('Drink Water — 6/8', AppRoutes.habits, HabitsListScreen, false),
      ('Backup complete', AppRoutes.settingsBackup, BackupSyncScreen, false),
      ('Weak password detected', AppRoutes.vault, VaultScreen, true),
    ];
    for (final (title, route, screen, drillIn) in cases) {
      testWidgets('$title → $route', (tester) async {
        await boot(tester);
        await pumpApp(tester, h, AppRoutes.home);
        final router = h.read(routerProvider);
        unawaited(router.push<void>(AppRoutes.notificationCenter));
        await settle(tester);
        expect(find.byType(NotificationCenterScreen), findsOneWidget);

        await tester.tap(find.text(title));
        await settle(tester);

        expect(tester.takeException(), isNull);
        expect(router.state.uri.toString(), route);
        expect(find.byType(NotificationCenterScreen), findsNothing);
        // On screen and tappable — not built into a hidden navigator.
        expect(find.byType(screen).hitTestable(), findsOneWidget);

        if (drillIn) {
          router.pop();
          await settle(tester);
          expect(find.byType(screen), findsNothing);
          expect(
            find.byType(NotificationCenterScreen).hitTestable(),
            findsOneWidget,
          );
        }
      });
    }

    testWidgets('View on the overdue digest, centre opened by go', (
      tester,
    ) async {
      await boot(tester);
      await pumpApp(tester, h, AppRoutes.notificationCenter);
      await tester.tap(find.text('View'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(h.read(routerProvider).state.uri.toString(), AppRoutes.tasks);
      expect(find.byType(TasksListScreen).hitTestable(), findsOneWidget);
    });
  });

  testWidgets('empty state', (tester) async {
    await boot(tester, withData: false);
    await pumpApp(tester, h, AppRoutes.notificationCenter);
    expect(find.text("You're all caught up"), findsOneWidget);
    await captureScreen(tester, '27_notification_center_empty');
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    await boot(tester);
    await pumpApp(
      tester,
      h,
      AppRoutes.notificationCenter,
      size: const Size(360, 800),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '27_notification_center_360_x13');
  });
}
