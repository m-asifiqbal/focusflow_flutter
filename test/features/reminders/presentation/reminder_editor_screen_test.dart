/// Reminder editor (screen 13): the mockup's new reminder renders every
/// section (light + dark captures), prefill from `/reminders/new?...`,
/// chips / wheel / alert choices are saved, an existing reminder can be
/// edited, archived and deleted, Cancel asks to discard, and no overflow at
/// 360 pt / 1.3×.
/// Captures build/screens/13_reminder_editor{,_dark,_360_x13,_edit,_link,
/// _location}.png.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/reminders/presentation/widgets/editor/reminder_when_section.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/presentation/screens/reminder_editor_screen.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../isolated_notifications.dart';

/// Mockup clock: Tue 13 Oct 2026, 9:41.
final _now = DateTime(2026, 10, 13, 9, 41);

/// The mockup is one tall frame (390 × 1099 pt).
const _tall = Size(390, 1099);

Future<TestHarness> _harness(WidgetTester tester) async {
  tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  addTearDown(tester.view.resetPadding);
  final h = (await tester.runAsync(
    () => TestHarness.create(now: _now, overrides: isolatedNotifications()),
  ))!;
  addTearDown(() => tester.runAsync(h.dispose));
  return h;
}

Future<List<Reminder>> _all(WidgetTester tester, TestHarness h) async =>
    (await tester.runAsync(
      () => h.read(remindersRepositoryProvider).watchSchedulable().first,
    ))!;

Future<String> _seed(TestHarness h, {String? rrule}) => h
    .read(remindersRepositoryProvider)
    .save(
      Reminder.draft(
        triggerAt: DateTime(2026, 10, 22, 18, 30),
        title: 'Pay rent',
        repeatRule: rrule,
      ).copyWith(note: 'Landlord account', createdAt: _now, updatedAt: _now),
    );

/// Scrolls the editor form until [finder] is built and visible.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first,
  );
}

void main() {
  // Regression: a bare Text in a taller pill is stretched to the pill's
  // minimum height, but its glyphs are painted at the TOP of that box — the
  // label sat high in the capsule. The test measures where the text line is
  // actually drawn, not the stretched box.
  testWidgets('repeat pills centre their label', (tester) async {
    final h = await _harness(tester);
    await pumpApp(tester, h, AppRoutes.newReminder(), size: _tall);
    for (final label in const [
      'Once',
      'Daily',
      'Weekdays',
      'Weekly',
      'Monthly',
      'Custom',
    ]) {
      await _scrollTo(tester, find.text(label));
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      final line = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: label.length),
          )
          .first
          .toRect();
      final drawnCenter = paragraph.localToGlobal(line.center).dy;
      final pill = tester.getRect(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(
        (drawnCenter - pill.center.dy).abs(),
        lessThan(0.75),
        reason: '$label is not vertically centred in its pill',
      );
    }
  });

  testWidgets('new reminder matches the mockup (light + dark captures)', (
    tester,
  ) async {
    await loadAppFonts();
    final h = await _harness(tester);
    final location = AppRoutes.newReminder(title: 'Call the bank about card');
    await pumpApp(tester, h, location, size: _tall);
    // The mockup shows the form unfocused.
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);

    expect(find.byType(ReminderEditorScreen), findsOneWidget);
    expect(find.text('New Reminder'), findsOneWidget);
    expect(find.text('Call the bank about card'), findsOneWidget);
    for (final t in const [
      'WHEN', 'Today', 'Tomorrow', 'Next week', 'Pick date', //
      'REPEAT', 'Once', 'Daily', 'Weekdays', 'Weekly', 'Monthly', 'Custom',
      'ALERT', 'Sound', 'Chime', 'Alarm-style (full screen)',
      'Default snooze', '10 min', 'Location trigger', 'Off',
      'LINK TO', 'Task or note', 'None',
    ]) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    expect(find.text('Archive'), findsNothing);
    await captureScreen(tester, '13_reminder_editor');

    await pumpApp(tester, h, location, size: _tall, dark: true);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await captureScreen(tester, '13_reminder_editor_dark');
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    await loadAppFonts();
    final h = await _harness(tester);
    await pumpApp(
      tester,
      h,
      AppRoutes.newReminder(title: 'Call the bank about card'),
      size: const Size(360, 800),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    // The WHEN tiles share one text scale.
    double labelHeight(String label) => tester
        .getRect(
          find.descendant(
            of: find.byType(ReminderDayChips),
            matching: find.text(label),
          ),
        )
        .height;
    final today = labelHeight('Today');
    for (final label in ['Tomorrow', 'Next week', 'Pick date']) {
      expect(labelHeight(label), moreOrLessEquals(today, epsilon: 0.5));
    }
    await captureScreen(tester, '13_reminder_editor_360_x13');
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('prefill + chips + alert choices are saved', (tester) async {
    final h = await _harness(tester);
    final taskId = (await tester.runAsync(
      () => h
          .read(tasksRepositoryProvider)
          .save(
            TaskItem(
              id: '',
              title: 'File taxes',
              createdAt: _now,
              updatedAt: _now,
            ),
          ),
    ))!;
    await pumpApp(
      tester,
      h,
      AppRoutes.newReminder(
        title: 'Taxes',
        at: DateTime(2026, 10, 13, 15, 30),
        repeatRule: 'FREQ=DAILY',
        link: ItemRef(ItemType.task, taskId),
      ),
      size: _tall,
    );
    expect(find.text('File taxes'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);

    await tester.tap(find.text('Tomorrow'));
    await tester.tap(find.text('Weekdays'));
    await settle(tester);
    await tester.tap(find.text('Alarm-style (full screen)'));
    await settle(tester);
    await tester.tap(find.text('Default snooze'));
    await settle(tester);
    await tester.tap(find.text('15 min'));
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.byType(ReminderEditorScreen), findsNothing);

    final r = (await _all(tester, h)).single;
    expect(r.title, 'Taxes');
    expect(r.triggerAt, DateTime(2026, 10, 14, 15, 30));
    expect(r.repeatRule, 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR');
    expect(r.snoozeMinutes, 15);
    expect(r.linkedRef, ItemRef(ItemType.task, taskId));
    expect(r.alertStyle, AlertStyle.alarm);
  });

  testWidgets('wheel changes the time; Save needs a title', (tester) async {
    final h = await _harness(tester);
    await pumpApp(tester, h, AppRoutes.newReminderPath, size: _tall);
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.byType(ReminderEditorScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Stretch');
    // Drag the minute wheel up two rows (00 → 10).
    await tester.drag(find.text('00').first, const Offset(0, -84));
    await settle(tester);
    await tester.tap(find.text('PM').first);
    await tester.drag(find.text('AM').first, const Offset(0, -42));
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);
    final r = (await _all(tester, h)).single;
    expect(r.triggerAt, DateTime(2026, 10, 13, 22, 10));
  });

  testWidgets('edit: link picker, location sheet, archive', (tester) async {
    await loadAppFonts();
    final h = await _harness(tester);
    final id = (await tester.runAsync(() => _seed(h)))!;
    await tester.runAsync(
      () => h.read(notesRepositoryProvider).createEmpty(title: 'Lease'),
    );
    await pumpApp(tester, h, AppRoutes.reminder(id), size: _tall);
    expect(find.text('Edit Reminder'), findsOneWidget);
    expect(find.text('Thu 22 Oct'), findsOneWidget);
    await captureScreen(tester, '13_reminder_editor_edit');

    await _scrollTo(tester, find.text('Location trigger'));
    await settle(tester);
    await tester.tap(find.text('Location trigger'));
    await settle(tester);
    expect(find.text('Location triggers are coming soon'), findsOneWidget);
    await captureScreen(tester, '13_reminder_editor_location');
    await tester.tap(find.text('Got it'));
    await settle(tester);

    await _scrollTo(tester, find.text('Task or note'));
    await settle(tester);
    await tester.tap(find.text('Task or note'));
    await settle(tester);
    await tester.tap(find.text('Notes'));
    await settle(tester);
    await captureScreen(tester, '13_reminder_editor_link');
    await tester.tap(find.text('Lease'));
    await settle(tester);
    expect(find.text('Note'), findsOneWidget);

    await _scrollTo(tester, find.text('Archive'));
    await settle(tester);
    await tester.tap(find.text('Archive'));
    await settle(tester);
    expect(find.byType(ReminderEditorScreen), findsNothing);
    final r = (await tester.runAsync(
      () => h.read(remindersRepositoryProvider).getReminder(id),
    ))!;
    expect(r.isArchived, isTrue);
    expect(r.linkedRef?.type, ItemType.note);
  });

  testWidgets('cancel with changes asks to discard; delete', (tester) async {
    final h = await _harness(tester);
    final id = (await tester.runAsync(() => _seed(h)))!;
    await pumpApp(tester, h, AppRoutes.reminder(id), size: _tall);

    await tester.tap(find.text('Daily'));
    await settle(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await settle(tester);
    expect(find.byType(ReminderEditorScreen), findsOneWidget);

    await _scrollTo(tester, find.text('Delete'));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await tester.tap(find.text('Delete').last);
    await settle(tester);
    expect(find.byType(ReminderEditorScreen), findsNothing);
    final r = (await tester.runAsync(
      () => h.read(remindersRepositoryProvider).getReminder(id),
    ))!;
    expect(r.isDeleted, isTrue);
  });

  testWidgets('unknown id shows not found', (tester) async {
    final h = await _harness(tester);
    await pumpApp(tester, h, AppRoutes.reminder('nope'), size: _tall);
    expect(find.text('Reminder not found'), findsOneWidget);
  });

  testWidgets('a passed one-time time shows a hint and saves for tomorrow', (
    tester,
  ) async {
    final h = await _harness(tester);
    await pumpApp(
      tester,
      h,
      AppRoutes.newReminder(title: 'Stretch', at: DateTime(2026, 10, 13, 8)),
      size: _tall,
    );
    expect(find.textContaining('This time has passed'), findsOneWidget);
    expect(find.textContaining('saving sets it for tomorrow'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.textContaining('Time had passed'), findsOneWidget);
    final r = (await _all(tester, h)).single;
    expect(r.triggerAt, DateTime(2026, 10, 14, 8));
  });

  testWidgets("'Today' follows the clock without a list screen ticking it", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final h = await _harness(tester);
    // The minute clock last ticked yesterday (e.g. the app slept), then
    // the editor opens straight from Quick Add after midnight.
    h.read(minuteClockProvider);
    h.clock.set(DateTime(2026, 10, 14, 0, 5));
    await pumpApp(tester, h, AppRoutes.newReminder(title: 'Late'));
    bool selected(String label) =>
        tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData()
            .flagsCollection
            .isSelected ==
        Tristate.isTrue;
    // Default 01:00 on the 14th is "Today", not "Tomorrow".
    expect(selected('Today'), isTrue);
    expect(selected('Tomorrow'), isFalse);

    // The When chips expose a semantics tap (TalkBack / VoiceOver).
    final tomorrow = tester.getSemantics(find.bySemanticsLabel('Tomorrow'));
    expect(tomorrow.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tomorrow.owner!.performAction(tomorrow.id, SemanticsAction.tap);
    await settle(tester);
    expect(selected('Tomorrow'), isTrue);
    semantics.dispose();
  });
}
