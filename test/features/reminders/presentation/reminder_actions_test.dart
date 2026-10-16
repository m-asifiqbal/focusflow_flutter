/// ReminderActions.snooze counts from when the reminder is due (or from
/// now if it is already due), so snoozing never moves a reminder earlier.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/presentation/notifiers/reminder_actions.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';
import '../isolated_notifications.dart';

final _now = DateTime(2026, 10, 13, 9, 35);

Reminder _r(DateTime at, {DateTime? snoozedUntil}) => Reminder(
  id: 'r',
  title: 'Call the bank',
  triggerAt: at,
  snoozedUntil: snoozedUntil,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  group('ReminderActions.snoozeTarget', () {
    test('a reminder due later is pushed later, not pulled earlier', () {
      expect(
        ReminderActions.snoozeTarget(_r(DateTime(2026, 10, 13, 10)), _now, 10),
        DateTime(2026, 10, 13, 10, 10),
      );
      // Due next week: snoozing 10 min must not fire it 10 min from now.
      final nextWeek = DateTime(2026, 10, 20, 9);
      final t = ReminderActions.snoozeTarget(_r(nextWeek), _now, 10);
      expect(t, DateTime(2026, 10, 20, 9, 10));
      expect(t.isBefore(nextWeek), isFalse);
    });

    test('a due or missed reminder snoozes from now', () {
      expect(
        ReminderActions.snoozeTarget(_r(DateTime(2026, 10, 12, 17)), _now, 10),
        DateTime(2026, 10, 13, 9, 45),
      );
    });

    test('an active snooze is extended from its end', () {
      expect(
        ReminderActions.snoozeTarget(
          _r(
            DateTime(2026, 10, 13, 9, 30),
            snoozedUntil: DateTime(2026, 10, 13, 9, 40),
          ),
          _now,
          10,
        ),
        DateTime(2026, 10, 13, 9, 50),
      );
    });
  });

  test('snooze writes snoozedUntil and returns the reminder before', () async {
    final h = await TestHarness.create(
      now: _now,
      overrides: isolatedNotifications(),
    );
    addTearDown(h.dispose);
    final repo = h.read(remindersRepositoryProvider);
    final id = await repo.save(_r(DateTime(2026, 10, 20, 9)).copyWith(id: ''));
    final before = await h.read(reminderActionsProvider).snooze(id);
    expect(before?.snoozedUntil, isNull);
    final after = await repo.getReminder(id);
    expect(after!.snoozedUntil, DateTime(2026, 10, 20, 9, 10));
    expect(
      after.effectiveTriggerAt.isBefore(DateTime(2026, 10, 20, 9)),
      isFalse,
    );
  });
}
