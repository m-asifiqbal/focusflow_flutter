/// ============================================================
/// REMINDER OCCURRENCE — one row of the reminders timeline / calendar
/// ============================================================
///
/// A repeating reminder appears once per occurrence (daily vitamins on
/// every day of the calendar); a one-time reminder once. [ReminderSchedule]
/// expands reminders into occurrences (pure, unit tested).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';

@immutable
class ReminderOccurrence {
  const ReminderOccurrence({
    required this.reminder,
    required this.at,
    this.isDone = false,
  });

  final Reminder reminder;

  /// When this occurrence fires (snooze applied to the pending one).
  final DateTime at;

  /// This occurrence was marked done (struck through at 45% opacity).
  final bool isDone;

  String get id => reminder.id;

  /// Not done and in the past.
  bool isPast(DateTime now) => !isDone && at.isBefore(now);

  @override
  bool operator ==(Object other) =>
      other is ReminderOccurrence &&
      other.reminder == reminder &&
      other.at == at &&
      other.isDone == isDone;

  @override
  int get hashCode => Object.hash(reminder, at, isDone);

  @override
  String toString() =>
      'ReminderOccurrence(${reminder.title} @ $at'
      '${isDone ? ' done' : ''})';
}

/// Pure occurrence expansion used by RemindersRepository and tests.
abstract final class ReminderSchedule {
  /// Occurrences of [r] in [from, to) (from inclusive), ascending:
  ///   • one-time: its [Reminder.effectiveTriggerAt] (done = completed);
  ///   • repeating: the pending occurrence (snooze applied), every later
  ///     occurrence of the rule, and the last occurrence marked done
  ///     ([Reminder.lastDoneAt]) as a done row.
  static List<ReminderOccurrence> between(
    Reminder r,
    DateTime from,
    DateTime to,
  ) {
    bool inRange(DateTime t) => !t.isBefore(from) && t.isBefore(to);
    final rule = r.recurrence;
    if (rule == null) {
      final at = r.effectiveTriggerAt;
      return inRange(at)
          ? [ReminderOccurrence(reminder: r, at: at, isDone: r.isCompleted)]
          : const [];
    }
    final result = <ReminderOccurrence>[];
    final done = r.lastDoneAt;
    if (done != null && done.isBefore(r.triggerAt) && inRange(done)) {
      result.add(ReminderOccurrence(reminder: r, at: done, isDone: true));
    }
    final pending = r.effectiveTriggerAt;
    if (inRange(pending)) {
      result.add(ReminderOccurrence(reminder: r, at: pending));
    }
    for (final t in rule.occurrencesBetween(r.triggerAt, from, to)) {
      if (t == r.triggerAt) continue; // represented by `pending`
      result.add(ReminderOccurrence(reminder: r, at: t));
    }
    result.sort((a, b) => a.at.compareTo(b.at));
    return result;
  }

  /// The next pending occurrence of [r] after [now] (see
  /// [Reminder.nextFireAfter]), or null.
  static ReminderOccurrence? next(Reminder r, DateTime now) {
    final at = r.nextFireAfter(now);
    return at == null ? null : ReminderOccurrence(reminder: r, at: at);
  }

  /// The occurrence representing [r] in flat lists (All / Recurring /
  /// Location / Snoozed / Missed): the next fire time, or the pending
  /// [Reminder.effectiveTriggerAt] when nothing is upcoming.
  static ReminderOccurrence current(Reminder r, DateTime now) {
    final at = r.nextFireAfter(now) ?? r.effectiveTriggerAt;
    return ReminderOccurrence(reminder: r, at: at, isDone: r.isCompleted);
  }
}
