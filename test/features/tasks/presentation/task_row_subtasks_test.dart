/// A task row lists its subtasks, each with its own check circle; a done
/// task shows them all ticked; selection mode makes them read-only.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/presentation/widgets/task_row.dart';

void main() {
  final now = DateTime(2026, 6, 13, 9);

  TaskItem task({int subtasks = 3, DateTime? completedAt}) => TaskItem(
    id: 't1',
    title: 'Trip',
    completedAt: completedAt,
    subtasks: [
      for (var i = 0; i < subtasks; i++)
        Subtask(id: 's$i', title: 'Step $i', done: i == 0, sortOrder: i * 1.0),
    ],
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pump(
    WidgetTester tester,
    TaskItem t, {
    ValueChanged<Subtask>? onSubtask,
    bool selection = false,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(AccentColor.emerald),
      home: Scaffold(
        body: SingleChildScrollView(
          child: TaskRow(
            task: t,
            now: now,
            onTap: () {},
            onCheck: (_) {},
            onSubtaskToggle: onSubtask,
            selectionMode: selection,
          ),
        ),
      ),
    ),
  );

  testWidgets('every subtask is listed and tapping its check toggles it', (
    tester,
  ) async {
    final toggled = <String>[];
    await pump(tester, task(), onSubtask: (s) => toggled.add(s.id));

    for (var i = 0; i < 3; i++) {
      expect(find.text('Step $i'), findsOneWidget);
    }
    await tester.tap(find.bySemanticsLabel('Complete subtask Step 1'));
    await tester.pump();
    expect(toggled, ['s1']);
    // A done subtask offers to un-tick.
    expect(find.bySemanticsLabel('Mark subtask Step 0 as not done'), findsOne);
  });

  testWidgets('a completed task shows all its subtasks ticked', (tester) async {
    await pump(tester, task(completedAt: now), onSubtask: (_) {});
    expect(find.bySemanticsLabel('Mark subtask Step 1 as not done'), findsOne);
    expect(find.bySemanticsLabel('Mark subtask Step 2 as not done'), findsOne);
    expect(find.bySemanticsLabel('Complete subtask Step 1'), findsNothing);
  });

  testWidgets('selection mode: subtasks are read-only', (tester) async {
    final toggled = <String>[];
    await pump(
      tester,
      task(),
      selection: true,
      onSubtask: (s) => toggled.add(s.id),
    );
    await tester.tap(find.bySemanticsLabel('Complete subtask Step 1'));
    await tester.pump();
    expect(toggled, isEmpty);
  });

  testWidgets('more than five subtasks: the rest is "+ n more"', (
    tester,
  ) async {
    await pump(tester, task(subtasks: 8), onSubtask: (_) {});
    expect(find.text('Step 4'), findsOneWidget);
    expect(find.text('Step 5'), findsNothing);
    expect(find.text('+ 3 more'), findsOneWidget);
  });
}
