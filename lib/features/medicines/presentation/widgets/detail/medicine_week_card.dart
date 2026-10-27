/// ============================================================
/// MEDICINE WEEK CARD — "This week": one dot per dose, last 7 days
/// ============================================================
///
/// Columns are days (oldest first, today highlighted), rows are the day's
/// doses: filled = taken, red ring = missed, slate ring = skipped, faint
/// ring = still to come, a dash = nothing scheduled. Dots pop in one after
/// another the first time the card shows (not with reduce motion).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_stats.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';

class MedicineWeekCard extends StatelessWidget {
  const MedicineWeekCard({required this.week, super.key});

  final List<MedicineWeekDay> week;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FFSectionHeader(title: tr('This week')),
      const SizedBox(height: AppSpacing.md),
      FFCard(child: MedicineWeekGrid(week: week)),
    ],
  );
}

/// The 7-day dot grid with its legend (no card around it), so the calendar
/// card can host it next to the Month and Year views.
class MedicineWeekGrid extends StatelessWidget {
  const MedicineWeekGrid({required this.week, super.key});

  final List<MedicineWeekDay> week;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final rows = week.fold<int>(
      0,
      (a, d) => d.states.length > a ? d.states.length : a,
    );
    final today = week.isEmpty ? null : week.last.day;
    return Column(
      children: [
        Row(
          children: [
            for (final d in week)
              Expanded(
                child: Text(
                  DateFormats.of('EEEEE').format(d.day),
                  textAlign: TextAlign.center,
                  style: context.text.sectionLabel.copyWith(
                    color: d.day == today
                        ? MedicineStyle.colors.inkFor(ff.brightness)
                        : ff.inkFaint,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var r = 0; r < (rows == 0 ? 1 : rows); r++)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: MedicineSizes.weekDotGap,
            ),
            child: Row(
              children: [
                for (var i = 0; i < week.length; i++)
                  Expanded(
                    child: Center(
                      child: _Dot(
                        state: r < week[i].states.length
                            ? week[i].states[r]
                            : null,
                        delay: i,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        const MedicineDoseLegend(),
      ],
    );
  }
}

/// Taken · Missed · Skipped · To come key, shared by every calendar view.
class MedicineDoseLegend extends StatelessWidget {
  const MedicineDoseLegend({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: AppSpacing.lg,
    runSpacing: AppSpacing.xs,
    children: [
      _Legend(DoseState.taken, tr('Taken')),
      _Legend(DoseState.missed, tr('Missed')),
      _Legend(DoseState.skipped, tr('Skipped')),
      _Legend(DoseState.upcoming, tr('To come')),
    ],
  );
}

/// The dot of one dose in the state [s] (null = nothing scheduled).
BoxDecoration doseDotDecoration(BuildContext context, DoseState? s) {
  final ff = context.ff;
  final solid = MedicineStyle.colors.solid;
  return switch (s) {
    // Taken is green (success) in every calendar view, not the pink of the
    // module: green reads as "done" at a glance.
    DoseState.taken => BoxDecoration(color: ff.success, shape: BoxShape.circle),
    DoseState.missed => BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: ff.danger, width: AppSizes.hairline + 1),
    ),
    DoseState.skipped => BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: ActionTints.lock.solid,
        width: AppSizes.hairline + 1,
      ),
    ),
    null => const BoxDecoration(),
    // Due now (or snoozed): a ring in the medicine colour.
    DoseState.due || DoseState.snoozed => BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: solid, width: AppSizes.hairline + 1),
    ),
    _ => BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: ff.inkFaint, width: AppSizes.hairline),
    ),
  };
}

class _Dot extends StatelessWidget {
  const _Dot({required this.state, required this.delay});

  final DoseState? state;

  /// Column of the dot: columns pop in left to right.
  final int delay;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final dot = state == null
        ? Container(
            width: MedicineSizes.weekDot,
            height: AppSizes.hairline,
            color: ff.divider,
          )
        : Container(
            width: MedicineSizes.weekDot,
            height: MedicineSizes.weekDot,
            decoration: doseDotDecoration(context, state),
          );
    if (context.reduceMotion) return dot;
    final ms = AppMotion.slow.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      // Staggered: each dot starts a little after the previous one.
      duration: Duration(milliseconds: ms + delay * 40),
      curve: Interval(
        (delay * 40) / (ms + delay * 40),
        1,
        curve: Curves.easeOutBack,
      ),
      child: dot,
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.state, this.label);

  final DoseState state;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: MedicineSizes.weekDot - 2,
        height: MedicineSizes.weekDot - 2,
        decoration: doseDotDecoration(context, state),
      ),
      const SizedBox(width: AppSpacing.xs),
      Text(label, style: context.text.caption),
    ],
  );
}
