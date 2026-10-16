/// Habit rows of the shared item actions sheet (screen 09): Log today,
/// Pause / Resume. Owned by the habits feature; see
/// shared/item_actions/module_item_actions.dart.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/ff_action_sheet.dart';
import 'package:focusflow/core/widgets/ff_snackbar.dart';
import 'package:focusflow/features/habits/presentation/habit_check_in_actions.dart';
import 'package:focusflow/features/habits/presentation/providers/habit_logger_provider.dart';
import 'package:focusflow/shared/item_actions/module_item_actions.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// Module rows for [item]. Each row's onTap runs after the sheet closes.
/// Archived / deleted habits get none (they can't be logged or paused).
Future<ModuleItemActions> habitItemActions(
  BuildContext context,
  WidgetRef ref,
  ItemSummary item,
) async {
  final habit = await ref.read(habitsRepositoryProvider).getHabit(item.id);
  if (habit == null || !habit.isActive) return ModuleItemActions.none;
  final paused = habit.isPaused;
  return ModuleItemActions(
    leading: [
      FFActionItem(
        icon: FontAwesomeIcons.check,
        label: 'Log today',
        colors: ModuleStyle.habits.colors,
        onTap: () {
          if (context.mounted) logHabitToday(context, ref, habit.id);
        },
      ),
      FFActionItem(
        icon: paused ? FontAwesomeIcons.play : FontAwesomeIcons.pause,
        label: paused ? 'Resume habit' : 'Pause habit',
        colors: ActionTints.lock,
        onTap: () async {
          if (!context.mounted) return;
          final logger = ref.read(habitLoggerProvider);
          await logger.setPaused(habit.id, !paused);
          if (!context.mounted) return;
          showUndoSnackbar(
            context,
            message: paused
                ? '"${habit.name}" resumed'
                : '"${habit.name}" paused',
            icon: paused ? FontAwesomeIcons.play : FontAwesomeIcons.pause,
            onUndo: () => logger.setPaused(habit.id, paused),
          );
        },
      ),
    ],
  );
}
