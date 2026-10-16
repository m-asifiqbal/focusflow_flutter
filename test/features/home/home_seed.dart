/// Seeds the data of mockup 03 (Tuesday 13 June 2023, 9:35): the Q3
/// strategy / Home screen / morning run tasks (+ four more so the hero
/// reads 4/7 · 57% · 3 LEFT), "Call the bank about card" at 10:00 (+ two
/// later reminders → 3), the Ideas and Groceries notes and the four habit
/// rings (Water, Reading, Gym, Meditate). Run inside `tester.runAsync`.
library;

import 'dart:convert';

import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/features/notes/domain/services/note_content.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/screen_harness.dart';
import '../../helpers/test_container.dart';

/// "Now" of the mockup: Tuesday 13 June 2023, 9:35.
final homeNow = DateTime(2023, 6, 13, 9, 35);
final homeToday = DateTime(2023, 6, 13);

/// Seeds everything; returns task ids by title.
Future<Map<String, String>> seedHomeMockup(TestHarness h) async {
  await h.updateSettings(
    (s) => s.copyWith(displayName: 'Asif', dailyFocusGoal: 7),
  );
  final ids = <String, String>{};
  await _seedTasks(h, ids);
  await _seedReminders(h);
  await _seedNotes(h);
  await _seedHabits(h);
  await h
      .read(inboxRepositoryProvider)
      .add(kind: InboxKind.reminder, title: 'Water the plants');
  h.clock.set(homeNow);
  return ids;
}

Future<void> _seedTasks(TestHarness h, Map<String, String> ids) async {
  final repo = h.read(tasksRepositoryProvider);
  Future<String> add(
    String title,
    int minutes, {
    TaskPriority priority = TaskPriority.none,
    List<String> tags = const [],
    DateTime? due,
    bool done = false,
    bool pinned = false,
  }) async {
    final draft = TaskItem.draft(
      now: homeNow,
      title: title,
      dueDate: due ?? homeToday,
      dueTimeMinutes: minutes,
      priority: priority,
      tags: [for (final t in tags) Tag(id: '', name: t)],
    );
    final id = await repo.save(draft.copyWith(isPinned: pinned));
    if (done) await repo.complete(id);
    return ids[title] = id;
  }

  h.clock.set(homeNow);
  await add(
    'Review FocusFlow Q3 Strategy',
    9 * 60,
    priority: TaskPriority.high,
    pinned: true,
  );
  await add('Design Home Screen v2', 11 * 60 + 30, tags: ['work']);
  await add('Morning run 5 km', 7 * 60, tags: ['health'], done: true);
  await add('Plan sprint retro', 16 * 60, tags: ['work']);
  await add('Inbox zero', 8 * 60, done: true);
  await add('Stretch break', 8 * 60 + 30, done: true);
  await add('Water the plants', 6 * 60 + 45, done: true);
  await add(
    'Book dentist',
    10 * 60,
    due: DateTime(2023, 6, 15),
    tags: ['personal'],
  );
}

Future<void> _seedReminders(TestHarness h) async {
  final repo = h.read(remindersRepositoryProvider);
  for (final (title, at) in [
    ('Call the bank about card', DateTime(2023, 6, 13, 10)),
    ('Pick up dry cleaning', DateTime(2023, 6, 13, 14)),
    ('Take vitamins', DateTime(2023, 6, 13, 20)),
    ('Pay rent', DateTime(2023, 6, 12, 18)),
  ]) {
    await repo.save(Reminder.draft(triggerAt: at, title: title));
  }
}

Future<void> _seedNotes(TestHarness h) async {
  final notes = h.read(notesRepositoryProvider);
  final folders = h.read(foldersRepositoryProvider);
  h.clock.set(DateTime(2023, 6, 13, 7, 35));
  final groceries = await notes.createEmpty(
    tagNames: ['groceries'],
    title: 'Weekend Shopping',
  );
  final ops = [
    {'insert': 'Almond milk'},
    {
      'insert': '\n',
      'attributes': {'list': 'unchecked'},
    },
    {'insert': 'Avocados'},
    {
      'insert': '\n',
      'attributes': {'list': 'checked'},
    },
    {'insert': 'Spinach'},
    {
      'insert': '\n',
      'attributes': {'list': 'unchecked'},
    },
  ];
  final delta = jsonEncode(ops);
  final content = NoteContent.fromDeltaJson(delta);
  await notes.saveContent(
    groceries,
    title: 'Weekend Shopping',
    deltaJson: delta,
    plainText: content.plainText,
    checklist: content.checklist,
    wordCount: 4,
  );

  final ideasFolder = await folders.create(ItemType.note, 'Ideas');
  final ideas = await notes.createEmpty(
    folderId: ideasFolder,
    colorHex: 'D1FAE5',
    tagNames: ['ideas'],
    title: 'Mobile App Design Trends',
    initialText:
        'Minimalism, organic shapes and personalised AI experiences are '
        'leading the way this year.',
  );
  await notes.setPinned(ideas, true);
}

Future<void> _seedHabits(TestHarness h) async {
  final repo = h.read(habitsRepositoryProvider);
  final start = DateTime(2023, 5, 1);
  Future<void> add(
    String name,
    String icon,
    String hex, {
    int target = 1,
    int count = 0,
  }) async {
    final id = await repo.save(
      Habit.draft(
        startDate: start,
        name: name,
        iconKey: icon,
        colorHex: hex,
        targetCount: target,
      ),
    );
    if (count > 0) await repo.setLog(id, homeToday, count: count);
  }

  await add(
    'Water',
    'droplet',
    HabitPalette.hexOf(HabitPalette.blue),
    target: 4,
    count: 3,
  );
  await add(
    'Reading',
    'book-open',
    HabitPalette.hexOf(HabitPalette.emerald),
    count: 1,
  );
  await add('Gym', 'dumbbell', HabitPalette.hexOf(HabitPalette.indigo));
  await add(
    'Meditate',
    'spa',
    HabitPalette.hexOf(HabitPalette.orange),
    target: 10,
    count: 5,
  );
}
