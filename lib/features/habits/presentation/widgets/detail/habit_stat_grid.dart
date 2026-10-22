/// ============================================================
/// HABIT STAT GRID — the 2×2 stat cards of the habit detail (16)
/// ============================================================
///
/// Current streak (orange, 🔥), Best streak (indigo) — in days, or weeks
/// for N× per week habits — Completion over the
/// last 30 days (emerald) and Total check-ins (blue). Surface cards with
/// a spaced caps label, a big coloured value and a muted unit line.
/// [empty] shows dashes for a habit without any check-in yet.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/services/habit_stats_calculator.dart';
import 'package:focusflow/features/habits/presentation/habit_format.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';

class HabitStatGrid extends StatelessWidget {
  const HabitStatGrid({
    required this.habit,
    required this.stats,
    this.empty = false,
    super.key,
  });

  final Habit habit;
  final HabitStats stats;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    String v(String s) => empty ? '–' : s;
    // Days, or weeks for N× per week habits (StreakUnit).
    final streak = stats.streak;
    final tiles = [
      _StatCard(
        label: tr('Current streak'),
        value: v('${streak.current}'),
        unit: streak.unitWord(streak.current),
        color: HabitAccents.streak,
        fire: streak.current > 0,
      ),
      _StatCard(
        label: tr('Best streak'),
        value: v('${streak.best}'),
        unit: streak.unitWord(streak.best),
        color: HabitPalette.indigo.solid,
      ),
      _StatCard(
        label: tr('Completion'),
        value: v(HabitFormat.percent(stats.completionRate)),
        unit: tr('{days, plural, one {last # day} other {last # days}}', {
          'days': stats.completionDays,
        }),
        color: HabitPalette.emerald.solid,
      ),
      _StatCard(
        label: tr('Total'),
        value: v('${stats.totalCheckIns}'),
        unit: habit.isQuit ? tr('clean days') : tr('check-ins'),
        color: HabitPalette.blue.solid,
      ),
    ];
    // Every card has the same three single-line rows, so a pair is
    // always the same height.
    Widget row(int i) => Row(
      children: [
        Expanded(child: tiles[i]),
        const SizedBox(width: AppSpacing.cardGap),
        Expanded(child: tiles[i + 1]),
      ],
    );
    return Column(
      children: [
        row(0),
        const SizedBox(height: AppSpacing.cardGap),
        row(2),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.fire = false,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;
  final bool fire;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      container: true,
      label: '$label: $value $unit',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: HabitDimens.statTileHeight,
        ),
        child: FFCard(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg + AppSpacing.xxs,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.md + AppSpacing.xxs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.sectionLabel.copyWith(letterSpacing: 1),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                maxLines: 1,
                style: context.text.bigStat.copyWith(
                  fontSize: HabitDimens.statValue,
                  color: color,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      unit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.meta.copyWith(
                        fontSize: HabitDimens.statUnit,
                        color: ff.inkFaint,
                      ),
                    ),
                  ),
                  if (fire) ...[
                    const SizedBox(width: AppSpacing.xs + 1),
                    Icon(
                      FontAwesomeIcons.fire,
                      size: HabitDimens.streakIcon,
                      color: HabitAccents.streak,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
