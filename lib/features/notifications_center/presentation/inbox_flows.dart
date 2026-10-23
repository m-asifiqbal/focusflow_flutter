/// ============================================================
/// INBOX FLOWS — what tapping a notification row or button does
/// ============================================================
///
/// What: open (row tap / View / Open / Fix), Done, Snooze, Reschedule,
/// Log, swipe-dismiss, Clear all and Read all — each marks the entry read, runs the
/// write through [InboxActionsController] (or the owning module's flow)
/// and shows the 5 s Undo snackbar.
/// Why: CLAUDE.md rule 3 (Undo on every destructive action) and rule 5
/// (widgets only trigger flows).
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/router/open_location.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';
import 'package:focusflow/features/notifications_center/presentation/notifiers/inbox_actions_controller.dart';
import 'package:focusflow/features/tasks/presentation/task_flows.dart';

/// The list a row without an item opens (overdue digest → Tasks, …).
String? inboxFallbackRoute(InboxKind kind) => switch (kind) {
  InboxKind.reminder => AppRoutes.reminders,
  InboxKind.task => AppRoutes.tasks,
  InboxKind.habit => AppRoutes.habits,
  InboxKind.medicine => AppRoutes.medicines,
  InboxKind.security => AppRoutes.vault,
  InboxKind.sync => AppRoutes.settingsBackup,
  InboxKind.system => null,
};

/// Row tap / View / Open / Fix: marks read and opens the item or the kind's
/// list — a drill-in, so back returns to the notifications. The lists that
/// live in the tab shell (Tasks, Reminders, Habits, Backup …) can't be pushed
/// over this full-screen route (it left a blank screen), so
/// [OpenLocation.openLocation] switches to their tab instead.
void openInboxEntry(BuildContext context, WidgetRef ref, InboxEntry e) {
  unawaited(ref.read(inboxActionsControllerProvider).markRead(e));
  final target = e.ref;
  final route = target != null
      ? AppRoutes.open(target)
      : inboxFallbackRoute(e.kind);
  if (route != null) context.openLocation(route);
}

/// Runs the inline button [action] of [e].
Future<void> runInboxAction(
  BuildContext context,
  WidgetRef ref,
  InboxEntry e,
  String action, {
  required int snoozeMinutes,
}) async {
  final c = ref.read(inboxActionsControllerProvider);
  switch (action) {
    case InboxActions.done:
      final target = e.ref;
      if (target?.type == ItemType.task) {
        unawaited(c.markRead(e));
        completeTask(context, ref, target!.id, title: e.title);
        return;
      }
      final undo = await c.doneReminder(e);
      if (!context.mounted) return;
      _result(
        context,
        undo,
        tr('"{title}" done', {'title': e.title}),
        FontAwesomeIcons.solidCircleCheck,
      );
    case InboxActions.snooze:
      final undo = await c.snooze(e, snoozeMinutes);
      if (!context.mounted) return;
      _result(
        context,
        undo,
        tr('Snoozed for {m} min', {'m': snoozeMinutes}),
        FontAwesomeIcons.solidClock,
      );
    case InboxActions.reschedule:
      unawaited(c.markRead(e));
      final overdue = await c.overdueTasks();
      if (!context.mounted) return;
      if (overdue.isEmpty) {
        showFFToast(
          context,
          tr('Nothing is overdue'),
          icon: FontAwesomeIcons.solidCircleCheck,
        );
        return;
      }
      await rescheduleTasks(context, ref, overdue);
    case InboxActions.log:
      final logged = await c.logHabit(e);
      if (!context.mounted) return;
      showFFToast(
        context,
        logged ? tr('Checked in') : tr('Already up to date'),
        icon: FontAwesomeIcons.solidCircleCheck,
      );
    default: // view, open, fix
      openInboxEntry(context, ref, e);
  }
}

void _result(BuildContext context, InboxUndo? undo, String msg, IconData icon) {
  if (undo == null) {
    showFFToast(context, tr('Already up to date'), icon: icon);
    return;
  }
  showUndoSnackbar(context, message: msg, icon: icon, onUndo: () => undo());
}

/// Swipe-to-dismiss with "Notification dismissed · UNDO". [onUndo] runs
/// after the entry is restored (the screen un-hides its row).
Future<void> dismissInboxEntry(
  BuildContext context,
  WidgetRef ref,
  InboxEntry e, {
  VoidCallback? onUndo,
}) async {
  final undo = await ref.read(inboxActionsControllerProvider).dismiss(e);
  if (!context.mounted) return;
  showUndoSnackbar(
    context,
    message: tr('Notification dismissed'),
    icon: FontAwesomeIcons.solidBellSlash,
    onUndo: () async {
      await undo();
      onUndo?.call();
    },
  );
}

/// "Clear all" of one day: dismisses every entry of [entries] at once with
/// one "N notifications cleared · UNDO". [onUndo] runs after they are
/// restored (the screen un-hides the rows).
Future<void> clearInboxEntries(
  BuildContext context,
  WidgetRef ref,
  List<InboxEntry> entries, {
  VoidCallback? onUndo,
}) async {
  if (entries.isEmpty) return;
  final undo = await ref
      .read(inboxActionsControllerProvider)
      .dismissAll(entries);
  if (!context.mounted) return;
  final n = entries.length;
  showUndoSnackbar(
    context,
    message: n == 1
        ? tr('Notification cleared')
        : tr('{n} notifications cleared', {'n': n}),
    icon: FontAwesomeIcons.solidBellSlash,
    onUndo: () async {
      await undo();
      onUndo?.call();
    },
  );
}

/// The label of an inline button ([snoozeMinutes] for "Snooze 10m").
String inboxActionLabel(String action, int snoozeMinutes) => switch (action) {
  InboxActions.done => tr('Done'),
  InboxActions.snooze => tr('Snooze {m}m', {'m': snoozeMinutes}),
  InboxActions.reschedule => tr('Reschedule'),
  InboxActions.view => tr('View'),
  InboxActions.open => tr('Open'),
  InboxActions.fix => tr('Fix'),
  InboxActions.log => tr('Log'),
  _ => action,
};
