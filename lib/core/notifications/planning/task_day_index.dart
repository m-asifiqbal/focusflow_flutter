/// ============================================================
/// TASK DAY INDEX — overdue / due-today counts in O(log n)
/// ============================================================
///
/// The planner needs, for many different days, "how many open tasks are
/// overdue then / due that day" (the app-icon badge predicted for every
/// notification, the overdue summary, the digests' counts).
///
/// Answering each question by scanning every task — and sorting the matches
/// by building a `DateTime` per comparison — cost O(notifications × tasks)
/// with a time-zone lookup in the inner loop: seconds of CPU for a few
/// hundred tasks, on the UI isolate, at every launch and after every edit.
///
/// This index sorts the open, dated tasks once by (due day, due time) over
/// plain integer day numbers ([DateUtilsX.dayNumber]); each question is then
/// a binary search. Same definitions as before: *open* = active and not
/// completed; a task is *overdue on* a day when its due day is before it
/// (day-based, like the Tasks list) and *due on* a day when it is that day.
/// ============================================================
library;

import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';

class TaskDayIndex {
  TaskDayIndex(Iterable<TaskItem> tasks) : this._(_sorted(tasks));

  TaskDayIndex._(_Sorted s) : _days = s.days, _tasks = s.tasks;

  /// Due day numbers, ascending; [_tasks] in the same order.
  final List<int> _days;
  final List<TaskItem> _tasks;

  static _Sorted _sorted(Iterable<TaskItem> tasks) {
    final entries = <_Entry>[];
    var order = 0;
    for (final t in tasks) {
      final due = t.dueDate;
      if (due == null || !t.isActive || t.isCompleted) continue;
      entries.add(
        _Entry(DateUtilsX.dayNumber(due), t.dueTimeMinutes ?? 0, order++, t),
      );
    }
    entries.sort();
    return _Sorted(
      [for (final e in entries) e.day],
      [for (final e in entries) e.task],
    );
  }

  /// First position whose day is ≥ [day].
  int _lower(int day) {
    var lo = 0;
    var hi = _days.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_days[mid] < day) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// First position whose day is > [day].
  int _upper(int day) {
    var lo = 0;
    var hi = _days.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_days[mid] <= day) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Open tasks due before [day] (a [DateUtilsX.dayNumber]), oldest first
  /// (by due day, then time, then the order they were given in).
  List<TaskItem> overdueOn(int day) => _tasks.sublist(0, _lower(day));

  /// Open tasks due on [day], by time.
  List<TaskItem> dueOn(int day) => _tasks.sublist(_lower(day), _upper(day));

  /// How many open tasks are overdue on [day].
  int overdueCount(int day) => _lower(day);

  /// How many open tasks are due on [day].
  int dueCount(int day) => _upper(day) - _lower(day);

  /// App icon badge on [day] for [mode] (null = no badge): overdue count,
  /// or overdue + due that day.
  int? badgeOn(int day, BadgeMode mode) => switch (mode) {
    BadgeMode.none => null,
    BadgeMode.overdue => overdueCount(day),
    BadgeMode.today => _upper(day),
  };
}

class _Sorted {
  const _Sorted(this.days, this.tasks);

  final List<int> days;
  final List<TaskItem> tasks;
}

class _Entry implements Comparable<_Entry> {
  const _Entry(this.day, this.minutes, this.order, this.task);

  final int day;
  final int minutes;
  final int order;
  final TaskItem task;

  @override
  int compareTo(_Entry other) {
    if (day != other.day) return day < other.day ? -1 : 1;
    if (minutes != other.minutes) return minutes < other.minutes ? -1 : 1;
    return order - other.order;
  }
}
