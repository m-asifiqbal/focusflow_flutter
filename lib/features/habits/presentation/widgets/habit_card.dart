/// ============================================================
/// HABIT CARD — one habit on the habits list (mockup 14)
/// ============================================================
///
///   [ring 50 + icon]  Name                       [+ / ✓]
///                     6 / 8 glasses · Completed · Mon · Wed · Fri
///   ─────────────────────────────────────────────────────────
///   M T W T F S S                                 🔥 12 days
///
/// Pure view over a [HabitDayStatus]: the list screen passes the
/// callbacks (tap → detail, long-press → actions sheet, button → check-in).
/// Rest days and paused habits are dimmed (the button still works so a
/// bonus day can be logged).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/ff_card.dart';
import 'package:focusflow/core/widgets/ff_progress_ring.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/services/streak_calculator.dart';
import 'package:focusflow/features/habits/presentation/habit_icons.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/features/habits/presentation/widgets/habit_check_button.dart';
import 'package:focusflow/features/habits/presentation/widgets/habit_week_squares.dart';

class HabitCard extends StatelessWidget {
  const HabitCard({
    required this.status,
    this.onTap,
    this.onLongPress,
    this.onCheck,
    this.onCheckLongPress,
    super.key,
  });

  final HabitDayStatus status;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Null hides the button (archived habits).
  final VoidCallback? onCheck;
  final VoidCallback? onCheckLongPress;

  /// Opacity of rest-day / paused content.
  static const double dimmed = 0.5;

  /// The button's spoken action for [s].
  static String checkLabel(HabitDayStatus s) {
    final name = s.habit.name;
    if (s.habit.isQuit) {
      return s.isDone
          ? tr('Log a slip for {name}', {'name': name})
          : tr('Mark {name} clean today', {'name': name});
    }
    if (s.isDone) {
      return s.habit.isYesNo
          ? tr('Mark {name} not done', {'name': name})
          : tr('Undo a {name} check-in', {'name': name});
    }
    return s.habit.isYesNo
        ? tr('Mark {name} done', {'name': name})
        : tr('Check in {name}', {'name': name});
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final habit = status.habit;
    final colors = habit.colors;
    final brightness = Theme.of(context).brightness;
    final dim = !status.isScheduled || habit.isPaused;

    final header = Row(
      children: [
        FFProgressRing(
          progress: status.progress,
          size: HabitDimens.cardRing,
          stroke: HabitDimens.cardRingStroke,
          color: colors.solid,
          trackColor: colors.softFor(brightness),
          semanticLabel: tr('{name} progress', {'name': habit.name}),
          child: Icon(
            HabitIcons.of(habit.iconKey),
            size: HabitDimens.cardIcon,
            color: colors.solid,
          ),
        ),
        const SizedBox(width: HabitDimens.ringTextGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                habit.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.cardTitle.copyWith(color: ff.ink),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                status.progressLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall.copyWith(
                  fontSize: HabitDimens.cardSubtitle,
                  color: ff.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return FFCard(
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: '${habit.name}, ${status.progressLabel}',
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Opacity(opacity: dim ? dimmed : 1, child: header),
              ),
              if (onCheck != null) ...[
                const SizedBox(width: AppSpacing.md),
                HabitCheckButton(
                  done: status.isDone,
                  colors: colors,
                  semanticLabel: checkLabel(status),
                  onTap: onCheck!,
                  onLongPress: onCheckLongPress,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
          Divider(height: 1, thickness: 1, color: ff.divider),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              HabitWeekSquares(week: status.week, colors: colors),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _Streak(streak: status.streak),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "🔥 12 days" (or "🔥 3 weeks" for N× per week habits) in the streak
/// orange.
class _Streak extends StatelessWidget {
  const _Streak({required this.streak});

  final HabitStreak streak;

  @override
  Widget build(BuildContext context) {
    final color = HabitAccents.streak;
    return Semantics(
      label: tr('Streak: {label}', {'label': streak.label}),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FontAwesomeIcons.fire,
            size: HabitDimens.streakIcon,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              streak.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.meta.copyWith(
                fontSize: HabitDimens.streakText,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
