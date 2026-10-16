/// Seeds the data behind the Global search mockup (design/06): 14 matches
/// for "design" — Notes 5, Tasks 4, Reminders 2, Habits 1, Vault 2 — with
/// the five title matches edited most recently so they rank on top.
library;

import 'dart:typed_data';

import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/test_container.dart';

/// Wednesday 10 June 2026, 9:00.
final DateTime searchNow = DateTime(2026, 6, 10, 9);

/// Ids of the seeded top hits.
class SearchSeed {
  late String note;
  late String task;
  late String reminder;
  late String vault;
  late String habit;
}

Future<SearchSeed> seedSearchMockup(TestHarness h) async {
  final seed = SearchSeed();
  final notes = h.read(notesRepositoryProvider);
  final tasks = h.read(tasksRepositoryProvider);
  final reminders = h.read(remindersRepositoryProvider);
  final habits = h.read(habitsRepositoryProvider);
  final vault = h.read(vaultRepositoryProvider);
  final folders = h.read(foldersRepositoryProvider);

  void at(Duration ago) => h.clock.set(searchNow.subtract(ago));
  TaskItem task(String title, {String notes = '', DateTime? due, int? time}) =>
      TaskItem(
        id: '',
        title: title,
        notes: notes,
        dueDate: due,
        dueTimeMinutes: time,
        createdAt: h.clock.now(),
        updatedAt: h.clock.now(),
      );
  Reminder reminder(String title, DateTime trigger, {String note = ''}) =>
      Reminder(
        id: '',
        title: title,
        note: note,
        triggerAt: trigger,
        createdAt: h.clock.now(),
        updatedAt: h.clock.now(),
      );
  VaultItemRecord login(String title) => VaultItemRecord(
    id: '',
    type: VaultItemType.login,
    title: title,
    encryptedPayload: Uint8List.fromList([1, 2, 3]),
    createdAt: h.clock.now(),
    updatedAt: h.clock.now(),
  );

  // Older, weaker matches (body / second-tier).
  at(const Duration(days: 30));
  await notes.createEmpty(
    title: 'Weekly review',
    initialText: 'Notes on the design system rollout.',
  );
  await notes.createEmpty(
    title: 'Book list',
    initialText: 'The Design of Everyday Things.',
  );
  await notes.createEmpty(
    title: 'Team sync',
    initialText: 'Discussed design tokens and spacing.',
  );
  await notes.createEmpty(
    title: 'Ideas backlog',
    initialText: 'Redesign onboarding, design critique.',
  );
  await tasks.save(task('Update tokens', notes: 'After the design review'));
  await tasks.save(task('Write changelog', notes: 'Mention design fixes'));
  await tasks.save(task('Plan sprint', notes: 'Include design QA'));
  await reminders.save(
    reminder('Call Sam', DateTime(2026, 6, 15, 10), note: 'design budget'),
  );
  await vault.save(login('Design Weekly newsletter'));

  // The five top hits of the mockup (most recent first).
  at(const Duration(days: 14));
  final habitDay = DateTime(2026, 5, 20);
  seed.habit = await habits.save(
    Habit(
      id: '',
      name: 'Daily design sketch',
      category: 'Creativity',
      startDate: habitDay,
      createdAt: h.clock.now(),
      updatedAt: h.clock.now(),
    ),
  );
  for (var i = 1; i <= 12; i++) {
    await habits.increment(seed.habit, DateTime(2026, 6, 10 - i));
  }
  at(const Duration(days: 6));
  seed.vault = await vault.save(login('Figma — design account'));
  at(const Duration(days: 3));
  seed.reminder = await reminders.save(
    reminder('Review design handoff', DateTime(2026, 6, 12, 15)),
  );
  at(const Duration(days: 1));
  seed.task = await tasks.save(
    task('Design Home Screen v2', due: DateTime(2026, 6, 10), time: 690),
  );
  at(const Duration(hours: 2));
  final ideas = await folders.create(ItemType.note, 'Ideas');
  seed.note = await notes.createEmpty(
    title: 'Mobile App Design Trends',
    folderId: ideas,
    initialText: 'Bento grids, soft gradients, bold type.',
  );

  // Never searchable: trashed.
  final trashed = await notes.createEmpty(title: 'Design draft (trashed)');
  await h.read(itemsRepositoryProvider).moveToTrash([
    ItemRef(ItemType.note, trashed),
  ]);
  h.clock.set(searchNow);
  return seed;
}
