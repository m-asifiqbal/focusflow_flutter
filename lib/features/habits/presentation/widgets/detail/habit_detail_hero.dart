/// ============================================================
/// HABIT DETAIL HERO — big ring, name, meta and the two buttons (16)
/// ============================================================
///
/// 132-pt ring in the habit colour (track = soft tint) around the icon
/// and today's value ("6/8"), the name, "Health · Weekdays · 8 glasses",
/// then "+ Log 1 glass" (habit colour, glow) and "Skip today" (surface).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/presentation/habit_format.dart';
import 'package:focusflow/features/habits/presentation/habit_icons.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';

class HabitDetailHero extends StatelessWidget {
  const HabitDetailHero({
    required this.habit,
    required this.todayLog,
    required this.progress,
    required this.onLog,
    required this.onSkip,
    super.key,
  });

  final Habit habit;
  final HabitLog? todayLog;

  /// 0…1 ring progress of today.
  final double progress;
  final VoidCallback? onLog;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final colors = habit.colors;
    final done = habit.isDoneWith(todayLog);
    final skipped = todayLog?.skipped ?? false;
    final ringValue = HabitFormat.ring(habit, todayLog);
    final meta = [
      if (habit.isPaused) tr('Paused'),
      if (habit.isArchived) tr('Archived'),
      HabitFormat.meta(habit),
    ].join(' · ');

    return Column(
      children: [
        FFProgressRing(
          progress: progress,
          size: HabitDimens.detailRing,
          stroke: HabitDimens.detailRingStroke,
          color: colors.solid,
          trackColor: colors.softFor(ff.brightness),
          semanticLabel: tr('Today {name}: {ringValue}', {
            'name': habit.name,
            'ringValue': ringValue,
          }),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                HabitIcons.of(habit.iconKey),
                size: HabitDimens.detailRingIcon,
                color: colors.solid,
              ),
              const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    ringValue,
                    style: context.text.bigStat.copyWith(
                      fontSize: HabitDimens.detailRingValue,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Semantics(
          header: true,
          child: Text(
            habit.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.title.copyWith(
              fontSize: HabitDimens.detailName,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          meta,
          textAlign: TextAlign.center,
          style: context.text.bodySmall.copyWith(
            color: ff.inkFaint,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _ActionButton(
              label: HabitFormat.logButton(habit, doneToday: done),
              icon: habit.isYesNo && done && !habit.isQuit
                  ? FontAwesomeIcons.check
                  : FontAwesomeIcons.plus,
              background: colors.solid,
              foreground: HabitAccents.onColor,
              shadow: HabitAccents.buttonGlow(colors.solid, dark: ff.isDark),
              onTap: onLog,
            ),
            _ActionButton(
              label: skipped ? tr('Unskip') : tr('Skip today'),
              icon: skipped
                  ? FontAwesomeIcons.rotateLeft
                  : FontAwesomeIcons.forward,
              background: ff.surface,
              foreground: ff.inkMuted,
              border: ff.surfaceBorder,
              shadow: ff.cardShadow,
              onTap: onSkip,
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.border,
    this.shadow = const [],
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color? border;
  final List<BoxShadow> shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: HabitDimens.actionButtonHeight,
              minWidth: HabitDimens.actionButtonMinWidth,
            ),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppRadii.button),
              border: border == null ? null : Border.all(color: border!),
              boxShadow: shadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: HabitDimens.actionIcon, color: foreground),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.button.copyWith(
                      fontSize: HabitDimens.actionLabel,
                      color: foreground,
                    ),
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
