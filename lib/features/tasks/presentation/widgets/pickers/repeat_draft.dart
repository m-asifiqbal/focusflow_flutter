/// ============================================================
/// REPEAT DRAFT — the editable state of the Repeat sheet
/// ============================================================
///
/// What: maps an RRULE onto the sheet's choices (None · Daily · Weekdays ·
/// Weekly on days · Monthly · Yearly · Custom: every N units, ends never /
/// on a date / after N times) and back to canonical RRULE text.
/// Why: pure Dart so the round trip is unit-testable; the sheet widget only
/// renders a [RepeatDraft] and calls its copy methods.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/utils/recurrence.dart';

enum RepeatChoice { none, daily, weekdays, weekly, monthly, yearly, custom }

enum RepeatEnd { never, onDate, after }

@immutable
class RepeatDraft {
  const RepeatDraft({
    required this.mode,
    required this.weekdays,
    required this.interval,
    required this.unit,
    required this.end,
    required this.until,
    required this.count,
    this.base,
  });

  /// Reads [rrule] (null = no repeat). [start] is the task's day — the
  /// default weekday / until date.
  factory RepeatDraft.fromRule(String? rrule, DateTime start) {
    final day = DateUtilsX.dateOnly(start);
    final rule = RecurrenceRule.tryParse(rrule);
    final defaults = RepeatDraft(
      mode: RepeatChoice.none,
      weekdays: {day.weekday},
      interval: 1,
      unit: RecurrenceFrequency.weekly,
      end: RepeatEnd.never,
      until: DateUtilsX.addDays(day, 30),
      count: 10,
    );
    if (rule == null) return defaults;
    final days = {
      for (final w in rule.byWeekdays)
        if (w.ordinal == null) w.weekday,
    };
    final hasOrdinals = rule.byWeekdays.any((w) => w.ordinal != null);
    final simple =
        rule.interval == 1 &&
        rule.count == null &&
        rule.until == null &&
        rule.byMonths.isEmpty;
    final noBy = rule.byWeekdays.isEmpty && rule.byMonthDays.isEmpty;
    RepeatChoice? mode;
    if (simple) {
      if (rule.isWeekdays) {
        mode = RepeatChoice.weekdays;
      } else {
        mode = switch (rule.frequency) {
          RecurrenceFrequency.daily when noBy => RepeatChoice.daily,
          RecurrenceFrequency.weekly
              when rule.byMonthDays.isEmpty && !hasOrdinals =>
            RepeatChoice.weekly,
          RecurrenceFrequency.monthly
              when rule.byWeekdays.isEmpty &&
                  (rule.byMonthDays.isEmpty ||
                      listEquals(rule.byMonthDays, [day.day])) =>
            RepeatChoice.monthly,
          RecurrenceFrequency.yearly when noBy => RepeatChoice.yearly,
          _ => null,
        };
      }
    }
    return RepeatDraft(
      mode: mode ?? RepeatChoice.custom,
      weekdays: days.isEmpty ? {day.weekday} : days,
      interval: rule.interval,
      unit: rule.frequency,
      end: rule.count != null
          ? RepeatEnd.after
          : rule.until != null
          ? RepeatEnd.onDate
          : RepeatEnd.never,
      until: rule.until == null
          ? defaults.until
          : DateUtilsX.dateOnly(rule.until!.toLocal()),
      count: rule.count ?? defaults.count,
      base: rule,
    );
  }

  final RepeatChoice mode;

  /// `DateTime.monday`…`sunday` (Weekly and Custom-weeks).
  final Set<int> weekdays;

  /// Custom: every [interval] [unit]s.
  final int interval;
  final RecurrenceFrequency unit;
  final RepeatEnd end;
  final DateTime until;
  final int count;

  /// The rule the sheet was opened with — keeps parts the sheet can't edit
  /// (month days, "2nd Tue") when Custom keeps the same unit.
  final RecurrenceRule? base;

  /// Canonical RRULE for the current choice; null for [RepeatChoice.none]
  /// (or Weekly with no day selected).
  String? toRRule() {
    final days = weekdays.toList()..sort();
    final rule = switch (mode) {
      RepeatChoice.none => null,
      RepeatChoice.daily => RecurrenceRule.daily(),
      RepeatChoice.weekdays => RecurrenceRule.weekdays(),
      RepeatChoice.weekly => days.isEmpty ? null : RecurrenceRule.weekly(days),
      RepeatChoice.monthly => RecurrenceRule.monthly(),
      RepeatChoice.yearly => RecurrenceRule.yearly(),
      RepeatChoice.custom => _custom(days),
    };
    return rule?.toRRule();
  }

  RecurrenceRule _custom(List<int> days) {
    final weekly = unit == RecurrenceFrequency.weekly;
    final keep = base != null && base!.frequency == unit;
    return RecurrenceRule(
      frequency: unit,
      interval: interval < 1 ? 1 : interval,
      byWeekdays: weekly
          ? [for (final d in days) WeekdayRule(d)]
          : keep
          ? base!.byWeekdays
          : const [],
      byMonthDays: keep && !weekly ? base!.byMonthDays : const [],
      byMonths: keep ? base!.byMonths : const [],
      count: end == RepeatEnd.after ? (count < 1 ? 1 : count) : null,
      until: end == RepeatEnd.onDate ? DateUtilsX.dateOnly(until) : null,
    );
  }

  /// Human label of the current choice ("Weekly · Tue", "Every 2 weeks…").
  String label(DateTime start) => Recurrence.label(toRRule(), start: start);

  RepeatDraft copyWith({
    RepeatChoice? mode,
    Set<int>? weekdays,
    int? interval,
    RecurrenceFrequency? unit,
    RepeatEnd? end,
    DateTime? until,
    int? count,
  }) => RepeatDraft(
    mode: mode ?? this.mode,
    weekdays: weekdays ?? this.weekdays,
    interval: interval ?? this.interval,
    unit: unit ?? this.unit,
    end: end ?? this.end,
    until: until ?? this.until,
    count: count ?? this.count,
    base: base,
  );

  /// Toggles one weekday (Weekly / Custom-weeks).
  RepeatDraft toggleWeekday(int weekday) {
    final next = {...weekdays};
    next.contains(weekday) ? next.remove(weekday) : next.add(weekday);
    return copyWith(weekdays: next);
  }
}
