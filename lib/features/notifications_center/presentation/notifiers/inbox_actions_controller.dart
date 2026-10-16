/// ============================================================
/// INBOX ACTIONS CONTROLLER — the writes behind screen 27's buttons
/// ============================================================
///
/// What: mark read / read all, swipe-dismiss, and the inline Done / Snooze
/// / Log buttons. Done, Snooze and Log run [NotificationActions] — the
/// same code the OS notification buttons run (acceptance: "Actions perform
/// the same logic as system notification actions"). Each write returns an
/// [InboxUndo] that puts things back for the 5 s Undo snackbar.
/// Why: CLAUDE.md rule 5 — widgets trigger flows, writes live here.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/notifications/engine/notification_actions.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';
import 'package:focusflow/features/notifications_center/domain/repository/inbox_repository.dart';
import 'package:focusflow/features/reminders/domain/repository/reminders_repository.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// Reverts one inbox action.
typedef InboxUndo = Future<void> Function();

class InboxActionsController {
  const InboxActionsController({
    required this.inbox,
    required this.reminders,
    required this.tasks,
    required this.actions,
  });

  final InboxRepository inbox;
  final RemindersRepository reminders;
  final TasksRepository tasks;
  final NotificationActions actions;

  Future<void> markRead(InboxEntry e) async {
    if (!e.isRead) await inbox.markRead(e.id);
  }

  /// "Read all" — every unread entry of [kind] (null = all kinds).
  Future<void> markAllRead(InboxKind? kind) => inbox.markAllRead(kind: kind);

  /// Swipe to dismiss; the undo brings the row back.
  Future<InboxUndo> dismiss(InboxEntry e) async {
    await inbox.dismiss(e.id);
    return () => inbox.undismiss(e.id);
  }

  /// "Done" on a reminder entry: marks it (and its linked task) done.
  /// Returns null when nothing changed (item gone, archived or done).
  Future<InboxUndo?> doneReminder(InboxEntry e) async {
    final target = e.ref;
    await markRead(e);
    if (target == null || target.type != ItemType.reminder) return null;
    final before = await reminders.getReminder(target.id);
    if (before == null) return null;
    final link = before.linkedRef;
    final linkedTask = link != null && link.type == ItemType.task
        ? await tasks.getTask(link.id)
        : null;
    if (!await actions.markDone(target)) return null;
    return () async {
      await reminders.save(before);
      if (linkedTask != null && !linkedTask.isCompleted) {
        final now = await tasks.getTask(linkedTask.id);
        if (now != null && now.isCompleted) {
          await tasks.uncomplete(linkedTask.id);
        }
      }
    };
  }

  /// "Snooze Nm" on a reminder entry; null when nothing changed.
  Future<InboxUndo?> snooze(InboxEntry e, int minutes) async {
    final target = e.ref;
    await markRead(e);
    if (target == null || target.type != ItemType.reminder) return null;
    final before = await reminders.getReminder(target.id);
    if (before == null) return null;
    if (!await actions.snooze(target, minutes: minutes)) return null;
    return () async {
      await reminders.save(before);
    };
  }

  /// "Log" on a habit entry: one check-in today. True when logged.
  Future<bool> logHabit(InboxEntry e) async {
    final target = e.ref;
    await markRead(e);
    if (target == null) return false;
    return actions.checkIn(target);
  }

  /// Open tasks due before today ("Reschedule" on the overdue digest).
  Future<List<TaskItem>> overdueTasks() =>
      tasks.watchTasks(const TasksQuery(scope: TasksScope.overdue)).first;
}

final inboxActionsControllerProvider = Provider<InboxActionsController>(
  (ref) => InboxActionsController(
    inbox: ref.watch(inboxRepositoryProvider),
    reminders: ref.watch(remindersRepositoryProvider),
    tasks: ref.watch(tasksRepositoryProvider),
    actions: ref.watch(notificationActionsProvider),
  ),
);
