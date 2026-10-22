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

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';

abstract final class TaskLabels {
  /// "Remind me" choices in minutes before the task (0 = at the time).
  static const List<int> remindOptions = [0, 5, 10, 15, 30, 60, 120, 1440];

  /// "15 min before", "1 hour before", "At time of task", "None".
  static String remindOffset(int? minutes) {
    if (minutes == null) return tr('None');
    if (minutes == 0) return tr('At time of task');
    if (minutes < 60) return tr('{m} min before', {'m': minutes});
    if (minutes % 1440 == 0) {
      return tr('{count, plural, one {# day before} other {# days before}}', {
        'count': minutes ~/ 1440,
      });
    }
    if (minutes % 60 == 0) {
      return tr('{count, plural, one {# hour before} other {# hours before}}', {
        'count': minutes ~/ 60,
      });
    }
    return tr('{m} min before', {'m': minutes});
  }

  /// Editor date value: "Tue, Jun 13" (year added when not this year).
  static String editorDate(DateTime? day, DateTime now) {
    if (day == null) return tr('No date');
    return day.year == now.year
        ? DateFormats.of('EEE, MMM d').format(day)
        : DateFormats.of('EEE, MMM d, y').format(day);
  }

  /// Editor time value: "09:00 AM" or "All day".
  static String editorTime(int? minutes, {bool use24h = false}) =>
      minutes == null
      ? tr('All day')
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
    if (today) return time ?? tr('Today');
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
    'overdue' => tr('Overdue'),
    'today' => tr('Today'),
    'upcoming' => tr('Upcoming'),
    'noDate' => tr('No date'),
    'completed' => tr('Completed'),
    _ => key,
  };

  /// Header subtitle: "7 due today · 2 overdue" / "All clear for today".
  static String headerSubtitle({required int dueToday, required int overdue}) {
    final parts = [
      if (dueToday > 0) tr('{n} due today', {'n': dueToday}),
      if (overdue > 0) tr('{n} overdue', {'n': overdue}),
    ];
    return parts.isEmpty ? tr('All clear for today') : parts.join(' · ');
  }

  /// Screen-reader description of a task row.
  static String semantics(TaskItem t, DateTime now, {bool use24h = false}) {
    final due = rowDue(t, now, use24h: use24h);
    return [
      t.title,
      if (t.isCompleted) tr('completed'),
      if (t.isOverdue(now)) tr('overdue'),
      ?due,
      if (t.priority != TaskPriority.none)
        tr('{label} priority', {'label': t.priority.label}),
      if (t.subtasks.isNotEmpty)
        tr('{done} of {total} subtasks', {
          'done': t.subtaskDone,
          'total': t.subtaskTotal,
        }),
      if (t.isRepeating) tr('repeats {rule}', {'rule': t.repeatLabel}),
      if (t.hasReminder) tr('reminder set'),
    ].join(', ');
  }
}
