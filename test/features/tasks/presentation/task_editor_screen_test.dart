/// Task editor (screen 11): the mockup task renders in every section
/// (light + dark captures), Save is gated on a title, prefill from
/// `/tasks/new?...`, saving writes subtasks + reminder, Cancel asks to
/// discard, Archive / Delete go through the lifecycle helpers, and no
/// overflow at 360 pt / 1.3×.
/// Captures build/screens/11_task_editor{,_dark,_new,_360_x13}.png.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';
import 'package:focusflow/features/tasks/presentation/screens/task_editor_screen.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../../reminders/isolated_notifications.dart';

final _now = DateTime(2026, 6, 13, 9, 41);

/// The mockup is one tall scrolled frame (390 × 1168 pt).
const _tall = Size(390, 1168);

/// Seeds the task of design/11_task_editor.png; returns its id.
Future<String> _seedMockup(TestHarness h) async {
  final folders = h.read(foldersRepositoryProvider);
  final work = await folders.create(ItemType.task, 'Work', iconKey: 'work');
  final note = await h
      .read(notesRepositoryProvider)
      .createEmpty(title: 'Q3 Roadmap', initialText: 'Milestones');
  return h
      .read(tasksRepositoryProvider)
      .save(
        TaskItem(
          id: '',
          title: 'Review FocusFlow Q3 Strategy',
          notes:
              'Go through the roadmap deck, align KPIs with the team and '
              'prepare questions for Thursday.',
          dueDate: DateTime(2026, 6, 16),
          dueTimeMinutes: 9 * 60,
          repeatRule: 'FREQ=WEEKLY;BYDAY=TU',
          remindOffsetMinutes: 15,
          priority: TaskPriority.medium,
          listId: work,
          tags: const [
            Tag(id: '', name: 'q3'),
            Tag(id: '', name: 'strategy'),
          ],
          linkedNoteId: note,
          subtasks: const [
            Subtask.draft('Collect Q2 metrics', done: true),
            Subtask.draft('Draft strategy outline', done: true),
            Subtask.draft('Review with design lead'),
          ],
          createdAt: _now,
          updatedAt: _now,
        ),
      );
}

Future<TestHarness> _harness(WidgetTester tester) async {
  tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  addTearDown(tester.view.resetPadding);
  final h = (await tester.runAsync(
    () => TestHarness.create(now: _now, overrides: isolatedNotifications()),
  ))!;
  addTearDown(() => tester.runAsync(h.dispose));
  return h;
}

Future<TaskItem?> _load(WidgetTester tester, TestHarness h, String id) => tester
    .runAsync(() => h.read(tasksRepositoryProvider).getTask(id))
    .then((t) => t);

void main() {
  testWidgets('renders the mockup task (light + dark captures)', (
    tester,
  ) async {
    await loadAppFonts();
    final h = await _harness(tester);
    final id = (await tester.runAsync(() => _seedMockup(h)))!;
    await pumpApp(tester, h, AppRoutes.task(id), size: _tall);

    expect(find.byType(TaskEditorScreen), findsOneWidget);
    await captureScreen(tester, '11_task_editor');
    expect(find.text('Edit Task'), findsOneWidget);
    expect(find.text('Review FocusFlow Q3 Strategy'), findsOneWidget);
    expect(find.text('SCHEDULE'), findsOneWidget);
    expect(find.text('Tue, Jun 16'), findsOneWidget);
    expect(find.text('09:00 AM'), findsOneWidget);
    expect(find.text('Weekly · Tue'), findsOneWidget);
    expect(find.text('15 min before'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('#q3 #strategy'), findsOneWidget);
    expect(find.text('Q3 Roadmap'), findsOneWidget);
    expect(find.text('SUBTASKS · 2/3'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    await captureScreen(tester, '11_task_editor');

    await pumpApp(tester, h, AppRoutes.task(id), size: _tall, dark: true);
    await captureScreen(tester, '11_task_editor_dark');
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    await loadAppFonts();
    final h = await _harness(tester);
    final id = (await tester.runAsync(() => _seedMockup(h)))!;
    await pumpApp(
      tester,
      h,
      AppRoutes.task(id),
      size: const Size(360, 800),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '11_task_editor_360_x13');
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new task: prefill from the query, Save needs a title', (
    tester,
  ) async {
    await loadAppFonts();
    final h = await _harness(tester);
    await pumpApp(
      tester,
      h,
      AppRoutes.newTask(
        date: '2026-06-15',
        timeMinutes: 14 * 60 + 30,
        priority: TaskPriority.high.index,
        tag: 'home',
        repeatRule: 'FREQ=DAILY',
      ),
      size: _tall,
    );
    expect(find.text('New Task'), findsOneWidget);
    expect(find.text('Mon, Jun 15'), findsOneWidget);
    expect(find.text('02:30 PM'), findsOneWidget);
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('#home'), findsOneWidget);
    expect(find.text('Archive'), findsNothing);
    await captureScreen(tester, '11_task_editor_new');

    // Save is disabled without a title.
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('New Task'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '  Water plants ');
    await tester.pump();
    await tester.tap(find.text('+ Add'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Subtask'), 'Ferns');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.byType(TaskEditorScreen), findsNothing);

    final saved = await tester.runAsync(
      () => h
          .read(tasksRepositoryProvider)
          .watchTasks(const TasksQuery(scope: TasksScope.all))
          .first,
    );
    final task = saved!.single;
    expect(task.title, 'Water plants');
    expect(task.priority, TaskPriority.high);
    expect(task.dueDate, DateTime(2026, 6, 15));
    expect(task.dueTimeMinutes, 14 * 60 + 30);
    expect(task.repeatRule, 'FREQ=DAILY');
    expect(task.tags.map((t) => t.name), ['home']);
    expect(task.subtasks.map((s) => s.title), ['Ferns']);
  });

  testWidgets('edit: toggling a subtask and priority saves them', (
    tester,
  ) async {
    final h = await _harness(tester);
    final id = (await tester.runAsync(() => _seedMockup(h)))!;
    await pumpApp(tester, h, AppRoutes.task(id), size: _tall);

    await tester.tap(find.bySemanticsLabel('Review with design lead done'));
    await tester.tap(find.text('High'));
    await settle(tester);
    expect(find.text('SUBTASKS · 3/3'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await settle(tester);

    final task = (await _load(tester, h, id))!;
    expect(task.priority, TaskPriority.high);
    expect(task.subtasks.every((s) => s.done), isTrue);
    expect(task.reminderId, isNotNull);
  });

  testWidgets('Cancel with changes asks to discard', (tester) async {
    final h = await _harness(tester);
    final id = (await tester.runAsync(() => _seedMockup(h)))!;
    await pumpApp(tester, h, AppRoutes.task(id), size: _tall);

    await tester.tap(find.text('Low'));
    await settle(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await settle(tester);
    expect(find.byType(TaskEditorScreen), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    await tester.tap(find.text('Discard'));
    await settle(tester);
    expect(find.byType(TaskEditorScreen), findsNothing);
    expect((await _load(tester, h, id))!.priority, TaskPriority.medium);
  });

  testWidgets('Archive archives the task and leaves', (tester) async {
    final h = await _harness(tester);
    final id = (await tester.runAsync(() => _seedMockup(h)))!;
    await pumpApp(tester, h, AppRoutes.task(id), size: _tall);

    await tester.tap(find.text('Archive'));
    await settle(tester);
    expect(find.byType(TaskEditorScreen), findsNothing);
    expect((await _load(tester, h, id))!.isArchived, isTrue);
  });

  testWidgets('Delete confirms, moves to Recently Deleted and leaves', (
    tester,
  ) async {
    final h = await _harness(tester);
    final id = (await tester.runAsync(() => _seedMockup(h)))!;
    await pumpApp(tester, h, AppRoutes.task(id), size: _tall);

    await tester.tap(find.text('Delete'));
    await settle(tester);
    expect(find.text('Delete this task?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await settle(tester);
    expect(find.byType(TaskEditorScreen), findsNothing);
    expect((await _load(tester, h, id))?.deletedAt, isNotNull);
  });

  testWidgets('pickers: repeat (custom), time, tags and linked note', (
    tester,
  ) async {
    await loadAppFonts();
    final h = await _harness(tester);
    final id = (await tester.runAsync(() => _seedMockup(h)))!;
    await pumpApp(tester, h, AppRoutes.task(id), size: _tall);

    await tester.tap(find.text('Repeat'));
    await settle(tester);
    await captureScreen(tester, '11_task_editor_repeat');
    await tester.tap(find.text('Custom…'));
    await settle(tester);
    await captureScreen(tester, '11_task_editor_repeat_custom');
    await tester.tap(find.text('Done').last);
    await settle(tester);
    expect(find.text('Repeat'), findsOneWidget);

    await tester.tap(find.text('Repeat'));
    await settle(tester);
    await tester.tap(find.text('Daily').last);
    await settle(tester);
    expect(find.text('Daily'), findsOneWidget);

    await tester.tap(find.text('Time'));
    await settle(tester);
    await captureScreen(tester, '11_task_editor_time');
    await tester.tapAt(const Offset(10, 60));
    await settle(tester);

    await tester.tap(find.text('Tags'));
    await settle(tester);
    await captureScreen(tester, '11_task_editor_tags');
    await tester.tapAt(const Offset(10, 60));
    await settle(tester);

    await tester.tap(find.text('Linked note'));
    await settle(tester);
    await captureScreen(tester, '11_task_editor_note');
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing task shows "Task not found"', (tester) async {
    final h = await _harness(tester);
    await pumpApp(tester, h, AppRoutes.task('nope'));
    expect(find.text('Task not found'), findsOneWidget);
  });
}
