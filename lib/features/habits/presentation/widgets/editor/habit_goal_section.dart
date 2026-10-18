/// ============================================================
/// HABIT GOAL SECTION — "GOAL & SCHEDULE" of the habit editor (15)
/// ============================================================
///
/// Daily target stepper + editable unit (build habits), the Frequency
/// picker (Every day · Specific days · X times per week · Every N days)
/// and, below it, the weekday circles (M–S, from Settings › week start) or
/// the per-week / every-N-days stepper. Quit habits count every day (the
/// schedule services ignore their frequency), so for them the section only
/// explains that instead of offering a schedule that would do nothing.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/features/habits/presentation/notifiers/habit_editor_controller.dart';
import 'package:focusflow/features/habits/presentation/providers/habits_providers.dart';
import 'package:focusflow/features/habits/presentation/widgets/editor/habit_editor_sheets.dart';
import 'package:focusflow/features/habits/presentation/widgets/editor/habit_stepper.dart';

class HabitGoalSection extends ConsumerWidget {
  const HabitGoalSection({required this.args, required this.draft, super.key});

  final HabitEditorArgs args;
  final Habit draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final c = ref.read(habitEditorControllerProvider(args).notifier);
    final weekStart = ref.watch(habitWeekStartProvider);
    final frequency = draft.frequency;
    final title = context.text.rowTitle.copyWith(
      fontSize: HabitDimens.editorRowTitle,
    );

    if (draft.isQuit) {
      return FFGroupedList(
        label: 'Goal & schedule',
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Text(
              'Quit habits count every day. Log a slip when it happens; '
              'a day without slips keeps your streak going.',
              style: context.text.body.copyWith(color: ff.inkMuted),
            ),
          ),
        ],
      );
    }

    Future<void> editUnit() async {
      final v = await showHabitTextSheet(
        context,
        title: 'Unit',
        initial: draft.unit,
        hint: 'glasses, min, pages…',
        maxLength: 20,
      );
      if (v != null) c.setUnit(v);
    }

    Future<void> pickFrequency() async {
      final v = await showHabitOptionSheet<HabitFrequencyKind>(
        context,
        title: 'Frequency',
        selected: HabitFrequencyKind.of(frequency),
        options: [
          for (final k in HabitFrequencyKind.values) HabitOption(k, k.label),
        ],
      );
      if (v != null) c.setFrequencyKind(v);
    }

    Widget pad(Widget child) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: child,
    );

    final schedule = switch (frequency) {
      TimesPerWeekFrequency(:final times) => _StepRow(
        label: 'Times per week',
        stepper: HabitStepper(
          value: times,
          min: 1,
          max: 7,
          semanticLabel: 'Times per week',
          onChanged: c.setTimesPerWeek,
        ),
      ),
      EveryNDaysFrequency(:final days) => _StepRow(
        label: 'Every',
        trailing: 'days',
        stepper: HabitStepper(
          value: days,
          min: 2,
          max: 30,
          semanticLabel: 'Days between check-ins',
          onChanged: c.setEveryNDays,
        ),
      ),
      _ => _WeekdayCircles(
        mask: switch (frequency) {
          SpecificDaysFrequency(:final weekdaysMask) => weekdaysMask,
          _ => 0x7F,
        },
        weekStart: weekStart,
        onToggle: c.toggleWeekday,
      ),
    };

    return FFGroupedList(
      label: 'Goal & schedule',
      dividerIndent: 0,
      children: [
        pad(
          Row(
            children: [
              Expanded(
                child: Text(
                  'Daily target',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: title.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              HabitStepper(
                value: draft.targetCount,
                min: HabitEditorController.minTarget,
                max: HabitEditorController.maxTarget,
                semanticLabel: 'Daily target',
                onChanged: c.setTarget,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: HabitDimens.unitMaxWidth,
                ),
                child: Semantics(
                  button: true,
                  label: 'Unit, ${draft.unit}',
                  excludeSemantics: true,
                  child: FFPressable(
                    onTap: editUnit,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppSizes.minTap,
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: AppSpacing.xs,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          widthFactor: 1,
                          child: Text(
                            draft.unit,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.body.copyWith(
                              fontSize: HabitDimens.editorRowTitle,
                              color: ff.inkFaint,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Frequency',
                    style: title.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FFTextButton(
                        label: frequency.label,
                        onPressed: pickFrequency,
                        semanticLabel: 'Frequency, ${frequency.label}',
                        padding: EdgeInsetsDirectional.zero,
                        style: context.text.button.copyWith(
                          fontSize: HabitDimens.frequencyValue,
                          fontWeight: FontWeight.w600,
                          color: ff.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? FontAwesomeIcons.chevronLeft
                        : FontAwesomeIcons.chevronRight,
                    size: AppSpacing.md + AppSpacing.xxs,
                    color: ff.primary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              schedule,
              if (frequency is SpecificDaysFrequency &&
                  frequency.weekdaysMask & 0x7F == 0)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
                  child: Text(
                    'Pick at least one day',
                    style: context.text.meta.copyWith(color: ff.danger),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.stepper, this.trailing});

  final String label;
  final Widget stepper;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: context.text.body.copyWith(height: 1.2)),
        ),
        stepper,
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(trailing!, style: context.text.body.copyWith(height: 1.2)),
        ],
      ],
    );
  }
}

class _WeekdayCircles extends StatelessWidget {
  const _WeekdayCircles({
    required this.mask,
    required this.weekStart,
    required this.onToggle,
  });

  final int mask;
  final int weekStart;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final days = [for (var i = 0; i < 7; i++) (weekStart - 1 + i) % 7 + 1];
    // 2026-06-01 is a Monday: weekday d → a date with that weekday.
    String name(int d, String pattern) =>
        DateFormats.of(pattern).format(DateTime(2026, 6, d));
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = ((constraints.maxWidth - HabitDimens.weekdayGap * 6) / 7)
            .clamp(0.0, HabitDimens.weekdayCircle);
        // Each day owns a full seventh of the row (> 44 pt wide at the
        // design width) and the 44-pt tap height. Inside its slot the
        // circle is aligned start → end (−1 … +1) so the circles still
        // span the row edge to edge, as in the mockup.
        return Row(
          children: [
            for (final (i, d) in days.indexed)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: HabitFrequency.maskHas(mask, d),
                  label: name(d, 'EEEE'),
                  excludeSemantics: true,
                  child: FFPressable(
                    onTap: () => onToggle(d),
                    child: SizedBox(
                      height: AppSizes.minTap,
                      child: Align(
                        alignment: AlignmentDirectional(i / 3 - 1, 0),
                        child: AnimatedContainer(
                          duration: context.motion(AppMotion.fast),
                          width: size,
                          height: size,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: HabitFrequency.maskHas(mask, d)
                                ? ff.primary
                                : ff.surface,
                            border: Border.all(
                              color: HabitFrequency.maskHas(mask, d)
                                  ? ff.primary
                                  : ff.ink.withValues(alpha: 0.12),
                              width: 1,
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              name(d, 'EEEEE'),
                              style: context.text.button.copyWith(
                                fontSize: HabitDimens.weekdayLetter,
                                color: HabitFrequency.maskHas(mask, d)
                                    ? ff.onPrimary
                                    : ff.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
