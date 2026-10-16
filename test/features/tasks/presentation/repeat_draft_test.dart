/// RepeatDraft (the repeat sheet's pure rule logic, screens 11 / 13):
/// presets are recognised from their RRULE, Custom builds interval / ends,
/// parts the sheet can't edit survive a same-unit edit, and Weekly with no
/// day selected means "no rule".
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/utils/recurrence.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/repeat_draft.dart';

void main() {
  // Tue 16 Jun 2026.
  final start = DateTime(2026, 6, 16);

  test('no rule → Never with the start day as default weekday', () {
    final d = RepeatDraft.fromRule(null, start);
    expect(d.mode, RepeatChoice.none);
    expect(d.weekdays, {DateTime.tuesday});
    expect(d.toRRule(), isNull);
  });

  test('presets round-trip through their RRULE', () {
    for (final mode in [
      RepeatChoice.daily,
      RepeatChoice.weekdays,
      RepeatChoice.weekly,
      RepeatChoice.monthly,
      RepeatChoice.yearly,
    ]) {
      final rule = RepeatDraft.fromRule(
        null,
        start,
      ).copyWith(mode: mode).toRRule();
      expect(rule, isNotNull, reason: '$mode');
      expect(RepeatDraft.fromRule(rule, start).mode, mode, reason: rule);
    }
  });

  test('Weekly with every day unselected yields no rule', () {
    final d = RepeatDraft.fromRule(
      null,
      start,
    ).copyWith(mode: RepeatChoice.weekly).toggleWeekday(DateTime.tuesday);
    expect(d.weekdays, isEmpty);
    expect(d.toRRule(), isNull);
  });

  test('Custom: every 2 weeks on Mon + Thu, after 5 times', () {
    final d = RepeatDraft.fromRule(null, start).copyWith(
      mode: RepeatChoice.custom,
      unit: RecurrenceFrequency.weekly,
      interval: 2,
      end: RepeatEnd.after,
      count: 5,
      weekdays: {DateTime.thursday, DateTime.monday},
    );
    final rule = RecurrenceRule.tryParse(d.toRRule())!;
    expect(rule.frequency, RecurrenceFrequency.weekly);
    expect(rule.interval, 2);
    expect(rule.count, 5);
    expect(rule.until, isNull);
    expect(
      [for (final w in rule.byWeekdays) w.weekday],
      [DateTime.monday, DateTime.thursday],
    );
    // Re-opening shows Custom with the same values.
    final back = RepeatDraft.fromRule(d.toRRule(), start);
    expect(back.mode, RepeatChoice.custom);
    expect(back.interval, 2);
    expect(back.end, RepeatEnd.after);
    expect(back.count, 5);
  });

  test('Custom: ends on a date covers that whole day', () {
    final d = RepeatDraft.fromRule('FREQ=DAILY', start).copyWith(
      mode: RepeatChoice.custom,
      unit: RecurrenceFrequency.daily,
      end: RepeatEnd.onDate,
      until: DateTime(2026, 6, 18, 15, 30),
    );
    final rule = RecurrenceRule.tryParse(d.toRRule())!;
    // A 10:00 reminder still fires on the last day.
    final at = DateTime(2026, 6, 16, 10);
    final hits = rule.occurrencesBetween(at, at, DateTime(2026, 6, 25));
    expect(hits.last, DateTime(2026, 6, 18, 10));
    expect(hits, hasLength(3));
  });

  test('Custom keeps month days it cannot edit when the unit is unchanged', () {
    final d = RepeatDraft.fromRule('FREQ=MONTHLY;BYMONTHDAY=1,15', start);
    expect(d.mode, RepeatChoice.custom);
    final edited = d.copyWith(interval: 3);
    final rule = RecurrenceRule.tryParse(edited.toRRule())!;
    expect(rule.interval, 3);
    expect(rule.byMonthDays, [1, 15]);
    // Switching unit drops them.
    final weekly = d.copyWith(unit: RecurrenceFrequency.weekly);
    expect(RecurrenceRule.tryParse(weekly.toRRule())!.byMonthDays, isEmpty);
  });

  test('interval and count are clamped to at least 1', () {
    final d = RepeatDraft.fromRule(null, start).copyWith(
      mode: RepeatChoice.custom,
      unit: RecurrenceFrequency.daily,
      interval: 0,
      end: RepeatEnd.after,
      count: 0,
    );
    final rule = RecurrenceRule.tryParse(d.toRRule())!;
    expect(rule.interval, 1);
    expect(rule.count, 1);
  });
}
