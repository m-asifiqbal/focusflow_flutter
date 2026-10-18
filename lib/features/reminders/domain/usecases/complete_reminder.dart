/// ============================================================
/// COMPLETE REMINDER — the one "mark done" used everywhere
/// ============================================================
///
/// What: marks one occurrence of a reminder done and, when it is a
/// one-time reminder linked to a task, completes that task too (the
/// reminder was the task's "Remind me": acknowledging it means the task is
/// done — notification Done, inbox Done and the list's MARK DONE / swipe /
/// actions sheet all behave the same). Repeating reminders only advance;
/// they never complete their task.
///
/// Why: the list and the notification used to diverge (only the
/// notification completed the task). Both now call this, and [undo]
/// restores the reminder and reopens the task (discarding a spawned next
/// occurrence of a repeating task).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/domain/repository/reminders_repository.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';

/// What [CompleteReminder] changed (for Undo).
@immutable
class ReminderDone {
  const ReminderDone({required this.before, this.task});

  /// The reminder as it was before.
  final Reminder before;

  /// The linked task completed alongside it, if any.
  final TaskCompletion? task;
}

class CompleteReminder {
  const CompleteReminder({required this.reminders, required this.tasks});

  final RemindersRepository reminders;
  final TasksRepository tasks;

  /// Marks [occurrence] (default: the pending one) of reminder [id] done.
  /// Null when the reminder is gone, inactive, already done, or the
  /// occurrence was already acknowledged.
  Future<ReminderDone?> call(String id, {DateTime? occurrence}) async {
    final r = await reminders.getReminder(id);
    if (r == null || !r.isActive || r.isCompleted) return null;
    final before = await reminders.markDone(id, occurrence: occurrence);
    if (before == null) return null;
    TaskCompletion? task;
    final link = before.linkedRef;
    if (link != null && link.type == ItemType.task && !before.isRecurring) {
      final t = await tasks.getTask(link.id);
      if (t != null && t.isActive && !t.isCompleted) {
        task = await tasks.complete(t.id);
        if (!task.completed) task = null;
      }
    }
    return ReminderDone(before: before, task: task);
  }

  /// Reverts [done]: reopens the task first (its reminder sync runs), then
  /// writes the reminder back exactly as it was.
  Future<void> undo(ReminderDone done) async {
    final task = done.task;
    if (task != null) {
      await tasks.uncomplete(
        task.taskId,
        discardNextOccurrenceId: task.nextOccurrenceId,
        reopenSubtaskIds: task.completedSubtaskIds,
      );
    }
    await reminders.save(done.before);
  }
}
