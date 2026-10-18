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
    required DateTime date,
    this.count = 0,
    this.skipped = false,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  }) : _date = date, // ignore: prefer_initializing_formals (named + private)
       _key = null;

  /// A log read from storage, where the day is the `yyyy-MM-dd` text of the
  /// row. Nothing is parsed until [date] is asked for: a habit with years of
  /// history is loaded often (Home, the planner, the library counts) and
  /// every consumer of the history works with [dayKey] only.
  const HabitLog.keyed({
    required this.id,
    required this.habitId,
    required String dayKey,
    this.count = 0,
    this.skipped = false,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  }) : _date = null,
       _key = dayKey; // ignore: prefer_initializing_formals (named + private)

  final String id;
  final String habitId;

  // Exactly one of the two is set; the other is derived on demand.
  final DateTime? _date;
  final String? _key;

  /// Local calendar day (midnight).
  DateTime get date => _date ?? DateUtilsX.parseDayKey(_key!);

  /// Build: check-ins; quit: slips.
  final int count;
  final bool skipped;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// `yyyy-MM-dd` key of [date].
  String get dayKey => _key ?? DateUtilsX.dayKey(_date!);

  HabitLog copyWith({
    int? count,
    bool? skipped,
    String? note,
    bool clearNote = false,
    DateTime? updatedAt,
  }) => HabitLog._(
    id,
    habitId,
    _date,
    _key,
    count ?? this.count,
    skipped ?? this.skipped,
    clearNote ? null : (note ?? this.note),
    createdAt,
    updatedAt ?? this.updatedAt,
  );

  const HabitLog._(
    this.id,
    this.habitId,
    this._date,
    this._key,
    this.count,
    this.skipped,
    this.note,
    this.createdAt,
    this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is HabitLog &&
      other.id == id &&
      other.habitId == habitId &&
      other.dayKey == dayKey &&
      other.count == count &&
      other.skipped == skipped &&
      other.note == note &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    habitId,
    dayKey,
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
