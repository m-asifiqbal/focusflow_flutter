/// Reminder editor form rules: route args parsing, WHEN / REPEAT chip
/// derivation, dirty tracking and what Save writes; controller defaults
/// (next full hour, Settings sound / snooze) and day changes keeping the
/// time and re-anchoring a weekly repeat.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/presentation/notifiers/reminder_editor_controller.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_alert_options.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_editor_state.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';
import '../isolated_notifications.dart';

final _now = DateTime(2026, 10, 13, 9, 41); // Tuesday

void main() {
  group('ReminderEditorArgs.fromRoute', () {
    test('new with prefill', () {
      final at = DateTime(2026, 10, 14, 8, 15);
      final args = ReminderEditorArgs.fromRoute('new', {
        'title': ' Call mum ',
        'at': at.toIso8601String(),
        'rrule': 'FREQ=DAILY',
        'linkType': 'task',
        'linkId': 't1',
      });
      expect(args.isNew, isTrue);
      expect(args.title, 'Call mum');
      expect(args.at, at);
      expect(args.repeatRule, 'FREQ=DAILY');
      expect(args.link, ItemRef(ItemType.task, 't1'));
    });

    test('existing id ignores the query; bad values are dropped', () {
      expect(ReminderEditorArgs.fromRoute('abc', {'title': 'x'}).id, 'abc');
      final args = ReminderEditorArgs.fromRoute('new', {
        'at': 'nope',
        'linkType': 'task',
      });
      expect(args.at, isNull);
      expect(args.link, isNull);
    });
  });

  test('WhenChoice.of / dayFor (week starts Monday)', () {
    final today = DateTime(2026, 10, 13);
    WhenChoice of(DateTime d) => WhenChoice.of(d, today, DateTime.monday);
    expect(of(DateTime(2026, 10, 13, 22)), WhenChoice.today);
    expect(of(DateTime(2026, 10, 14, 7)), WhenChoice.tomorrow);
    expect(of(DateTime(2026, 10, 19)), WhenChoice.nextWeek);
    expect(of(DateTime(2026, 10, 22)), WhenChoice.other);
    expect(
      WhenChoice.nextWeek.dayFor(today, DateTime.sunday),
      DateTime(2026, 10, 18),
    );
    expect(WhenChoice.other.dayFor(today, DateTime.monday), isNull);
  });

  test('RepeatPreset.of round-trips the quick chips', () {
    final tue = DateTime(2026, 10, 13, 10);
    for (final p in [
      RepeatPreset.daily,
      RepeatPreset.weekdays,
      RepeatPreset.weekly,
      RepeatPreset.monthly,
    ]) {
      expect(RepeatPreset.of(p.rule(tue), tue), p);
    }
    expect(RepeatPreset.of(null, tue), RepeatPreset.once);
    expect(RepeatPreset.of('FREQ=YEARLY', tue), RepeatPreset.custom);
    expect(
      RepeatPreset.of('FREQ=WEEKLY;BYDAY=MO,WE', tue),
      RepeatPreset.custom,
    );
  });

  test('alert option labels', () {
    expect(ReminderAlertOptions.soundLabel('chime'), 'Chime');
    expect(ReminderAlertOptions.soundLabel('marimba'), 'Marimba');
    expect(ReminderAlertOptions.snoozeLabel(10), '10 min');
    expect(ReminderAlertOptions.snoozeLabel(60), '1 hour');
    expect(ReminderAlertOptions.snoozeLabel(120), '2 hours');
  });

  test('moving a done reminder re-arms it on save', () {
    final r = Reminder.draft(
      triggerAt: DateTime(2026, 10, 12, 9),
      title: 'x',
    ).copyWith(id: 'r1', completedAt: _now, isEnabled: false);
    final s = ReminderEditorState(original: r, draft: r);
    expect(s.isDirty, isFalse);
    final moved = s.copyWith(
      draft: r.copyWith(triggerAt: DateTime(2026, 10, 14, 9)),
    );
    expect(moved.isDirty, isTrue);
    final out = moved.toReminder();
    expect(out.completedAt, isNull);
    expect(out.isEnabled, isTrue);
  });

  group('controller', () {
    late TestHarness h;
    setUp(
      () async => h = await TestHarness.create(
        now: _now,
        overrides: isolatedNotifications(),
      ),
    );
    tearDown(() => h.dispose());

    test('new: next full hour, defaults from settings', () async {
      const args = ReminderEditorArgs(title: 'Bank');
      final s = await h.read(reminderEditorControllerProvider(args).future);
      expect(s.draft.triggerAt, DateTime(2026, 10, 13, 10));
      expect(s.draft.title, 'Bank');
      expect(s.canSave, isTrue);
      expect(s.isDirty, isFalse);
    });

    test('setDay keeps the time and moves a weekly repeat', () async {
      const args = ReminderEditorArgs(title: 'Gym');
      final sub = h.container.listen(
        reminderEditorControllerProvider(args),
        (_, _) {},
      );
      addTearDown(sub.close);
      await h.read(reminderEditorControllerProvider(args).future);
      final form = h.read(reminderEditorControllerProvider(args).notifier);
      form.setTime(18 * 60 + 30);
      form.setRepeat(RepeatPreset.weekly.rule(DateTime(2026, 10, 13)));
      form.setDay(DateTime(2026, 10, 15)); // Thursday
      final s = h.read(reminderEditorControllerProvider(args)).value!;
      expect(s.draft.triggerAt, DateTime(2026, 10, 15, 18, 30));
      expect(
        RepeatPreset.of(s.draft.repeatRule, s.draft.triggerAt),
        RepeatPreset.weekly,
      );
      expect(s.draft.repeatRule, contains('TH'));

      final id = await form.save();
      final saved = await h.read(remindersRepositoryProvider).getReminder(id!);
      expect(saved!.triggerAt, DateTime(2026, 10, 15, 18, 30));
    });

    test('a one-time time that has passed is saved for its next '
        'occurrence', () async {
      const args = ReminderEditorArgs(title: 'Stretch');
      final sub = h.container.listen(
        reminderEditorControllerProvider(args),
        (_, _) {},
      );
      addTearDown(sub.close);
      await h.read(reminderEditorControllerProvider(args).future);
      final form = h.read(reminderEditorControllerProvider(args).notifier);
      form.setDay(DateTime(2026, 10, 13));
      form.setTime(8 * 60); // 08:00 < now (09:41)
      final s = h.read(reminderEditorControllerProvider(args)).value!;
      expect(s.pastTimeRollsTo(_now), DateTime(2026, 10, 14, 8));
      final id = await form.save();
      final saved = await h.read(remindersRepositoryProvider).getReminder(id!);
      expect(saved!.triggerAt, DateTime(2026, 10, 14, 8));
      expect(saved.isMissed(_now), isFalse);
    });
  });

  group('pastTimeRollsTo', () {
    Reminder draft(DateTime at, {String? rrule}) =>
        Reminder.draft(triggerAt: at, title: 'R', repeatRule: rrule);

    test('future, repeating and untouched existing times stay', () {
      final future = draft(DateTime(2026, 10, 13, 10));
      expect(
        ReminderEditorState(
          original: future,
          draft: future,
        ).pastTimeRollsTo(_now),
        isNull,
      );
      final daily = draft(DateTime(2026, 10, 13, 8), rrule: 'FREQ=DAILY');
      expect(
        ReminderEditorState(
          original: daily,
          draft: daily,
        ).pastTimeRollsTo(_now),
        isNull,
      );
      final missed = draft(DateTime(2026, 10, 12, 17)).copyWith(id: 'm');
      expect(
        ReminderEditorState(
          original: missed,
          draft: missed.copyWith(title: 'Renamed'),
        ).pastTimeRollsTo(_now),
        isNull,
      );
    });

    test('a past day keeps its time today when that is still ahead', () {
      final past = draft(DateTime(2026, 10, 12, 15));
      expect(
        ReminderEditorState(original: past, draft: past).pastTimeRollsTo(_now),
        DateTime(2026, 10, 13, 15),
      );
      expect(
        ReminderEditorState(
          original: past,
          draft: past,
        ).toReminder(now: _now).triggerAt,
        DateTime(2026, 10, 13, 15),
      );
    });
  });
}
