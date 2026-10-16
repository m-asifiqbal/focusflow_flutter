/// ============================================================
/// HOME SECTION STATES — empty / error / loading / first-run blocks
/// ============================================================
///
/// What: [HomeEmptyCard] (the compact FFEmptyState of screen 29 inside a
/// card, with an inline "Add task" / "Add reminder" CTA),
/// [HomeErrorCard] (message + Retry) and [HomeGetStartedCard] (3-step
/// checklist — first note, first task, first habit or reminder — shown in
/// place of today's empty task list until every step is done).
/// Why: every Home section degrades the same way, so the screen reads as
/// one system.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/home/domain/services/home_focus.dart';
import 'package:go_router/go_router.dart';

/// Friendly in-card empty state of one section.
class HomeEmptyCard extends StatelessWidget {
  const HomeEmptyCard({
    required this.colors,
    required this.icon,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.onCta,
    super.key,
  });

  final ModuleColors colors;
  final IconData icon;
  final String title;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return FFCard(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.xs),
      child: FFEmptyState.compact(
        colors: colors,
        icon: icon,
        title: title,
        body: body,
        ctaLabel: ctaLabel,
        onCta: onCta,
      ),
    );
  }
}

/// A section that failed to load, with Retry.
class HomeErrorCard extends StatelessWidget {
  const HomeErrorCard({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return FFCard(
      child: Row(
        children: [
          Icon(
            FontAwesomeIcons.triangleExclamation,
            size: AppSizes.tileGlyph,
            color: ff.danger,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              "Couldn't load this section",
              style: context.text.bodySmall.copyWith(color: ff.ink),
            ),
          ),
          FFTextButton(label: 'Retry', onPressed: onRetry),
        ],
      ),
    );
  }
}

/// First run: three steps that each open an editor and tick themselves
/// off once such an item exists ([HomeGetStarted]).
class HomeGetStartedCard extends StatelessWidget {
  const HomeGetStartedCard({
    required this.progress,
    this.firstRun = false,
    super.key,
  });

  final HomeGetStarted progress;

  /// Nothing exists yet: a welcome line instead of "1 of 3 done".
  final bool firstRun;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        ModuleStyle.notes,
        'Write your first note',
        'Capture ideas before they fade',
        AppRoutes.newNote,
        progress.hasNote,
      ),
      (
        ModuleStyle.tasks,
        'Add your first task',
        'Plan what matters today',
        AppRoutes.newTaskPath,
        progress.hasTask,
      ),
      (
        ModuleStyle.habits,
        'Start a habit or reminder',
        'Small steps, every day',
        AppRoutes.newHabitPath,
        progress.hasRoutine,
      ),
    ];
    final ff = context.ff;
    return FFCard(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Get started', style: context.text.cardTitle),
                ),
                Text(
                  firstRun
                      ? '${HomeGetStarted.steps} quick steps'
                      : '${progress.doneCount} of ${HomeGetStarted.steps} done',
                  style: context.text.meta,
                ),
              ],
            ),
          ),
          for (final (style, title, body, route, done) in steps)
            FFPressable(
              onTap: () => context.push(route),
              semanticLabel: done ? '$title, done' : title,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    FFIconTile.soft(icon: style.icon, colors: style.colors),
                    const SizedBox(width: AppSpacing.rowLeadingGap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: context.text.rowTitle.copyWith(
                              color: done ? ff.inkFaint : null,
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          Text(body, style: context.text.meta),
                        ],
                      ),
                    ),
                    Icon(
                      done
                          ? FontAwesomeIcons.solidCircleCheck
                          : FontAwesomeIcons.chevronRight,
                      size: AppSizes.tileGlyph,
                      color: done ? ff.primary : ff.inkFaint,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
