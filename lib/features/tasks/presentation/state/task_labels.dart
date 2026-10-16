/// ============================================================
/// TASK LABELS — the human strings of the tasks screens (10, 11)
/// ============================================================
///
/// What: pure functions turning task values into the copy shown on rows,
/// section headers and editor rows ("Yesterday", "09:00 AM",
/// "15 min before", "OVERDUE").
/// Why: rows, the editor, the actions sheet and tests must agree on the
/// same wording, so it lives in one place instead of in widgets.
/// ============================================================
library;

import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:intl/intl.dart';

abstract final class TaskLabels {
  /// "Remind me" choices in minutes before the task (0 = at the time).
  static const List<int> remindOptions = [0, 5, 10, 15, 30, 60, 120, 1440];

  /// "15 min before", "1 hour before", "At time of task", "None".
  static String remindOffset(int? minutes) {
    if (minutes == null) return 'None';
    if (minutes == 0) return 'At time of task';
    if (minutes < 60) return '$minutes min before';
    if (minutes % 1440 == 0) {
      final d = minutes ~/ 1440;
      return d == 1 ? '1 day before' : '$d days before';
    }
    if (minutes % 60 == 0) {
      final h = minutes ~/ 60;
      return h == 1 ? '1 hour before' : '$h hours before';
    }
    return '$minutes min before';
  }

  /// Editor date value: "Tue, Jun 13" (year added when not this year).
  static String editorDate(DateTime? day, DateTime now) {
    if (day == null) return 'No date';
    return day.year == now.year
        ? DateFormat('EEE, MMM d').format(day)
        : DateFormat('EEE, MMM d, y').format(day);
  }

  /// Editor time value: "09:00 AM" or "All day".
  static String editorTime(int? minutes, {bool use24h = false}) =>
      minutes == null
      ? 'All day'
      : DateUtilsX.minutesToTime(minutes, use24h: use24h);

  /// The date/time part of a task row's meta line:
  /// overdue → "Yesterday"; today → "09:00 AM" (or "Today");
  /// upcoming → "Tomorrow · 09:00 AM"; no date → null.
  static String? rowDue(TaskItem t, DateTime now, {bool use24h = false}) {
    final due = t.dueDate;
    if (due == null) return null;
    final time = t.dueTimeMinutes == null
        ? null
        : DateUtilsX.minutesToTime(t.dueTimeMinutes!, use24h: use24h);
    final today = DateUtilsX.isSameDay(due, now);
    if (today) return time ?? 'Today';
    final day = DateUtilsX.relativeDay(due, now);
    if (t.isOverdue(now) || time == null) return day;
    return '$day · $time';
  }

  /// Whether the row's due label shows a clock (timed, due today or done
  /// today) rather than a calendar icon.
  static bool rowDueIsTime(TaskItem t, DateTime now) =>
      t.dueTimeMinutes != null &&
      t.dueDate != null &&
      DateUtilsX.isSameDay(t.dueDate!, now);

  /// Section header for a [TaskSections] key.
  static String section(String key) => switch (key) {
    'overdue' => 'Overdue',
    'today' => 'Today',
    'upcoming' => 'Upcoming',
    'noDate' => 'No date',
    'completed' => 'Completed',
    _ => key,
  };

  /// Header subtitle: "7 due today · 2 overdue" / "All clear for today".
  static String headerSubtitle({required int dueToday, required int overdue}) {
    final parts = [
      if (dueToday > 0) '$dueToday due today',
      if (overdue > 0) '$overdue overdue',
    ];
    return parts.isEmpty ? 'All clear for today' : parts.join(' · ');
  }

  /// Screen-reader description of a task row.
  static String semantics(TaskItem t, DateTime now, {bool use24h = false}) {
    final due = rowDue(t, now, use24h: use24h);
    return [
      t.title,
      if (t.isCompleted) 'completed',
      if (t.isOverdue(now)) 'overdue',
      ?due,
      if (t.priority != TaskPriority.none) '${t.priority.label} priority',
      if (t.subtasks.isNotEmpty)
        '${t.subtaskDone} of ${t.subtaskTotal} subtasks',
      if (t.isRepeating) 'repeats ${t.repeatLabel}',
      if (t.hasReminder) 'reminder set',
    ].join(', ');
  }
}
