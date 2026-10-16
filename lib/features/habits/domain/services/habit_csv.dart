/// ============================================================
/// HABIT CSV — "Export CSV" of one habit's history (detail › More)
/// ============================================================
///
/// One row per logged day, oldest first:
///   `date,count,target,unit,done,skipped,note`
/// Fields are RFC 4180 quoted when they contain a comma, quote or line
/// break, so notes survive spreadsheet imports. Pure — the screen hands
/// the text to the OS share sheet.
/// ============================================================
library;

import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/habit_schedule.dart';

abstract final class HabitCsv {
  static const String header = 'date,count,target,unit,done,skipped,note';

  /// The CSV text for [habit] and its [logs] (any order).
  static String export(Habit habit, Iterable<HabitLog> logs) {
    final sorted = logs.toList()..sort((a, b) => a.date.compareTo(b.date));
    final lines = <String>[header];
    for (final log in sorted) {
      lines.add(
        [
          log.dayKey,
          '${log.count}',
          '${habit.targetCount}',
          escape(habit.unit),
          HabitSchedule.isDone(habit, log) ? 'yes' : 'no',
          log.skipped ? 'yes' : 'no',
          escape(log.note ?? ''),
        ].join(','),
      );
    }
    return '${lines.join('\n')}\n';
  }

  /// Quotes [value] when needed (RFC 4180). A value a spreadsheet would
  /// run as a formula (starting with = + - @, or a tab / CR) gets a leading
  /// apostrophe first, so an exported note can't inject a formula.
  static String escape(String value) {
    final safe = value.startsWith(RegExp('[=+\\-@\t\r]')) ? "'$value" : value;
    if (!safe.contains(RegExp('[,"\n\r]'))) return safe;
    return '"${safe.replaceAll('"', '""')}"';
  }

  /// A file-system friendly name: "drink-water-history.csv".
  static String fileName(Habit habit) {
    final slug = habit.name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '${slug.isEmpty ? 'habit' : slug}-history.csv';
  }
}
