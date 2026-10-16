/// ============================================================
/// TASKS LIST STATES — loading, error, empty and "all done" (screen 10)
/// ============================================================
///
/// What: skeleton rows while the first query runs; an error card with
/// Retry; the screen-29 empty state (no tasks / filter empty / no search
/// match) and the "All done for today 🎉" celebration card.
/// Why: every list in the app has these four states (master prompt §6);
/// they are kept apart from the screen so it stays layout-only.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/quick_add/presentation/quick_add.dart';
import 'package:focusflow/features/tasks/presentation/state/tasks_filter.dart';

const EdgeInsetsGeometry _gutter = EdgeInsetsDirectional.fromSTEB(
  AppSpacing.screen,
  AppSpacing.sm,
  AppSpacing.screen,
  0,
);

/// Skeleton rows while the first query runs.
class TasksLoadingState extends StatelessWidget {
  const TasksLoadingState({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsetsDirectional.fromSTEB(
      AppSpacing.screen,
      AppSpacing.xl,
      AppSpacing.screen,
      0,
    ),
    child: FFSkeletonList(count: 4),
  );
}

/// The query failed (e.g. the database could not be opened).
class TasksErrorState extends StatelessWidget {
  const TasksErrorState({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: _gutter,
    child: FFEmptyState.compact(
      colors: ModuleStyle.tasks.colors,
      icon: FontAwesomeIcons.triangleExclamation,
      title: "Couldn't load tasks",
      body: 'Something went wrong reading your tasks. Try again.',
      ctaLabel: 'Retry',
      ctaIcon: FontAwesomeIcons.arrowRotateRight,
      onCta: onRetry,
    ),
  );
}

/// No tasks for the current filter / search.
class TasksEmptyState extends StatelessWidget {
  const TasksEmptyState({
    required this.filter,
    required this.searching,
    required this.hasTasks,
    required this.onAdd,
    super.key,
  });

  final TaskFilter filter;
  final bool searching;

  /// Whether any active task exists at all (else: "No tasks yet").
  final bool hasTasks;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = ModuleStyle.tasks.colors;
    if (searching) {
      return Padding(
        padding: _gutter,
        child: FFEmptyState.compact(
          colors: colors,
          icon: FontAwesomeIcons.magnifyingGlass,
          title: 'No matching tasks',
          body: 'Try another word or clear the tag filter.',
        ),
      );
    }
    final (title, body) = switch (filter.smart) {
      _ when !hasTasks && !filter.isList => (
        'No tasks yet',
        'Capture what you need to do — due dates, priorities and '
            'subtasks keep it on track.',
      ),
      TaskSmartList.today => (
        'Nothing due today',
        'Nothing due today. Plan something or enjoy the calm.',
      ),
      TaskSmartList.upcoming => (
        'Nothing upcoming',
        'Tasks with a future due date show up here.',
      ),
      TaskSmartList.overdue => (
        'Nothing overdue',
        "You're on top of everything. Nice work!",
      ),
      TaskSmartList.completed => (
        'No completed tasks',
        'Tick a task off and it lands here.',
      ),
      TaskSmartList.all || null => (
        filter.isList ? 'This list is empty' : 'No tasks yet',
        'Capture what you need to do — due dates, priorities and '
            'subtasks keep it on track.',
      ),
    };
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.lg),
      child: FFEmptyState(
        colors: colors,
        icon: ModuleStyle.tasks.icon,
        title: title,
        body: body,
        ctaLabel: 'Add a task',
        onCta: onAdd,
        hint: 'Try: "Pay rent tomorrow 9am !high"',
        onHint: () =>
            showQuickAdd(context, text: 'Pay rent tomorrow 9am !high'),
      ),
    );
  }
}

/// "All done for today 🎉" — every task of today is ticked off.
class TasksAllDoneBanner extends StatelessWidget {
  const TasksAllDoneBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final colors = ModuleStyle.tasks.colors;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        AppSpacing.sm,
        AppSpacing.screen,
        AppSpacing.sm,
      ),
      child: FFCard(
        radius: AppRadii.row,
        color: colors.softFor(ff.brightness),
        shadow: false,
        border: false,
        child: Row(
          children: [
            FFIconTile(icon: FontAwesomeIcons.champagneGlasses, colors: colors),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('All done for today 🎉', style: context.text.cardTitle),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Every task due today is ticked off.',
                    style: context.text.meta,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
