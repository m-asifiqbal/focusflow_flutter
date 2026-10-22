/// ============================================================
/// HOME HABITS SECTION — "Habit Tracker ……… Trends"
/// ============================================================
///
/// What: a card of progress rings, one per habit of today (habit colour,
/// habit icon inside, name below). Tap a ring = +1 check-in (toggle for
/// yes/no habits) via the habits lane's check-in flow; long-press opens
/// the habit detail. More than four rings scroll horizontally. Empty:
/// compact empty state with "New habit".
/// Why: the same HabitLogger as the Habits list, so streaks, haptics and
/// quit-habit slips behave identically everywhere.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/presentation/habit_check_in_actions.dart';
import 'package:focusflow/features/habits/presentation/habit_icons.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/features/habits/presentation/providers/habits_providers.dart';
import 'package:focusflow/features/home/domain/services/home_focus.dart';
import 'package:focusflow/features/home/presentation/home_tokens.dart';
import 'package:focusflow/features/home/presentation/widgets/home_section_states.dart';
import 'package:go_router/go_router.dart';
import 'package:focusflow/features/home/presentation/widgets/home_section_link.dart';

class HomeHabitsSection extends ConsumerWidget {
  const HomeHabitsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(todayHabitsProvider);
    // The habit day rolls at midnight (a reload): keep the rings meanwhile.
    final Widget body = habits.when(
      skipLoadingOnReload: true,
      error: (_, _) =>
          HomeErrorCard(onRetry: () => ref.invalidate(todayHabitsProvider)),
      loading: () => const FFSkeletonList(count: 1),
      data: (value) => value.isEmpty
          ? HomeEmptyCard(
              colors: ModuleStyle.habits.colors,
              icon: ModuleStyle.habits.icon,
              title: tr('No habits yet'),
              body: tr('Build a routine one small step at a time.'),
              ctaLabel: tr('New habit'),
              onCta: () => context.push(AppRoutes.newHabitPath),
            )
          : _RingsCard(habits: value),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionHeader(
          title: tr('Habit Tracker'),
          trailing: HomeSectionLink(
            tr('Trends'),
            onPressed: () => context.go(AppRoutes.insights),
          ),
        ),
        const SizedBox(height: HomeDimens.linkHeaderGap),
        body,
      ],
    );
  }
}

class _RingsCard extends StatelessWidget {
  const _RingsCard({required this.habits});

  final List<HabitDayStatus> habits;

  @override
  Widget build(BuildContext context) {
    final fits = habits.length <= HomeRules.habitRings;
    return FFCard(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xl,
      ),
      child: fits
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final s in habits)
                  Expanded(
                    child: _HabitRing(key: ValueKey(s.habit.id), status: s),
                  ),
              ],
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in habits)
                    SizedBox(
                      width: HomeDimens.ringCellMin + AppSpacing.md,
                      child: _HabitRing(key: ValueKey(s.habit.id), status: s),
                    ),
                ],
              ),
            ),
    );
  }
}

class _HabitRing extends ConsumerWidget {
  const _HabitRing({required this.status, super.key});

  final HabitDayStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final habit = status.habit;
    final colors = habit.colors;
    final percent = (status.progress * 100).round();
    final done = status.isDone;

    return Semantics(
      button: true,
      label: done
          ? tr('{name}, done', {'name': habit.name})
          : tr('{name}, {n} percent', {'name': habit.name, 'n': percent}),
      hint: habit.isYesNo ? tr('Toggle today') : tr('Log one more'),
      onLongPressHint: tr('Open habit'),
      excludeSemantics: true,
      child: FFPressable(
        onTap: () => checkInHabit(context, ref, status),
        onLongPress: () => context.push(AppRoutes.habit(habit.id)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FFProgressRing(
              progress: status.progress,
              size: HomeDimens.ring,
              stroke: HomeDimens.ringStroke,
              color: colors.solid,
              trackColor: ff.surfaceMuted,
              child: Container(
                width: HomeDimens.ring - HomeDimens.ringStroke * 2,
                height: HomeDimens.ring - HomeDimens.ringStroke * 2,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? colors.softFor(ff.brightness) : null,
                ),
                child: Icon(
                  HabitIcons.of(habit.iconKey),
                  size: HomeDimens.ringIcon,
                  color: colors.solid,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              habit.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.text.rowTitle.copyWith(
                fontSize: HomeDimens.ringLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
