/// Overview › Task timeline rows: which tasks are listed, their span and
/// state, the row cap and ordering, and that the snapshot carries it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/insights/domain/entities/insights_range.dart';
import 'package:focusflow/features/insights/domain/entities/insights_timeline.dart';
import 'package:focusflow/features/insights/domain/services/insights_aggregator.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';

final _today = DateTime(2026, 10, 15);
final _window = InsightsRange.initial.resolve(_today); // Oct 9 – Oct 15

TaskItem _task(
  String id, {
  DateTime? due,
  DateTime? created,
  DateTime? done,
  DateTime? archived,
}) => TaskItem(
  id: id,
  title: 'Task $id',
  dueDate: due,
  completedAt: done,
  archivedAt: archived,
  createdAt: created ?? DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

void main() {
  test('lists active dated tasks due in the window, with state and span', () {
    final t = TaskTimeline.build(
      [
        _task('open', due: _today, created: DateTime(2026, 10, 10)),
        _task(
          'late',
          due: DateTime(2026, 10, 12),
          created: DateTime(2026, 10, 3),
        ),
        _task(
          'done',
          due: DateTime(2026, 10, 11),
          created: DateTime(2026, 10, 9),
          done: DateTime(2026, 10, 10),
        ),
        _task('undated'),
        _task('outside', due: DateTime(2026, 10, 20)),
        _task(
          'archived',
          due: DateTime(2026, 10, 12),
          archived: DateTime(2026, 10, 13),
        ),
      ],
      _window,
      _today,
    );

    expect(t.total, 3);
    expect(t.rows.map((r) => r.id), ['late', 'done', 'open']);
    final byId = {for (final r in t.rows) r.id: r};
    expect(byId['late']!.state, TimelineState.overdue);
    expect(byId['late']!.start, DateTime(2026, 10, 3));
    expect(byId['late']!.end, DateTime(2026, 10, 12));
    expect(byId['done']!.state, TimelineState.done);
    // Due today is not overdue yet.
    expect(byId['open']!.state, TimelineState.open);
  });

  test('a task created after its due day starts on the due day', () {
    final t = TaskTimeline.build(
      [
        _task(
          'x',
          due: DateTime(2026, 10, 10),
          created: DateTime(2026, 10, 14),
        ),
      ],
      _window,
      _today,
    );
    expect(t.rows.single.start, DateTime(2026, 10, 10));
    expect(t.rows.single.end, DateTime(2026, 10, 10));
  });

  test('caps the rows: needs-attention first, then by start day', () {
    final tasks = [
      for (var i = 0; i < 6; i++)
        _task(
          'done$i',
          due: DateTime(2026, 10, 10),
          done: DateTime(2026, 10, 10),
        ),
      for (var i = 0; i < 4; i++)
        _task(
          'late$i',
          due: DateTime(2026, 10, 11),
          created: DateTime(2026, 10, 5 + i),
        ),
    ];
    final t = TaskTimeline.build(tasks, _window, _today);
    expect(t.total, 10);
    expect(t.rows, hasLength(TaskTimeline.maxRows));
    // All four overdue tasks made it; the rest are done ones.
    expect(t.rows.where((r) => r.state == TimelineState.overdue), hasLength(4));
    final starts = t.rows.map((r) => r.start).toList();
    expect(starts, [...starts]..sort());
  });

  test('empty window gives the empty timeline', () {
    expect(TaskTimeline.build(const [], _window, _today), TaskTimeline.empty);
    expect(TaskTimeline.empty.isEmpty, isTrue);
  });

  test('the aggregator puts the timeline in the snapshot', () {
    const agg = InsightsAggregator();
    final s = agg.compute(
      InsightsSources(tasksDue: [_task('a', due: DateTime(2026, 10, 12))]),
      _window,
      _today,
    );
    expect(s.timeline.rows.single.id, 'a');
    expect(s.timeline.total, 1);
  });
}
