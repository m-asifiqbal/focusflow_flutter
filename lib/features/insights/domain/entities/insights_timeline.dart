/// ============================================================
/// INSIGHTS TIMELINE — the rows of the Overview "Task timeline" (Gantt)
/// ============================================================
///
/// What: [TaskTimeline.build] turns the tasks due in a window into at most
/// [TaskTimeline.maxRows] Gantt rows: a bar runs from the day the task was
/// created to its due day (clamped to the window by the chart).
/// Which rows: overdue first, then open, then done (so a long window shows
/// what still needs attention), each group by due day; the chosen rows are
/// then ordered by start day like a project plan. [TaskTimeline.total]
/// counts every task in the window so the card can say "showing 8 of 23".
/// Why a pure function: the aggregator and the tests share it; the chart
/// widget only draws.
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/insights/domain/entities/insights_range.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';

enum TimelineState { overdue, open, done }

@immutable
class TimelineTask {
  const TimelineTask({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.state,
  });

  final String id;
  final String title;

  /// Created day and due day (local midnights, `start <= end`).
  final DateTime start;
  final DateTime end;
  final TimelineState state;

  @override
  bool operator ==(Object other) =>
      other is TimelineTask &&
      other.id == id &&
      other.title == title &&
      other.start == start &&
      other.end == end &&
      other.state == state;

  @override
  int get hashCode => Object.hash(id, title, start, end, state);
}

@immutable
class TaskTimeline {
  const TaskTimeline({this.rows = const [], this.total = 0});

  static const TaskTimeline empty = TaskTimeline();

  /// Rows the chart shows at most.
  static const int maxRows = 8;

  final List<TimelineTask> rows;

  /// Tasks due in the window (≥ rows.length).
  final int total;

  bool get isEmpty => rows.isEmpty;

  /// Tasks due in [window] that are active and dated, as of [today].
  static TaskTimeline build(
    List<TaskItem> tasks,
    InsightsWindow window,
    DateTime today,
  ) {
    final day = DateUtilsX.dateOnly(today);
    final all = <TimelineTask>[];
    for (final t in tasks) {
      final due = t.dueDate;
      if (due == null || !t.isActive || !window.contains(due)) continue;
      final end = DateUtilsX.dateOnly(due);
      final created = DateUtilsX.dateOnly(t.createdAt);
      all.add(
        TimelineTask(
          id: t.id,
          title: t.title,
          start: created.isAfter(end) ? end : created,
          end: end,
          state: t.isCompleted
              ? TimelineState.done
              : (end.isBefore(day)
                    ? TimelineState.overdue
                    : TimelineState.open),
        ),
      );
    }
    if (all.isEmpty) return empty;
    // Needs-attention first; stable within a group by due day, then title.
    all.sort((a, b) {
      final s = a.state.index.compareTo(b.state.index);
      if (s != 0) return s;
      final e = a.end.compareTo(b.end);
      return e != 0 ? e : a.title.compareTo(b.title);
    });
    final picked = all.take(maxRows).toList()
      ..sort((a, b) {
        final s = a.start.compareTo(b.start);
        if (s != 0) return s;
        final e = a.end.compareTo(b.end);
        return e != 0 ? e : a.title.compareTo(b.title);
      });
    return TaskTimeline(rows: List.unmodifiable(picked), total: all.length);
  }

  static const _eq = ListEquality<TimelineTask>();

  @override
  bool operator ==(Object other) =>
      other is TaskTimeline &&
      other.total == total &&
      _eq.equals(other.rows, rows);

  @override
  int get hashCode => Object.hash(total, _eq.hash(rows));
}
