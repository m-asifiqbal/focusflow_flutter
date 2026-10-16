/// ============================================================
/// HABIT LOG — one day of one habit
/// ============================================================
///
/// Stored per (habitId, local day) in `habit_logs`. Semantics depend on the
/// habit kind (see Habit.isDoneWith):
///   • build habit: [count] = check-ins that day (done when ≥ target).
///   • quit habit:  [count] = slips that day (clean when 0 / no log).
/// [skipped] marks a deliberate rest day — it never breaks a streak.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';

@immutable
class HabitLog {
  const HabitLog({
    required this.id,
    required this.habitId,
    required this.date,
    this.count = 0,
    this.skipped = false,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String habitId;

  /// Local calendar day (midnight).
  final DateTime date;

  /// Build: check-ins; quit: slips.
  final int count;
  final bool skipped;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// `yyyy-MM-dd` key of [date].
  String get dayKey => DateUtilsX.dayKey(date);

  HabitLog copyWith({
    int? count,
    bool? skipped,
    String? note,
    bool clearNote = false,
    DateTime? updatedAt,
  }) => HabitLog(
    id: id,
    habitId: habitId,
    date: date,
    count: count ?? this.count,
    skipped: skipped ?? this.skipped,
    note: clearNote ? null : (note ?? this.note),
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is HabitLog &&
      other.id == id &&
      other.habitId == habitId &&
      other.date == date &&
      other.count == count &&
      other.skipped == skipped &&
      other.note == note &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    habitId,
    date,
    count,
    skipped,
    note,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'HabitLog($habitId $dayKey count=$count${skipped ? ' skipped' : ''})';
}
