/// ============================================================
/// HABIT STREAKS CARD — longest current streaks (mockup 25)
/// ============================================================
///
/// What: up to three rows (habit icon tile, name, bar, "45 d" / "3 w")
/// plus "VIEW ALL" → the habits list. Bars are relative to the longest
/// streak shown (weekly habits weigh 7 days per week). Without habits, a
/// compact empty state invites creating one.
/// Why: units come from HabitStreak, so N× per week habits never show
/// weeks as days.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/presentation/habit_icons.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/features/insights/domain/entities/insights_snapshot.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';
import 'package:go_router/go_router.dart';

class HabitStreaksCard extends StatelessWidget {
  const HabitStreaksCard({
    required this.rows,
    required this.hasHabits,
    super.key,
  });

  final List<StreakRow> rows;
  final bool hasHabits;

  @override
  Widget build(BuildContext context) {
    return FFCard(
      padding: const EdgeInsetsDirectional.fromSTEB(
        InsightsDimens.cardPadding,
        AppSpacing.md,
        InsightsDimens.cardPadding,
        InsightsDimens.cardPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Habit streaks',
                    style: context.text.sectionTitle.copyWith(
                      fontSize: InsightsDimens.cardTitle,
                    ),
                  ),
                ),
              ),
              _ViewAll(onTap: () => context.push(AppRoutes.habits)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!hasHabits || rows.isEmpty)
            FFEmptyState.compact(
              colors: ModuleStyle.habits.colors,
              icon: ModuleStyle.habits.icon,
              title: 'No habits yet',
              body: 'Build a habit to start a streak.',
              ctaLabel: 'New habit',
              onCta: () => context.push(AppRoutes.newHabit()),
            )
          else
            for (final r in rows) _StreakTile(row: r),
        ],
      ),
    );
  }
}

class _ViewAll extends StatelessWidget {
  const _ViewAll({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      button: true,
      label: 'View all habits',
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTap),
          child: Center(
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: ff.primarySoft,
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
              child: Text(
                'VIEW ALL',
                style: context.text.tag.copyWith(
                  fontSize: InsightsDimens.kpiDelta,
                  color: ff.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakTile extends StatelessWidget {
  const _StreakTile({required this.row});

  final StreakRow row;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final colors = HabitPalette.forHex(row.colorHex);
    return Semantics(
      label: '${row.name}, ${InsightsFormat.streakLong(row.streak)} streak',
      button: true,
      excludeSemantics: true,
      child: FFOpenOriginTracker(
        radius: AppRadii.tile,
        child: FFPressable(
          onTap: () => context.push(AppRoutes.habit(row.habitId)),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                FFIconTile.soft(
                  icon: HabitIcons.of(row.iconKey),
                  colors: colors,
                  size: InsightsDimens.streakTile,
                ),
                const SizedBox(width: AppSpacing.rowLeadingGap),
                Expanded(
                  flex: 3,
                  child: Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.rowTitle.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // The bar gives way to the name on narrow / large-text
                // layouts (never wider than in the mockup).
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: InsightsDimens.streakBarWidth,
                      ),
                      child: SizedBox(
                        height: InsightsDimens.streakBar,
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ColoredBox(color: ff.divider),
                              ),
                              FractionallySizedBox(
                                widthFactor: row.progress.clamp(0.0, 1.0),
                                heightFactor: 1,
                                child: ColoredBox(color: colors.solid),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  InsightsFormat.streakShort(row.streak),
                  style: context.text.stat.copyWith(
                    fontSize: InsightsDimens.streakValue,
                    color: colors.inkFor(ff.brightness),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
