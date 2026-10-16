/// ============================================================
/// TASK SECTIONS & STATS — how the Tasks list groups and counts
/// ============================================================
///
/// [TaskSections.build] is a pure function (unit tested) that splits a
/// task list into the smart sections of screen 10:
///   OVERDUE   open, due before today
///   TODAY     open, due today
///   UPCOMING  open, due after today
///   NO DATE   open, no due date ("Someday")
///   COMPLETED completed (newest completion first)
/// [TaskStats] are the four tappable tiles (Today / Overdue / Upcoming /
/// Done).
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';

@immutable
class TaskStats {
  const TaskStats({
    this.today = 0,
    this.overdue = 0,
    this.upcoming = 0,
    this.done = 0,
    this.noDate = 0,
    this.doneToday = 0,
    this.dueTodayTotal = 0,
  });

  static const empty = TaskStats();

  /// Open tasks due today.
  final int today;

  /// Open tasks due before today.
  final int overdue;

  /// Open tasks due after today.
  final int upcoming;

  /// Completed (active) tasks.
  final int done;

  /// Open tasks without a due date.
  final int noDate;

  /// Tasks completed today (Home "Tasks 4/7": [doneToday] / [dueTodayTotal]).
  final int doneToday;

  /// Tasks due today, open or completed.
  final int dueTodayTotal;

  @override
  bool operator ==(Object other) =>
      other is TaskStats &&
      other.today == today &&
      other.overdue == overdue &&
      other.upcoming == upcoming &&
      other.done == done &&
      other.noDate == noDate &&
      other.doneToday == doneToday &&
      other.dueTodayTotal == dueTodayTotal;

  @override
  int get hashCode => Object.hash(
    today,
    overdue,
    upcoming,
    done,
    noDate,
    doneToday,
    dueTodayTotal,
  );

  @override
  String toString() =>
      'TaskStats(today: $today, overdue: $overdue, upcoming: $upcoming, '
      'done: $done)';
}

@immutable
class TaskSections {
  const TaskSections({
    this.overdue = const [],
    this.today = const [],
    this.upcoming = const [],
    this.noDate = const [],
    this.completed = const [],
  });

  static const empty = TaskSections();

  final List<TaskItem> overdue;
  final List<TaskItem> today;
  final List<TaskItem> upcoming;
  final List<TaskItem> noDate;
  final List<TaskItem> completed;

  /// Open tasks (all sections except [completed]).
  int get openCount =>
      overdue.length + today.length + upcoming.length + noDate.length;
  int get totalCount => openCount + completed.length;
  bool get isEmpty => totalCount == 0;

  /// Sections in display order with their stable keys
  /// (`overdue`, `today`, `upcoming`, `noDate`, `completed`), skipping
  /// empty ones.
  List<(String, List<TaskItem>)> get nonEmpty => [
    if (overdue.isNotEmpty) ('overdue', overdue),
    if (today.isNotEmpty) ('today', today),
    if (upcoming.isNotEmpty) ('upcoming', upcoming),
    if (noDate.isNotEmpty) ('noDate', noDate),
    if (completed.isNotEmpty) ('completed', completed),
  ];

  /// Splits [tasks] relative to [now]'s day.
  ///
  /// Order inside open sections: [manual] → `sortOrder`; otherwise pinned
  /// first, then due date/time (all-day before timed on the same day),
  /// then priority (high first), then `sortOrder`. Completed: newest
  /// completion first.
  static TaskSections build(
    Iterable<TaskItem> tasks,
    DateTime now, {
    bool manual = false,
  }) {
    final today = DateUtilsX.dateOnly(now);
    final overdue = <TaskItem>[];
    final todays = <TaskItem>[];
    final upcoming = <TaskItem>[];
    final noDate = <TaskItem>[];
    final completed = <TaskItem>[];
    for (final t in tasks) {
      final due = t.dueDate;
      if (t.isCompleted) {
        completed.add(t);
      } else if (due == null) {
        noDate.add(t);
      } else if (due.isBefore(today)) {
        overdue.add(t);
      } else if (DateUtilsX.isSameDay(due, today)) {
        todays.add(t);
      } else {
        upcoming.add(t);
      }
    }
    final cmp = manual ? _manualOrder : _smartOrder;
    for (final list in [overdue, todays, upcoming, noDate]) {
      list.sort(cmp);
    }
    completed.sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    return TaskSections(
      overdue: List.unmodifiable(overdue),
      today: List.unmodifiable(todays),
      upcoming: List.unmodifiable(upcoming),
      noDate: List.unmodifiable(noDate),
      completed: List.unmodifiable(completed),
    );
  }

  /// Counts for the stat tiles, relative to [now]'s day.
  static TaskStats statsOf(Iterable<TaskItem> tasks, DateTime now) {
    final today = DateUtilsX.dateOnly(now);
    var t = 0, o = 0, u = 0, d = 0, n = 0, dt = 0, total = 0;
    for (final task in tasks) {
      final due = task.dueDate;
      final dueToday = due != null && DateUtilsX.isSameDay(due, today);
      if (dueToday) total++;
      if (task.isCompleted) {
        d++;
        if (DateUtilsX.isSameDay(task.completedAt!, today)) dt++;
      } else if (due == null) {
        n++;
      } else if (due.isBefore(today)) {
        o++;
      } else if (dueToday) {
        t++;
      } else {
        u++;
      }
    }
    return TaskStats(
      today: t,
      overdue: o,
      upcoming: u,
      done: d,
      noDate: n,
      doneToday: dt,
      dueTodayTotal: total,
    );
  }

  static int _manualOrder(TaskItem a, TaskItem b) {
    final c = a.sortOrder.compareTo(b.sortOrder);
    return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
  }

  static int _smartOrder(TaskItem a, TaskItem b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    final ad = a.dueDate, bd = b.dueDate;
    if (ad != null && bd != null) {
      final c = ad.compareTo(bd);
      if (c != 0) return c;
      final at = a.dueTimeMinutes ?? -1, bt = b.dueTimeMinutes ?? -1;
      if (at != bt) return at.compareTo(bt);
    }
    if (a.priority != b.priority) {
      return b.priority.index.compareTo(a.priority.index);
    }
    return _manualOrder(a, b);
  }

  static const _eq = ListEquality<TaskItem>();

  @override
  bool operator ==(Object other) =>
      other is TaskSections &&
      _eq.equals(other.overdue, overdue) &&
      _eq.equals(other.today, today) &&
      _eq.equals(other.upcoming, upcoming) &&
      _eq.equals(other.noDate, noDate) &&
      _eq.equals(other.completed, completed);

  @override
  int get hashCode => Object.hash(
    _eq.hash(overdue),
    _eq.hash(today),
    _eq.hash(upcoming),
    _eq.hash(noDate),
    _eq.hash(completed),
  );
}
