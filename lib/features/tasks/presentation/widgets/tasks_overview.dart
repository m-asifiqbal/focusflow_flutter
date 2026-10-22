/// ============================================================
/// TASKS OVERVIEW — top of the Tasks list (screen 10)
/// ============================================================
///
/// What: the four tappable stat tiles (Today blue · Overdue red · Upcoming
/// emerald · Done slate) and the smart-list / task-list chip bar
/// ("Today", "Upcoming", "Work", "Personal", …, "All").
/// Why: both select the same [TaskFilter]; they read the live stats and
/// task lists from providers and only call `taskFilterProvider.select`.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/domain/entities/task_sections.dart';
import 'package:focusflow/features/tasks/presentation/providers/tasks_list_providers.dart';
import 'package:focusflow/features/tasks/presentation/state/tasks_filter.dart';
import 'package:focusflow/features/tasks/presentation/task_style.dart';
import 'package:focusflow/features/tasks/presentation/task_tokens.dart';
import 'package:focusflow/features/tasks/presentation/widgets/uniform_label_scale.dart';

/// Today · Overdue · Upcoming · Done.
class TaskStatTiles extends ConsumerWidget {
  const TaskStatTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(taskStatsProvider).valueOrNull ?? TaskStats.empty;
    final filter = ref.watch(taskFilterProvider);
    final ff = context.ff;
    final upcoming = ModuleColors(
      solid: ff.primary,
      soft: ff.primarySoft,
      ink: ff.primaryStrong,
    );
    Widget tile(TaskSmartList list, int value, ModuleColors colors) {
      // Today / Upcoming are mirrored by a selected chip (as in the
      // mockup), so only the chip-less filters ring their tile.
      final chipless =
          list == TaskSmartList.overdue || list == TaskSmartList.completed;
      return Expanded(
        child: FFStatTile(
          value: '$value',
          label: list.label,
          colors: colors,
          selected: chipless && filter.smart == list,
          onTap: () => ref
              .read(taskFilterProvider.notifier)
              .select(TaskFilter.smart(list)),
        ),
      );
    }

    // One text scale for all four tiles, so a long label ("Upcoming")
    // never renders smaller than its siblings at 360 pt / large text.
    Widget scaled(Widget row) => LayoutBuilder(
      builder: (context, box) {
        final tileWidth = (box.maxWidth - 3 * AppSpacing.sm) / 4;
        final scaler = uniformLabelScaler(
          context,
          labels: [for (final l in TaskSmartList.values) l.label],
          style: context.text.meta.copyWith(fontSize: 13),
          maxWidth: tileWidth - TaskSizes.statTileLabelInset,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: row,
        );
      },
    );

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.screen,
      ),
      child: scaled(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tile(TaskSmartList.today, stats.today, TaskStyle.todayTile),
              const SizedBox(width: AppSpacing.sm),
              tile(TaskSmartList.overdue, stats.overdue, TaskStyle.overdueTile),
              const SizedBox(width: AppSpacing.sm),
              tile(TaskSmartList.upcoming, stats.upcoming, upcoming),
              const SizedBox(width: AppSpacing.sm),
              tile(TaskSmartList.completed, stats.done, TaskStyle.doneTile),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Today" · "Upcoming" · one chip per task list · "All".
class TaskFilterChips extends ConsumerWidget {
  const TaskFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(taskFilterProvider);
    final lists = ref.watch(taskListsProvider).valueOrNull ?? const [];
    final items = <FFChipItem<TaskFilter>>[
      FFChipItem(
        value: TaskFilter.today,
        label: tr('Today'),
        icon: FontAwesomeIcons.solidSun,
      ),
      FFChipItem(
        value: TaskFilter.smart(TaskSmartList.upcoming),
        label: tr('Upcoming'),
        icon: FontAwesomeIcons.solidCalendar,
      ),
      for (final list in lists)
        FFChipItem(
          value: TaskFilter.list(list.id),
          label: list.name,
          icon: TaskStyle.listIcon(list),
        ),
      FFChipItem(
        value: TaskFilter.smart(TaskSmartList.all),
        label: tr('All'),
        icon: FontAwesomeIcons.listUl,
      ),
    ];
    return FFChipBar<TaskFilter>(
      items: items,
      selected: filter,
      onSelected: ref.read(taskFilterProvider.notifier).select,
    );
  }
}
