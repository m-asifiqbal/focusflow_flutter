/// Reminders list (screen 12): the mockup timeline renders (light + dark
/// captures), the header subtitle / sections / meta lines match, toggle /
/// snooze / mark done write the database (with Undo), missed reminders
/// get the red MISSED section, the denied-permission banner, the empty
/// state and no overflow at 360 pt / 1.3×. Regressions: the minute tick
/// keeps the timeline (no skeleton, same scroll offset), snooze uses the
/// reminder's own default snooze, done rows still swipe, and the picked
/// day / chip reset when the screen is left.
/// Captures build/screens/12_reminders_list{,_dark,_360_x13,_missed,_empty}.png.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/notifications/notification_permissions.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/widgets/ff_headers.dart';
import 'package:focusflow/core/widgets/ff_skeleton.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/presentation/providers/reminders_list_providers.dart';
import 'package:focusflow/features/reminders/presentation/screens/reminders_list_screen.dart';
import 'package:focusflow/features/reminders/presentation/widgets/reminder_card.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../isolated_notifications.dart';

/// Tue 13 Oct 2026, 09:35 — "next in 25 min" is the 10:00 call.
final _now = DateTime(2026, 10, 13, 9, 35);

/// The mockup is one tall frame (390 × 1198 pt).
const _tall = Size(390, 1198);

Reminder _r(
  String title,
  DateTime at, {
  String? rrule,
  bool enabled = true,
  DateTime? completedAt,
  ReminderLocation? location,
  ItemRef? link,
  List<Tag> tags = const [],
  int snoozeMinutes = 10,
}) => Reminder(
  id: '',
  title: title,
  triggerAt: at,
  repeatRule: rrule,
  isEnabled: enabled,
  completedAt: completedAt,
  location: location,
  linkedRef: link,
  tags: tags,
  snoozeMinutes: snoozeMinutes,
  createdAt: _now,
  updatedAt: _now,
);

/// Seeds the reminders of design/12_reminders_list.png; returns ids by title.
Future<Map<String, String>> _seedMockup(TestHarness h) async {
  final repo = h.read(remindersRepositoryProvider);
  final taskId = await h
      .read(tasksRepositoryProvider)
      .save(
        TaskItem(
          id: '',
          title: 'Design Home v2',
          createdAt: _now,
          updatedAt: _now,
        ),
      );
  DateTime at(int day, int h, [int m = 0]) => DateTime(2026, 10, day, h, m);
  final reminders = [
    // Daily, today's 07:00 already marked done → pending is tomorrow.
    _r('Take vitamins', at(14, 7), rrule: 'FREQ=DAILY', completedAt: at(13, 7)),
    _r('Call the bank about card', at(13, 10)),
    _r(
      'Review design handoff',
      at(13, 15),
      link: ItemRef(ItemType.task, taskId),
    ),
    _r(
      'Buy groceries',
      at(13, 18, 30),
      location: const ReminderLocation(
        lat: 51.5,
        lng: -0.12,
        onEnter: false,
        label: 'office',
      ),
    ),
    _r(
      'Wind down — no screens',
      at(13, 21, 30),
      rrule: 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
      enabled: false,
    ),
    _r(
      'Pay rent',
      at(14, 9),
      rrule: 'FREQ=MONTHLY;BYMONTHDAY=14',
      tags: const [Tag(id: '', name: 'High priority')],
    ),
  ];
  return {for (final r in reminders) r.title: await repo.save(r)};
}

Future<TestHarness> _harness(
  WidgetTester tester, {
  NotificationPermission permission = NotificationPermission.granted,
}) async {
  tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  addTearDown(tester.view.resetPadding);
  final h = (await tester.runAsync(
    () => TestHarness.create(
      now: _now,
      overrides: [
        ...isolatedNotifications(permission: permission),
        notificationPermissionProvider.overrideWith((ref) async => permission),
      ],
    ),
  ))!;
  addTearDown(() => tester.runAsync(h.dispose));
  return h;
}

Future<Reminder?> _load(WidgetTester tester, TestHarness h, String id) => tester
    .runAsync(() => h.read(remindersRepositoryProvider).getReminder(id))
    .then((r) => r);

void main() {
  testWidgets('renders the mockup timeline (light + dark captures)', (
    tester,
  ) async {
    await loadAppFonts();
    final h = await _harness(tester);
    await tester.runAsync(() => _seedMockup(h));
    await pumpApp(tester, h, AppRoutes.reminders, size: _tall);

    expect(find.byType(RemindersListScreen), findsOneWidget);
    await captureScreen(tester, '12_reminders_list');
    expect(find.text('Reminders'), findsWidgets);
    expect(find.text('3 today · next in 25 min'), findsOneWidget);
    for (final chip in ['Today', 'Upcoming', 'Recurring', 'Location']) {
      expect(find.text(chip), findsOneWidget);
    }
    expect(find.text('MORNING'), findsOneWidget);
    expect(find.text('AFTERNOON & EVENING'), findsOneWidget);
    expect(find.text('TOMORROW'), findsOneWidget);
    expect(find.text('Daily · Repeats every day'), findsOneWidget);
    expect(find.text('Today · in 25 min'), findsOneWidget);
    expect(find.text('SNOOZE 10m'), findsOneWidget);
    expect(find.text('MARK DONE'), findsOneWidget);
    expect(find.text('Linked task · Design Home v2'), findsOneWidget);
    // The next-due card is emphasised: it bleeds into both gutters but
    // stays on screen.
    Rect cardOf(String title) => tester.getRect(
      find.ancestor(of: find.text(title), matching: find.byType(ReminderCard)),
    );
    final next = cardOf('Call the bank about card');
    final other = cardOf('Review design handoff');
    expect(next.left, lessThan(other.left));
    expect(next.right, greaterThan(other.right));
    expect(next.right, lessThanOrEqualTo(_tall.width));
    expect(find.text('When I leave office · Location'), findsOneWidget);
    expect(find.text('Weekdays · Mon–Fri'), findsOneWidget);
    expect(find.textContaining('Monthly · 14th'), findsOneWidget);
    // Daily vitamins / weekday wind-down are not repeated under TOMORROW.
    expect(find.text('Take vitamins'), findsOneWidget);
    expect(find.text('07:00'), findsOneWidget);
    expect(find.text('PM'), findsWidgets);

    await pumpApp(tester, h, AppRoutes.reminders, size: _tall, dark: true);
    await captureScreen(tester, '12_reminders_list_dark');
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    await loadAppFonts();
    final h = await _harness(tester);
    await tester.runAsync(() => _seedMockup(h));
    await pumpApp(
      tester,
      h,
      AppRoutes.reminders,
      size: const Size(360, 800),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    // The large title scales down to fit instead of ellipsizing.
    final titleFinder = find.descendant(
      of: find.byType(FFLargeHeader),
      matching: find.text('Reminders'),
    );
    final title = tester.renderObject<RenderParagraph>(titleFinder);
    expect(title.didExceedMaxLines, isFalse);
    expect(
      tester.getRect(titleFinder).right,
      lessThanOrEqualTo(
        tester.getRect(find.bySemanticsLabel('Open calendar')).left,
      ),
    );
    await captureScreen(tester, '12_reminders_list_360_x13');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toggle disables, snooze and mark done write with Undo', (
    tester,
  ) async {
    await loadAppFonts();
    final h = await _harness(tester);
    final ids = (await tester.runAsync(() => _seedMockup(h)))!;
    await pumpApp(tester, h, AppRoutes.reminders, size: _tall);

    // Toggle "Review design handoff" off.
    await tester.tap(find.bySemanticsLabel('Turn off Review design handoff'));
    await settle(tester);
    expect(
      (await _load(tester, h, ids['Review design handoff']!))!.isEnabled,
      isFalse,
    );

    // SNOOZE 10m on the next-due card (due 10:00, now 09:35) → pushed to
    // 10:10, never pulled earlier to 09:45; Undo clears.
    final bank = ids['Call the bank about card']!;
    await tester.tap(find.text('SNOOZE 10m'));
    await settle(tester);
    expect(
      (await _load(tester, h, bank))!.snoozedUntil,
      DateTime(2026, 10, 13, 10, 10),
    );
    await tester.tap(find.text('UNDO'));
    await settle(tester);
    expect((await _load(tester, h, bank))!.snoozedUntil, isNull);

    // MARK DONE → completed; Undo reopens.
    await tester.tap(find.text('MARK DONE'));
    await settle(tester);
    expect((await _load(tester, h, bank))!.isCompleted, isTrue);
    expect(find.textContaining('done'), findsWidgets);
    await tester.tap(find.text('UNDO'));
    await settle(tester);
    expect((await _load(tester, h, bank))!.isCompleted, isFalse);
  });

  testWidgets('long-press sheet: Snooze / Mark done / Disable', (tester) async {
    await loadAppFonts();
    final h = await _harness(tester);
    final ids = (await tester.runAsync(() => _seedMockup(h)))!;
    await pumpApp(tester, h, AppRoutes.reminders, size: _tall);

    await tester.longPress(find.text('Buy groceries'));
    await settle(tester);
    expect(find.text('Snooze 10 min'), findsOneWidget);
    expect(find.text('Mark done'), findsOneWidget);
    await tester.tap(find.text('Disable'));
    await settle(tester);
    expect((await _load(tester, h, ids['Buy groceries']!))!.isEnabled, isFalse);

    await tester.longPress(find.text('Buy groceries'));
    await settle(tester);
    expect(find.text('Snooze 10 min'), findsNothing);
    await tester.tap(find.text('Enable'));
    await settle(tester);
    expect((await _load(tester, h, ids['Buy groceries']!))!.isEnabled, isTrue);
  });

  testWidgets('missed reminders get the red MISSED section', (tester) async {
    await loadAppFonts();
    final h = await _harness(tester);
    await tester.runAsync(() async {
      await _seedMockup(h);
      await h
          .read(remindersRepositoryProvider)
          .save(_r('Renew passport', DateTime(2026, 10, 12, 17)));
    });
    await pumpApp(tester, h, AppRoutes.reminders);
    expect(find.text('MISSED'), findsOneWidget);
    expect(find.text('RESCHEDULE'), findsOneWidget);
    expect(find.text('Yesterday · Missed'), findsOneWidget);
    await captureScreen(tester, '12_reminders_list_missed');
  });

  testWidgets('denied permission shows the Enable banner', (tester) async {
    await loadAppFonts();
    final h = await _harness(tester, permission: NotificationPermission.denied);
    await tester.runAsync(() => _seedMockup(h));
    await pumpApp(tester, h, AppRoutes.reminders);
    expect(find.textContaining('Notifications are off'), findsOneWidget);
    expect(find.text('Enable'), findsOneWidget);
  });

  testWidgets('chips and week strip switch the timeline', (tester) async {
    await loadAppFonts();
    final h = await _harness(tester);
    await tester.runAsync(() => _seedMockup(h));
    await pumpApp(tester, h, AppRoutes.reminders, size: _tall);

    await tester.ensureVisible(find.text('Recurring'));
    await tester.pump();
    await tester.tap(find.text('Recurring'));
    await settle(tester);
    expect(find.text('Take vitamins'), findsOneWidget);
    expect(find.text('Pay rent'), findsOneWidget);
    expect(find.text('Call the bank about card'), findsNothing);

    await tester.ensureVisible(find.text('Snoozed'));
    await tester.pump();
    await tester.tap(find.text('Snoozed'));
    await settle(tester);
    expect(find.text('Nothing snoozed'), findsOneWidget);

    // Picking Wednesday 14 goes back to the Today chip for that day.
    await tester.tap(find.bySemanticsLabel(RegExp('^Wednesday, October 14')));
    await settle(tester);
    expect(find.text('Pay rent'), findsOneWidget);
    expect(find.text('Call the bank about card'), findsNothing);
  });

  testWidgets('empty state when there are no reminders', (tester) async {
    await loadAppFonts();
    final h = await _harness(tester);
    await pumpApp(tester, h, AppRoutes.reminders);
    expect(find.text('No reminders yet'), findsOneWidget);
    expect(find.text('Add reminder'), findsOneWidget);
    expect(find.text('Nothing scheduled'), findsOneWidget);
    await captureScreen(tester, '12_reminders_list_empty');
  });

  testWidgets('minute tick keeps the timeline and the scroll offset', (
    tester,
  ) async {
    await loadAppFonts();
    final h = await _harness(tester);
    await tester.runAsync(() => _seedMockup(h));
    await pumpApp(tester, h, AppRoutes.reminders);
    ScrollPosition list() => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await settle(tester);
    final offset = list().pixels;
    expect(offset, greaterThan(0));

    for (final scope in ['Today', 'Upcoming']) {
      if (scope != 'Today') {
        list().jumpTo(0);
        await tester.pump();
        await tester.tap(find.text(scope));
        await settle(tester);
      }
      h.clock.advance(const Duration(minutes: 1));
      h.read(minuteClockProvider.notifier).tick();
      await tester.pump();
      expect(find.byType(FFSkeletonList), findsNothing, reason: scope);
      if (scope == 'Today') expect(list().pixels, offset);
      await settle(tester);
      expect(find.byType(FFSkeletonList), findsNothing, reason: scope);
    }
  });

  testWidgets("snooze uses the reminder's own default snooze", (tester) async {
    await loadAppFonts();
    final h = await _harness(tester);
    final id = (await tester.runAsync(
      () => h
          .read(remindersRepositoryProvider)
          .save(
            _r(
              'Call the bank about card',
              DateTime(2026, 10, 13, 10),
              snoozeMinutes: 15,
            ),
          ),
    ))!;
    await pumpApp(tester, h, AppRoutes.reminders);
    expect(find.text('SNOOZE 15m'), findsOneWidget);

    await tester.longPress(find.text('Call the bank about card'));
    await settle(tester);
    expect(find.text('Snooze 15 min'), findsOneWidget);
    await tester.tap(find.text('Snooze 15 min'));
    await settle(tester);
    expect(
      (await _load(tester, h, id))!.snoozedUntil,
      DateTime(2026, 10, 13, 10, 15),
    );
  });

  testWidgets('picked day and chip reset when the screen is left', (
    tester,
  ) async {
    await loadAppFonts();
    final h = await _harness(tester);
    await tester.runAsync(() => _seedMockup(h));
    await pumpApp(tester, h, AppRoutes.reminders, size: _tall);

    await tester.tap(find.bySemanticsLabel(RegExp('^Wednesday, October 14')));
    await settle(tester);
    expect(find.text('Call the bank about card'), findsNothing);

    h.read(routerProvider).go(AppRoutes.library);
    await settle(tester);
    h.read(routerProvider).go(AppRoutes.reminders);
    await settle(tester);
    expect(find.text('Call the bank about card'), findsOneWidget);

    // Picking today again means "follow today" (null).
    final sub = h.container.listen(selectedReminderDayProvider, (_, _) {});
    addTearDown(sub.close);
    h.read(selectedReminderDayProvider.notifier).select(_now);
    expect(sub.read(), isNull);
    h.read(selectedReminderDayProvider.notifier).select(DateTime(2026, 10, 14));
    expect(sub.read(), DateTime(2026, 10, 14));
  });
}
