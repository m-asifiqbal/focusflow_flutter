/// ============================================================
/// MEDICINE STATS — adherence, streak, this week and history
/// ============================================================
///
/// Pure function of a medicine, its dose logs and "now" (detail screen):
///   • adherence — taken ÷ (taken + skipped + missed) over the last 30 days,
///     counting only doses whose time has come (null when none has);
///   • streak — consecutive days, back from today, on which no scheduled
///     dose was missed and at least one was taken. Today only counts once
///     all its doses are logged; until then it neither counts nor breaks
///     the streak. Days with nothing scheduled are skipped over;
///   • week — the last 7 days (oldest first), each with its doses' states;
///   • history — the doses of the last 30 days whose time has come, newest
///     first (logged as-needed doses included).
/// Pausing is ignored here: history never changes because of a pause.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_schedule.dart';

/// One day of the "This week" grid.
@immutable
class MedicineWeekDay {
  const MedicineWeekDay({required this.day, required this.states});

  final DateTime day;

  /// The day's scheduled doses in time order (empty = nothing due).
  final List<DoseState> states;

  @override
  bool operator ==(Object other) =>
      other is MedicineWeekDay &&
      other.day == day &&
      listEquals(other.states, states);

  @override
  int get hashCode => Object.hash(day, Object.hashAll(states));
}

@immutable
class MedicineStats {
  const MedicineStats({
    required this.adherence,
    required this.streak,
    required this.takenToday,
    required this.dueToday,
    required this.week,
    required this.history,
    required this.nextDose,
  });

  /// 0–1 over the last 30 days; null when no dose was due yet.
  final double? adherence;

  /// Days in a row with every dose taken (see the file header).
  final int streak;

  /// Doses of today taken / scheduled.
  final int takenToday;
  final int dueToday;

  final List<MedicineWeekDay> week;

  /// Doses whose time has come, newest first.
  final List<DoseSlot> history;

  /// Today's first dose not logged yet (null when none is left).
  final DoseSlot? nextDose;

  static const int windowDays = 30;

  @override
  bool operator ==(Object other) =>
      other is MedicineStats &&
      other.adherence == adherence &&
      other.streak == streak &&
      other.takenToday == takenToday &&
      other.dueToday == dueToday &&
      listEquals(other.week, week) &&
      listEquals(other.history, history) &&
      other.nextDose == nextDose;

  @override
  int get hashCode => Object.hash(
    adherence,
    streak,
    takenToday,
    dueToday,
    Object.hashAll(week),
    Object.hashAll(history),
    nextDose,
  );
}

abstract final class MedicineStatsCalculator {
  /// How far back the streak looks (days).
  static const int streakLimit = 400;

  static MedicineStats compute(
    Medicine m,
    Iterable<DoseLog> logs,
    DateTime now,
  ) {
    final today = DateUtilsX.dateOnly(now);
    final byId = {for (final l in logs) l.id: l};
    List<DoseSlot> slots(DateTime day) =>
        MedicineSchedule.slotsOn(m, day, byId, ignorePause: true);

    // Adherence + history over the window.
    var taken = 0, counted = 0;
    final history = <DoseSlot>[];
    for (var i = 0; i < MedicineStats.windowDays; i++) {
      final day = DateUtilsX.addDays(today, -i);
      final daySlots = MedicineSchedule.dayPlan([m], day, byId.values);
      for (final s in daySlots.reversed) {
        final state = s.stateAt(now);
        if (state == DoseState.upcoming) continue;
        history.add(s);
        if (s.isAsNeeded) continue;
        if (state == DoseState.taken) taken++;
        if (state == DoseState.taken ||
            state == DoseState.skipped ||
            state == DoseState.missed) {
          counted++;
        }
      }
    }

    // Today.
    final todaySlots = slots(today);
    final takenToday = todaySlots
        .where((s) => s.stateAt(now) == DoseState.taken)
        .length;
    DoseSlot? next;
    for (final s in todaySlots) {
      if (!s.stateAt(now).isLogged) {
        next = s;
        break;
      }
    }

    // Streak.
    var streak = 0;
    final startNo = DateUtilsX.dayNumber(m.startDate);
    for (var i = 0; i < streakLimit; i++) {
      final day = DateUtilsX.addDays(today, -i);
      if (DateUtilsX.dayNumber(day) < startNo) break;
      final daySlots = slots(day);
      if (daySlots.isEmpty) continue;
      final states = [for (final s in daySlots) s.stateAt(now)];
      if (i == 0 && states.any((s) => !s.isLogged)) continue;
      if (states.contains(DoseState.missed)) break;
      if (!states.contains(DoseState.taken)) break;
      streak++;
    }

    // Week (oldest first).
    final week = [
      for (var i = 6; i >= 0; i--)
        () {
          final day = DateUtilsX.addDays(today, -i);
          return MedicineWeekDay(
            day: day,
            states: [for (final s in slots(day)) s.stateAt(now)],
          );
        }(),
    ];

    return MedicineStats(
      adherence: counted == 0 ? null : taken / counted,
      streak: streak,
      takenToday: takenToday,
      dueToday: todaySlots.length,
      week: week,
      history: List.unmodifiable(history),
      nextDose: next,
    );
  }
}
