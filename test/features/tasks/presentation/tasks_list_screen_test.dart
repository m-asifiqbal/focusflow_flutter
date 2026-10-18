/// Tasks list (screen 10): mockup-like data renders in sections, stat
/// tiles filter, checking a task completes it with Undo, "Reschedule all"
/// moves overdue tasks, empty state, and no overflow at 360 pt / 1.3×.
/// Captures build/screens/10_tasks_list{,_dark}.png for the mockup check.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/widgets/ff_stat_tile.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';
import 'package:focusflow/features/tasks/presentation/screens/tasks_list_screen.dart';
import 'package:focusflow/features/tasks/presentation/widgets/task_row.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../../reminders/isolated_notifications.dart';

final _now = DateTime(2026, 6, 13, 9, 41);

TaskItem _task(
  String title, {
  DateTime? due,
  int? time,
  TaskPriority priority = TaskPriority.none,
  String? listId,
  List<String> tags = const [],
  String? rrule,
  int? remind,
  List<Subtask> subtasks = const [],
}) => TaskItem(
  id: '',
  title: title,
  dueDate: due,
  dueTimeMinutes: time,
  priority: priority,
  listId: listId,
  tags: [for (final t in tags) Tag(id: '', name: t)],
  repeatRule: rrule,
  remindOffsetMinutes: remind,
  subtasks: subtasks,
  createdAt: _now,
  updatedAt: _now,
);

/// Seeds the tasks of design/10_tasks_list.png. Returns the repository.
Future<TasksRepository> seedMockup(TestHarness h) async {
  final tasks = h.read(tasksRepositoryProvider);
  final folders = h.read(foldersRepositoryProvider);
  final work = await folders.create(ItemType.task, 'Work', iconKey: 'work');
  await folders.create(ItemType.task, 'Personal', iconKey: 'personal');
  final yesterday = DateTime(2026, 6, 12);
  final today = DateTime(2026, 6, 13);
  await tasks.save(
    _task(
      'Submit tax documents',
      due: yesterday,
      priority: TaskPriority.high,
      tags: ['finance'],
    ),
  );
  await tasks.save(_task('Renew gym membership', due: yesterday));
  await tasks.save(
    _task(
      'Review FocusFlow Q3 Strategy',
      due: today,
      time: 9 * 60,
      priority: TaskPriority.high,
      listId: work,
      rrule: 'FREQ=WEEKLY',
      subtasks: [
        const Subtask.draft('Outline', done: true),
        const Subtask.draft('Numbers', done: true),
        const Subtask.draft('Risks'),
        const Subtask.draft('Roadmap'),
        const Subtask.draft('Slides'),
      ],
    ),
  );
  await tasks.save(
    _task(
      'Design Home Screen v2',
      due: today,
      time: 11 * 60 + 30,
      priority: TaskPriority.medium,
      tags: ['design'],
      remind: 15,
    ),
  );
  await tasks.save(
    _task(
      'Team Meeting — Sprint review',
      due: today,
      time: 14 * 60,
      priority: TaskPriority.low,
      listId: work,
    ),
  );
  final run = await tasks.save(
    _task('Morning run 5 km', due: today, time: 7 * 60),
  );
  await tasks.complete(run);
  for (var i = 1; i <= 3; i++) {
    await tasks.save(_task('Upcoming $i', due: DateTime(2026, 6, 13 + i)));
  }
  return tasks;
}

Future<TestHarness> _harness(WidgetTester tester, {bool seed = true}) async {
  // The mockups' status bar and home indicator.
  tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  addTearDown(tester.view.resetPadding);
  final h = (await tester.runAsync(
    () => TestHarness.create(now: _now, overrides: isolatedNotifications()),
  ))!;
  addTearDown(() => tester.runAsync(h.dispose));
  if (seed) await tester.runAsync(() => seedMockup(h));
  return h;
}

void main() {
  testWidgets('renders the mockup sections (light + dark captures)', (
    tester,
  ) async {
    await loadAppFonts();
    final h = await _harness(tester);
    await pumpApp(tester, h, AppRoutes.tasks);

    expect(find.byType(TasksListScreen), findsOneWidget);
    expect(find.text('Tasks'), findsWidgets);
    expect(find.text('3 due today · 2 overdue'), findsOneWidget);
    expect(find.text('OVERDUE · 2'), findsOneWidget);
    expect(find.text('Reschedule all'), findsOneWidget);
    expect(find.text('TODAY · 3'), findsOneWidget);
    expect(find.text('Submit tax documents'), findsOneWidget);
    expect(find.text('Yesterday'), findsNWidgets(2));
    expect(find.text('2/5 subtasks'), findsOneWidget);
    expect(find.text('WORK'), findsWidgets);
    await captureScreen(tester, '10_tasks_list');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await settle(tester);
    expect(find.text('COMPLETED · 1'), findsOneWidget);
    await captureScreen(tester, '10_tasks_list_scrolled');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
    await settle(tester);

    await pumpApp(tester, h, AppRoutes.tasks, dark: true);
    await captureScreen(tester, '10_tasks_list_dark');
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    await loadAppFonts();
    final h = await _harness(tester);
    await pumpApp(
      tester,
      h,
      AppRoutes.tasks,
      size: const Size(360, 800),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    // All four stat labels share one scale (no single label shrunk alone).
    double labelHeight(String label) => tester
        .getRect(
          find.descendant(
            of: find.byType(FFStatTile),
            matching: find.text(label),
          ),
        )
        .height;
    final today = labelHeight('Today');
    for (final label in ['Overdue', 'Upcoming', 'Done']) {
      expect(labelHeight(label), moreOrLessEquals(today, epsilon: 0.5));
    }
    await captureScreen(tester, '10_tasks_list_360_x13');
  });

  testWidgets('stat tile filters the list', (tester) async {
    final h = await _harness(tester);
    await pumpApp(tester, h, AppRoutes.tasks);
    await tester.tap(find.bySemanticsLabel('2 Overdue'));
    await settle(tester);
    expect(find.text('OVERDUE · 2'), findsOneWidget);
    expect(find.textContaining('TODAY ·'), findsNothing);
  });

  testWidgets('checking a task completes it after the delay, with Undo', (
    tester,
  ) async {
    final h = await _harness(tester);
    final tasks = h.read(tasksRepositoryProvider);
    await pumpApp(tester, h, AppRoutes.tasks);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await settle(tester);

    await tester.tap(find.bySemanticsLabel('Complete Design Home Screen v2'));
    await tester.pump();
    expect(find.text('"Design Home Screen v2" completed'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1300));
    await settle(tester);
    expect(find.text('COMPLETED · 2'), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await settle(tester);
    expect(find.text('COMPLETED · 1'), findsOneWidget);
    final open = await tester.runAsync(
      () => tasks.watchTasks(const TasksQuery(scope: TasksScope.today)).first,
    );
    expect(
      open!.firstWhere((t) => t.title == 'Design Home Screen v2').isCompleted,
      isFalse,
    );
  });

  testWidgets('ticking the last open subtask completes the task, with Undo', (
    tester,
  ) async {
    final h = await _harness(tester);
    final tasks = h.read(tasksRepositoryProvider);
    await pumpApp(tester, h, AppRoutes.tasks);
    const title = 'Review FocusFlow Q3 Strategy'; // 2 of 5 subtasks done

    for (final step in ['Risks', 'Roadmap']) {
      final check = find.bySemanticsLabel('Complete subtask $step');
      await tester.ensureVisible(check);
      await tester.pump(); // lay out at the new scroll offset before tapping
      await tester.tap(check);
      await settle(tester);
    }
    // Not the last one yet: the task is still open.
    expect(find.bySemanticsLabel('Complete $title'), findsOneWidget);
    expect(find.text('"$title" completed'), findsNothing);

    final last = find.bySemanticsLabel('Complete subtask Slides');
    await tester.ensureVisible(last);
    await tester.pump();
    await tester.tap(last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // The task shows done at once and says so, like a tap on its own check.
    expect(find.bySemanticsLabel('Mark $title as not done'), findsOneWidget);
    expect(find.text('"$title" completed'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1300));
    await settle(tester);
    final done = await tester.runAsync(
      () => tasks.watchTasks(const TasksQuery(scope: TasksScope.all)).first,
    );
    expect(
      done!
          .firstWhere((t) => t.title == title && t.isCompleted)
          .subtasks
          .map((s) => s.done),
      everyElement(isTrue),
    );

    // Undo takes the last subtask back with the completion.
    await tester.tap(find.text('UNDO'));
    await settle(tester);
    final reopened = await tester.runAsync(
      () => tasks.watchTasks(const TasksQuery(scope: TasksScope.all)).first,
    );
    final task = reopened!.singleWhere((t) => t.title == title && t.isActive);
    expect(task.isCompleted, isFalse);
    expect(task.subtasks.map((s) => s.title), [
      'Outline',
      'Numbers',
      'Risks',
      'Roadmap',
      'Slides',
    ]);
    expect(task.subtasks.map((s) => s.done), [true, true, true, true, false]);
  });

  testWidgets('"Reschedule all" moves overdue tasks to today', (tester) async {
    final h = await _harness(tester);
    await pumpApp(tester, h, AppRoutes.tasks);
    await tester.tap(find.text('Reschedule all'));
    await settle(tester);
    expect(find.text('Next week'), findsOneWidget);
    await tester.tap(find.text('Today').last);
    await settle(tester);
    expect(find.textContaining('OVERDUE'), findsNothing);
    expect(find.text('TODAY · 5'), findsOneWidget);
    expect(find.text('2 tasks rescheduled'), findsOneWidget);
  });

  testWidgets('long-press opens the actions sheet with task rows', (
    tester,
  ) async {
    final h = await _harness(tester);
    await pumpApp(tester, h, AppRoutes.tasks);
    await tester.longPress(find.text('Submit tax documents'));
    await settle(tester);
    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('Change due date'), findsOneWidget);
    expect(find.text('Priority'), findsOneWidget);
  });

  testWidgets('multi-select from the menu completes selected tasks', (
    tester,
  ) async {
    await loadAppFonts();
    final h = await _harness(tester);
    await pumpApp(tester, h, AppRoutes.tasks, size: const Size(360, 800));
    await tester.tap(find.bySemanticsLabel('More options'));
    await settle(tester);
    await tester.tap(find.text('Select tasks'));
    await settle(tester);
    expect(find.text('Select tasks'), findsOneWidget);
    await tester.tap(find.text('Submit tax documents'));
    await tester.tap(find.text('Renew gym membership'));
    await settle(tester);
    expect(find.text('2 selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '10_tasks_list_selecting');
    await tester.tap(find.bySemanticsLabel('Complete selected tasks'));
    await settle(tester);
    expect(find.text('2 tasks completed'), findsOneWidget);
    expect(find.textContaining('OVERDUE'), findsNothing);
    expect(find.text('Tasks'), findsWidgets);
  });

  testWidgets('board view shows the three columns', (tester) async {
    final h = await _harness(tester);
    await pumpApp(tester, h, AppRoutes.tasks);
    await tester.tap(find.bySemanticsLabel('Show as board'));
    await settle(tester);
    expect(find.text('TO DO · 5'), findsOneWidget);
    expect(find.text('DOING · 0'), findsOneWidget);
    await tester.tap(find.text('Start').first);
    await settle(tester);
    expect(find.text('DOING · 1'), findsOneWidget);
  });

  testWidgets('empty state without tasks', (tester) async {
    await loadAppFonts();
    final h = await _harness(tester, seed: false);
    await pumpApp(tester, h, AppRoutes.tasks);
    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.text('Add a task'), findsOneWidget);
    await captureScreen(tester, '10_tasks_list_empty');
  });

  testWidgets('drag handle: 44 pt hit area, Move up / Move down actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final h = await _harness(tester);
    await pumpApp(tester, h, AppRoutes.tasks);
    expect(
      tester.getSize(find.byType(TaskDragHandle).first),
      const Size(AppSizes.minTap, AppSizes.minTap),
    );

    // The first handle whose row can move down.
    final handles = find.bySemanticsLabel(RegExp('^Reorder '));
    late SemanticsNode node;
    late CustomSemanticsAction down;
    for (var i = 0; i < handles.evaluate().length; i++) {
      final n = tester.getSemantics(handles.at(i));
      final ids = n.getSemanticsData().customSemanticsActionIds ?? const [];
      final labels = [
        for (final id in ids) CustomSemanticsAction.getAction(id)!.label,
      ];
      if (labels.contains('Move down')) {
        node = n;
        down = CustomSemanticsAction.getAction(
          ids[labels.indexOf('Move down')],
        )!;
        break;
      }
    }
    final title = node.getSemanticsData().label.substring('Reorder '.length);
    node.owner!.performAction(
      node.id,
      SemanticsAction.customAction,
      CustomSemanticsAction.getIdentifier(down),
    );
    await settle(tester);

    final sections = (await tester.runAsync(
      () => h
          .read(tasksRepositoryProvider)
          .watchSections(TasksQuery(day: DateTime(2026, 6, 13)), manual: true)
          .first,
    ))!;
    final section = sections.nonEmpty
        .map((e) => e.$2.map((t) => t.title).toList())
        .firstWhere((titles) => titles.contains(title));
    expect(section.indexOf(title), 1);
    semantics.dispose();
  });
}
