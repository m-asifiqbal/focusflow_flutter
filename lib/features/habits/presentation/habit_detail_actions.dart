/// ============================================================
/// HABIT DETAIL ACTIONS — buttons and More sheet of screen 16
/// ============================================================
///
///   logFromDetail       "+ Log 1 glass" / "Mark done" / "Log a slip"
///   skipFromDetail      "Skip today" (Undo) ⇄ "Unskip"
///   saveHabitDay        heatmap / history day editor writes (Undo)
///   showHabitDetailMore More: Pause / Resume, Export CSV, Archive, Delete
///                       (a trashed habit: Restore / Delete forever only)
/// Archive and Delete go through the shared lifecycle actions (confirm +
/// 5 s Undo) and leave the screen once the habit is gone.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/services/habit_check_in.dart';
import 'package:focusflow/features/habits/domain/services/habit_words.dart';
import 'package:focusflow/features/habits/presentation/habit_check_in_actions.dart';
import 'package:focusflow/features/habits/presentation/habit_icons.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/features/habits/presentation/providers/habit_detail_providers.dart';
import 'package:focusflow/features/habits/presentation/providers/habit_logger_provider.dart';
import 'package:focusflow/shared/item_actions/item_lifecycle_actions.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

/// The primary button: one check-in, done toggle, or a slip (with Undo).
Future<void> logFromDetail(
  BuildContext context,
  WidgetRef ref,
  Habit habit,
  HabitLog? todayLog,
) async {
  final logger = ref.read(habitLoggerProvider);
  final outcome = await logger.apply(
    habit,
    todayLog,
    HabitCheckIn.detailLog(habit),
  );
  habitHaptic(ref, outcome);
  if (outcome == HabitLogOutcome.slipped && context.mounted) {
    showUndoSnackbar(
      context,
      message: tr('Slip logged · "{name}" streak reset', {'name': habit.name}),
      icon: FontAwesomeIcons.rotateLeft,
      onUndo: () => logger.undo(habit, todayLog),
    );
  }
}

/// "Skip today": marks a rest day (Undo restores the day); on a skipped
/// day it clears the skip instead.
Future<void> skipFromDetail(
  BuildContext context,
  WidgetRef ref,
  Habit habit,
  HabitLog? todayLog,
) async {
  final logger = ref.read(habitLoggerProvider);
  if (todayLog?.skipped ?? false) {
    await logger.undo(habit, null);
    return;
  }
  await logger.skipToday(habit.id);
  if (!context.mounted) return;
  showUndoSnackbar(
    context,
    message: tr('"{name}" skipped today', {'name': habit.name}),
    icon: FontAwesomeIcons.forward,
    onUndo: () => logger.undo(habit, todayLog),
  );
}

/// Writes one day's log from the day editor; [count] 0, not skipped and
/// no note removes the log. When the day actually changed, the 5 s Undo
/// snackbar (in [context]) puts the previous log back.
Future<void> saveHabitDay(
  BuildContext context,
  WidgetRef ref,
  Habit habit,
  DateTime day, {
  required int count,
  required bool skipped,
  required String note,
}) async {
  final repo = ref.read(habitsRepositoryProvider);
  final logger = ref.read(habitLoggerProvider);
  final before =
      (await repo.watchHabitWithLogs(habit.id, from: day, to: day).first)?.logs
          .where((l) => DateUtilsX.isSameDay(l.date, day))
          .firstOrNull;
  final text = note.trim();
  final clear = count == 0 && !skipped && text.isEmpty;
  if (clear) {
    if (before == null) return;
    await repo.clearLog(habit.id, day);
  } else {
    final unchanged =
        before != null &&
        before.count == count &&
        before.skipped == skipped &&
        (before.note ?? '') == text;
    if (unchanged) return;
    await repo.setLog(
      habit.id,
      day,
      count: count,
      skipped: skipped,
      note: text.isEmpty ? null : text,
    );
  }
  if (!context.mounted) return;
  showUndoSnackbar(
    context,
    message: clear
        ? tr('Log removed · {format}', {
            'format': DateFormat.MMMd().format(day),
          })
        : tr('Log updated · {format}', {
            'format': DateFormat.MMMd().format(day),
          }),
    icon: FontAwesomeIcons.rotateLeft,
    onUndo: () => logger.restoreDay(habit.id, day, before),
  );
}

/// The detail's More sheet.
Future<void> showHabitDetailMore(
  BuildContext context,
  WidgetRef ref,
  Habit habit,
  List<HabitLog> logs,
) {
  final refs = [habit.ref];
  void leave() {
    if (context.mounted) context.go(AppRoutes.habits);
  }

  final header = FFActionSheetHeader(
    title: habit.name,
    icon: HabitIcons.of(habit.iconKey),
    colors: habit.colors,
    meta: habit.isDeleted
        ? tr('Habit · Recently deleted')
        : habit.isArchived
        ? tr('Habit · Archived')
        : tr('Habit · {category}', {
            'category': HabitWords.shown(habit.category),
          }),
  );

  // Opened from Recently Deleted or a deep link: only the trash actions.
  if (habit.isDeleted) {
    return showFFActionSheet(
      context,
      FFActionSheetData(
        header: header,
        actions: [
          FFActionItem(
            icon: FontAwesomeIcons.rotateLeft,
            label: tr('Restore'),
            colors: habit.colors,
            onTap: () =>
                restoreFromTrash(context, ref, refs, title: habit.name),
          ),
        ],
        deleteLabel: tr('Delete forever'),
        onDelete: () async {
          if (await deleteItemsForever(context, ref, refs, title: habit.name)) {
            leave();
          }
        },
      ),
    );
  }

  return showFFActionSheet(
    context,
    FFActionSheetData(
      header: header,
      actions: [
        if (habit.isActive)
          FFActionItem(
            icon: habit.isPaused
                ? FontAwesomeIcons.play
                : FontAwesomeIcons.pause,
            label: habit.isPaused ? tr('Resume habit') : tr('Pause habit'),
            colors: ActionTints.lock,
            onTap: () async {
              final logger = ref.read(habitLoggerProvider);
              await logger.setPaused(habit.id, !habit.isPaused);
              if (!context.mounted) return;
              showUndoSnackbar(
                context,
                message: habit.isPaused
                    ? tr('"{name}" resumed', {'name': habit.name})
                    : tr('"{name}" paused', {'name': habit.name}),
                icon: habit.isPaused
                    ? FontAwesomeIcons.play
                    : FontAwesomeIcons.pause,
                onUndo: () => logger.setPaused(habit.id, habit.isPaused),
              );
            },
          ),
        FFActionItem(
          icon: FontAwesomeIcons.fileCsv,
          label: tr('Export CSV'),
          colors: ActionTints.share,
          onTap: () async {
            try {
              await ref.read(habitCsvShareServiceProvider).share(habit, logs);
            } on Object {
              if (context.mounted) {
                showFFToast(
                  context,
                  tr("Couldn't export the history"),
                  icon: FontAwesomeIcons.triangleExclamation,
                );
              }
            }
          },
        ),
        if (habit.isArchived)
          FFActionItem(
            icon: FontAwesomeIcons.boxOpen,
            label: tr('Restore from archive'),
            colors: habit.colors,
            onTap: () => restoreFromArchive(context, ref, refs),
          ),
      ],
      onArchive: habit.isArchived
          ? null
          : () async {
              if (await archiveItems(context, ref, refs, title: habit.name)) {
                leave();
              }
            },
      onDelete: () async {
        if (await deleteItems(context, ref, refs, title: habit.name)) leave();
      },
    ),
  );
}
