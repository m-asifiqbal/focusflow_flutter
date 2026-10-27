/// ============================================================
/// MEDICINE CALENDAR — dose states of any span of days (detail screen)
/// ============================================================
///
/// Pure function behind the Week · Month · Year views of "taken doses":
/// for each day of a span, the states of the medicine's scheduled doses at
/// "now" (same rules as the week grid: a pause never rewrites history,
/// nothing before the start date or after the end date). [DayOutcome] folds
/// a day's states into the one colour the year view paints.
/// Cost: one schedule lookup per day (≤ 366 for a year), no I/O — the logs
/// are read once by the repository for the whole span.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_schedule.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_stats.dart';

/// How a day went, in one word.
enum DayOutcome {
  /// Nothing scheduled.
  none,

  /// Nothing logged yet (today, or a future day).
  pending,

  /// Every dose taken.
  taken,

  /// Some taken, some missed / skipped / still to come.
  partial,

  /// Doses missed, none taken.
  missed,

  /// Doses skipped, none taken or missed.
  skipped;

  static DayOutcome of(List<DoseState> states) {
    if (states.isEmpty) return none;
    var taken = 0, missed = 0, skipped = 0;
    for (final s in states) {
      switch (s) {
        case DoseState.taken:
          taken++;
        case DoseState.missed:
          missed++;
        case DoseState.skipped:
          skipped++;
        case DoseState.snoozed || DoseState.due || DoseState.upcoming:
          break;
      }
    }
    if (taken == states.length) return DayOutcome.taken;
    if (taken > 0) return DayOutcome.partial;
    if (missed > 0) return DayOutcome.missed;
    if (skipped > 0) return DayOutcome.skipped;
    return DayOutcome.pending;
  }
}

abstract final class MedicineCalendar {
  /// The most days one span may cover (a year).
  static const int maxDays = 366;

  /// The days `[from, to]` (inclusive, oldest first) with their dose states
  /// at [now]. [logs] may hold other days / medicines; they are ignored.
  static List<MedicineWeekDay> days(
    Medicine m,
    Iterable<DoseLog> logs,
    DateTime from,
    DateTime to,
    DateTime now,
  ) {
    final first = DateUtilsX.dateOnly(from);
    final count = DateUtilsX.daysBetween(first, DateUtilsX.dateOnly(to)) + 1;
    if (count <= 0) return const [];
    final byId = {
      for (final l in logs)
        if (l.medicineId == m.id) l.id: l,
    };
    return List.unmodifiable([
      for (var i = 0; i < count && i < maxDays; i++)
        () {
          final day = DateUtilsX.addDays(first, i);
          return MedicineWeekDay(
            day: day,
            states: [
              for (final s in MedicineSchedule.slotsOn(
                m,
                day,
                byId,
                ignorePause: true,
              ))
                s.stateAt(now),
            ],
          );
        }(),
    ]);
  }
}

/// The span a calendar view asks the logs for.
@immutable
class MedicineLogSpan {
  const MedicineLogSpan(this.id, this.from, this.to);

  final String id;

  /// First / last day (inclusive, local midnights).
  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is MedicineLogSpan &&
      other.id == id &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(id, from, to);
}
