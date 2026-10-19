/// `openLocation`: pages that live in the tab shell are pushed while the tab
/// bar is showing, but switched to with `go` from a full-screen route —
/// pushing one over a full-screen route stacked a second tab shell (same page
/// key) and left a blank screen (notification centre → "View" on "2 tasks are
/// overdue"). Pages on the root navigator are pushed from anywhere.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/router/app_shell.dart';
import 'package:focusflow/core/router/open_location.dart';
import 'package:focusflow/features/archive/presentation/screens/archive_screen.dart';
import 'package:focusflow/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:focusflow/features/notifications_center/presentation/screens/notification_center_screen.dart';
import 'package:focusflow/features/tasks/presentation/screens/tasks_list_screen.dart';

import '../../features/reminders/isolated_notifications.dart';
import '../../helpers/screen_harness.dart';
import '../../helpers/test_container.dart';

void main() {
  group("isShellPage (the router's own route table)", () {
    late TestHarness h;

    setUp(() async {
      h = await TestHarness.create(now: DateTime(2026, 6, 12, 9));
    });

    tearDown(() => h.dispose());

    test('pages inside the tab shell', () {
      final router = h.read(routerProvider);
      for (final r in [
        AppRoutes.home,
        AppRoutes.library,
        AppRoutes.notes,
        AppRoutes.tasks,
        AppRoutes.reminders,
        AppRoutes.habits,
        AppRoutes.pinned,
        AppRoutes.favourites,
        AppRoutes.tags,
        AppRoutes.tag('abc'),
        AppRoutes.insights,
        AppRoutes.settings,
        AppRoutes.settingsBackup,
        AppRoutes.settingsBackupRestore,
        AppRoutes.settingsImportExport,
        '${AppRoutes.tasks}?filter=overdue',
      ]) {
        expect(isShellPage(router, r), isTrue, reason: r);
      }
    });

    test('full-screen pages on the root navigator', () {
      final router = h.read(routerProvider);
      for (final r in [
        // Nested under a tab path, but declared on the root navigator.
        AppRoutes.vault,
        AppRoutes.archive,
        AppRoutes.trash,
        AppRoutes.settingsAppearance,
        AppRoutes.settingsNotifications,
        AppRoutes.settingsAccount,
        AppRoutes.settingsModule('tasks'),
        AppRoutes.search,
        AppRoutes.calendar,
        AppRoutes.notificationCenter,
        AppRoutes.note('n1'),
        AppRoutes.task('t1'),
        AppRoutes.reminder('r1'),
        AppRoutes.habit('h1'),
        AppRoutes.onboarding,
        AppRoutes.signIn,
        '/nowhere',
      ]) {
        expect(isShellPage(router, r), isFalse, reason: r);
      }
    });
  });

  group('openLocation', () {
    late TestHarness h;

    Future<void> boot(WidgetTester tester, String location) async {
      await loadAppFonts();
      h = (await tester.runAsync(
        () => TestHarness.create(
          now: DateTime(2026, 6, 13, 10),
          overrides: isolatedNotifications(),
        ),
      ))!;
      addTearDown(() => tester.runAsync(h.dispose));
      await pumpApp(tester, h, location);
    }

    testWidgets('from the tab bar a shell page is pushed (back returns)', (
      tester,
    ) async {
      await boot(tester, AppRoutes.home);
      final router = h.read(routerProvider);
      expect(tabShellIsTopmost(router), isTrue);

      tester.element(find.byType(AppShell)).openLocation(AppRoutes.tasks);
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(router.state.uri.toString(), AppRoutes.tasks);
      expect(find.byType(TasksListScreen).hitTestable(), findsOneWidget);
      expect(router.canPop(), isTrue);
      router.pop();
      await settle(tester);
      expect(find.byType(TasksListScreen), findsNothing);
      expect(find.byType(AppShell).hitTestable(), findsOneWidget);
    });

    testWidgets('from a full-screen route a shell page is switched to', (
      tester,
    ) async {
      await boot(tester, AppRoutes.home);
      final router = h.read(routerProvider);
      unawaited(router.push<void>(AppRoutes.calendar));
      await settle(tester);
      expect(find.byType(CalendarScreen).hitTestable(), findsOneWidget);
      expect(tabShellIsTopmost(router), isFalse);

      tester.element(find.byType(CalendarScreen)).openLocation(AppRoutes.tasks);
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(router.state.uri.toString(), AppRoutes.tasks);
      expect(find.byType(CalendarScreen), findsNothing);
      expect(find.byType(TasksListScreen).hitTestable(), findsOneWidget);
    });

    testWidgets('a root-level page is pushed even from a full-screen route', (
      tester,
    ) async {
      await boot(tester, AppRoutes.home);
      final router = h.read(routerProvider);
      unawaited(router.push<void>(AppRoutes.notificationCenter));
      await settle(tester);

      // Declared under /library but on the root navigator: safe to push, so
      // back returns to the notification centre.
      tester
          .element(find.byType(NotificationCenterScreen))
          .openLocation(AppRoutes.archive);
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(router.state.uri.toString(), AppRoutes.archive);
      expect(find.byType(ArchiveScreen).hitTestable(), findsOneWidget);

      router.pop();
      await settle(tester);
      expect(
        find.byType(NotificationCenterScreen).hitTestable(),
        findsOneWidget,
      );
    });
  });
}
