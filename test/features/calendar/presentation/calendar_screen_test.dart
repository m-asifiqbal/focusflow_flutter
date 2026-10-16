/// Screen 26 — Calendar: mockup data in Month view (light + dark
/// captures), mode switching, tapping a day, the empty day, deep links
/// (`?date=`), swipe to change month, drag-to-reschedule with Undo,
/// opening a row, Home's "View Monthly", and no overflow at 360 pt /
/// text scale 1.3.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/calendar/presentation/widgets/calendar_agenda_row.dart';
import 'package:focusflow/features/calendar/presentation/widgets/calendar_grid_card.dart';
import 'package:focusflow/features/quick_add/presentation/widgets/quick_add_sheet.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../../reminders/isolated_notifications.dart';
import '../calendar_seed.dart';

void main() {
  late TestHarness h;
  late CalendarSeed seed;

  Future<void> boot(WidgetTester tester) async {
    await loadAppFonts();
    h = (await tester.runAsync(
      () => TestHarness.create(
        now: calendarNow,
        overrides: isolatedNotifications(),
      ),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    seed = (await tester.runAsync(() => seedCalendarMockup(h)))!;
  }

  Finder nothingPlanned() =>
      find.textContaining('Nothing planned', findRichText: true);

  testWidgets('renders the mockup data in Month view (light)', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.calendar);
    await captureScreen(tester, '26_calendar');

    expect(find.text('June 2023'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.byType(CalendarMonthCard), findsOneWidget);
    // Sunday week start (seeded setting) → SUN is the first column.
    final sun = tester.getTopLeft(find.text('SUN'));
    final mon = tester.getTopLeft(find.text('MON'));
    expect(sun.dx, lessThan(mon.dx));
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Tuesday, June 13'), findsOneWidget);
    expect(find.text('4 items'), findsOneWidget);
    expect(find.byType(CalendarAgendaRow), findsNWidgets(4));
    expect(find.text('Review FocusFlow Q3 Strategy'), findsOneWidget);
    expect(find.text('Task · High'), findsOneWidget);
    expect(find.text('Call the bank about card'), findsOneWidget);
    expect(find.text('Reminder'), findsOneWidget);
    expect(find.text('Habit · done'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('All day'), findsOneWidget);
  });

  testWidgets('dark mode capture', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.calendar, dark: true);
    expect(find.byType(CalendarAgendaRow), findsNWidgets(4));
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '26_calendar_dark');
  });

  testWidgets('switching modes', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.calendar);
    await tester.tap(find.text('Week'));
    await settle(tester);
    expect(find.byType(CalendarWeekCard), findsOneWidget);
    expect(find.byType(CalendarMonthCard), findsNothing);
    expect(find.textContaining('reschedule'), findsOneWidget);
    expect(find.byType(CalendarAgendaRow), findsNWidgets(4));
    await captureScreen(tester, '26_calendar_week');

    await tester.tap(find.text('Agenda'));
    await settle(tester);
    expect(find.text('Jun 13 – Jun 19'), findsOneWidget);
    expect(find.text('Tuesday, June 13'), findsOneWidget);
    expect(find.text('Wednesday, June 14'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Next week'));
    await settle(tester);
    expect(find.text('Jun 20 – Jun 26'), findsOneWidget);
  });

  testWidgets('tapping a day lists it', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.calendar);
    await tester.tap(find.text('14'));
    await settle(tester);
    expect(find.text('Wednesday, June 14'), findsOneWidget);
    // Dentist + the daily habit.
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Dentist'), findsOneWidget);
  });

  testWidgets('empty day offers Quick Add on that day', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.calendar);
    // 1 June: before the habit starts, nothing else seeded.
    await tester.tap(find.text('1').first);
    await settle(tester);
    expect(find.text('Thursday, June 1'), findsOneWidget);
    expect(find.text('0 items'), findsOneWidget);
    expect(nothingPlanned(), findsOneWidget);
    await captureScreen(tester, '26_calendar_empty_day');
    await tester.tap(nothingPlanned());
    await settle(tester);
    expect(find.byType(QuickAddSheet), findsOneWidget);
  });

  testWidgets('deep link opens on the date; bad dates fall back to today', (
    tester,
  ) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.calendarOn(DateTime(2023, 7, 4)));
    expect(find.text('July 2023'), findsOneWidget);
    expect(find.text('Tuesday, July 4'), findsOneWidget);

    h.read(routerProvider).go('${AppRoutes.calendar}?date=2023-02-30');
    await settle(tester);
    expect(find.text('Tuesday, June 13'), findsOneWidget);
  });

  testWidgets('swipe changes month', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.calendar);
    await tester.fling(
      find.byType(CalendarMonthCard),
      const Offset(-300, 0),
      1000,
    );
    await settle(tester);
    expect(find.text('July 2023'), findsOneWidget);
    expect(find.text('Thursday, July 13'), findsOneWidget);
    await tester.fling(
      find.byType(CalendarMonthCard),
      const Offset(300, 0),
      1000,
    );
    await settle(tester);
    await tester.fling(
      find.byType(CalendarMonthCard),
      const Offset(300, 0),
      1000,
    );
    await settle(tester);
    expect(find.text('May 2023'), findsOneWidget);
  });

  testWidgets('drag a task onto another day reschedules it, with Undo', (
    tester,
  ) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.calendar);
    await tester.tap(find.text('Week'));
    await settle(tester);

    final row = find.text('Review FocusFlow Q3 Strategy');
    final gesture = await tester.startGesture(tester.getCenter(row));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(find.text('15')));
    await tester.pump();
    await gesture.up();
    await settle(tester);

    Future<DateTime?> due() async => (await tester.runAsync(
      () => h.read(tasksRepositoryProvider).getTask(seed.reviewTaskId),
    ))!.dueDate;

    expect(await due(), DateTime(2023, 6, 15));
    expect(find.text('Moved to Thu, Jun 15'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await settle(tester);
    expect(await due(), calendarToday);
    expect(find.text('4 items'), findsOneWidget);
  });

  testWidgets('tapping a row opens the item', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.calendar);
    await tester.tap(find.text('Design Home Screen v2'));
    await settle(tester);
    expect(
      h.read(routerProvider).state.uri.toString(),
      AppRoutes.task(seed.designTaskId),
    );
  });

  testWidgets("Home's View Monthly opens the calendar on the selected day", (
    tester,
  ) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.home);
    await tester.tap(find.text('View Monthly'));
    await settle(tester);
    expect(
      h.read(routerProvider).state.uri.toString(),
      AppRoutes.calendarOn(calendarToday),
    );
    expect(find.text('Tuesday, June 13'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('no overflow at 360 pt and text scale 1.3 '
        '(${dark ? 'dark' : 'light'})', (tester) async {
      await boot(tester);
      await pumpApp(
        tester,
        h,
        AppRoutes.calendar,
        size: const Size(360, 800),
        textScale: 1.3,
        dark: dark,
      );
      expect(tester.takeException(), isNull);
      for (final mode in ['Week', 'Agenda', 'Month']) {
        await tester.tap(find.text(mode));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: mode);
      }
      await captureScreen(tester, '26_calendar_360_x13${dark ? '_dark' : ''}');
    });
  }
}
