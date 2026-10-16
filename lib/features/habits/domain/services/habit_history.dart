/// ============================================================
/// HABIT HISTORY — the "History" list of the habit detail screen (16)
/// ============================================================
///
/// Turns a habit's logs into newest-first entries ("Today · 6 of 8 glasses
/// · 75%", "Yesterday · Goal reached", "Sun, Jun 11 · Skipped"). Pure, so
/// the screen only formats text. Rules:
///   • only days from the start date up to [today] are listed;
///   • a log that records nothing (count 0, not skipped, no note) is
///     dropped — it is what "Clear" leaves behind in older data;
///   • quit habits list slips, skipped days and notes (clean days without
///     a note have no log and are not listed).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/habit_schedule.dart';

enum HabitHistoryKind {
  /// Build habit: goal reached. Quit habit: clean day with a note.
  done,

  /// Build habit: some check-ins, goal not reached (or only a note).
  partial,

  /// Deliberate rest day.
  skipped,

  /// Quit habit: a slip was logged.
  slip,
}

@immutable
class HabitHistoryEntry {
  const HabitHistoryEntry({
    required this.log,
    required this.kind,
    required this.progress,
  });

  final HabitLog log;
  final HabitHistoryKind kind;

  /// 0…1 (see HabitSchedule.progress).
  final double progress;

  DateTime get day => log.date;
  String? get note => log.note;

  @override
  bool operator ==(Object other) =>
      other is HabitHistoryEntry &&
      other.log == log &&
      other.kind == kind &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(log, kind, progress);
}

abstract final class HabitHistory {
  /// Newest-first history of [habit] up to [today] (at most [limit]).
  static List<HabitHistoryEntry> entries(
    Habit habit,
    Iterable<HabitLog> logs,
    DateTime today, {
    int? limit,
  }) {
    final sorted =
        logs
            .where(
              (l) =>
                  HabitSchedule.daysBetween(l.date, today) >= 0 &&
                  HabitSchedule.daysBetween(habit.startDate, l.date) >= 0,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final result = <HabitHistoryEntry>[];
    for (final log in sorted) {
      final entry = _entry(habit, log);
      if (entry == null) continue;
      result.add(entry);
      if (limit != null && result.length >= limit) break;
    }
    return result;
  }

  static HabitHistoryEntry? _entry(Habit habit, HabitLog log) {
    final hasNote = (log.note ?? '').trim().isNotEmpty;
    final progress = HabitSchedule.progress(habit, log);
    final HabitHistoryKind kind;
    if (log.skipped) {
      kind = HabitHistoryKind.skipped;
    } else if (habit.isQuit) {
      if (log.count > 0) {
        kind = HabitHistoryKind.slip;
      } else if (hasNote) {
        kind = HabitHistoryKind.done;
      } else {
        return null;
      }
    } else if (log.count >= habit.targetCount) {
      kind = HabitHistoryKind.done;
    } else if (log.count > 0 || hasNote) {
      kind = HabitHistoryKind.partial;
    } else {
      return null;
    }
    return HabitHistoryEntry(log: log, kind: kind, progress: progress);
  }
}
