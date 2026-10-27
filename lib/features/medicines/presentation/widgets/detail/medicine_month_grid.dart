/// ============================================================
/// MEDICINE MONTH GRID — one month of doses as a calendar (detail)
/// ============================================================
///
/// Weekday initials, then one cell per day (weeks start on the user's
/// week-start setting): the date over a dot per scheduled dose — filled =
/// taken, red = missed, slate = skipped, faint ring = still to come. Today's
/// date sits on a coloured disc. Days after today show only their date.
/// Why not reuse the week grid: that one is columns = days; a month needs the
/// calendar shape. Cells are plain widgets (≤ 42), no per-cell animation.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_stats.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';

/// Blank cells before the 1st so it lands under its weekday.
int leadingBlanks(DateTime firstOfMonth, int weekStart) =>
    (firstOfMonth.weekday - weekStart + 7) % 7;

/// The mini dot of one dose (filled; a ring while still to come).
BoxDecoration miniDoseDot(BuildContext context, DoseState s) {
  final ff = context.ff;
  return switch (s) {
    DoseState.taken => BoxDecoration(color: ff.success, shape: BoxShape.circle),
    DoseState.missed => BoxDecoration(color: ff.danger, shape: BoxShape.circle),
    DoseState.skipped => BoxDecoration(
      color: ActionTints.lock.solid,
      shape: BoxShape.circle,
    ),
    DoseState.due || DoseState.snoozed => BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: MedicineStyle.colors.solid),
    ),
    DoseState.upcoming => BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: ff.inkFaint),
    ),
  };
}

class MedicineMonthGrid extends StatelessWidget {
  const MedicineMonthGrid({
    required this.days,
    required this.today,
    required this.weekStart,
    super.key,
  });

  /// Every day of the month, the 1st first (never empty).
  final List<MedicineWeekDay> days;
  final DateTime today;
  final int weekStart;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final lead = leadingBlanks(days.first.day, weekStart);
    final slots = <MedicineWeekDay?>[
      for (var i = 0; i < lead; i++) null,
      ...days,
    ];
    while (slots.length % 7 != 0) {
      slots.add(null);
    }
    final labelStyle = context.text.sectionLabel.copyWith(color: ff.inkFaint);
    return Column(
      children: [
        Row(
          children: [
            for (final l in DateUtilsX.weekdayInitials(weekStart))
              Expanded(
                child: Text(l, textAlign: TextAlign.center, style: labelStyle),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var r = 0; r < slots.length ~/ 7; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: _Cell(day: slots[r * 7 + c], today: today),
                ),
            ],
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.day, required this.today});

  final MedicineWeekDay? day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final d = day;
    const height = BoxConstraints(minHeight: MedicineSizes.monthCell);
    if (d == null) return ConstrainedBox(constraints: height);
    final ff = context.ff;
    final colors = MedicineStyle.colors;
    final isToday = DateUtilsX.isSameDay(d.day, today);
    final future = d.day.isAfter(today);
    final taken = d.states.where((s) => s == DoseState.taken).length;
    final label = tr('{date}: {taken} of {total} doses taken', {
      'date': DateFormats.of('MMMM d').format(d.day),
      'taken': taken,
      'total': d.states.length,
    });
    return Semantics(
      label: d.states.isEmpty && !isToday ? null : label,
      excludeSemantics: d.states.isNotEmpty || isToday,
      child: ConstrainedBox(
        constraints: height,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: AppSpacing.xxs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: MedicineSizes.monthDay,
                height: MedicineSizes.monthDay,
                alignment: Alignment.center,
                decoration: isToday
                    ? BoxDecoration(color: colors.solid, shape: BoxShape.circle)
                    : null,
                child: Text(
                  '${d.day.day}',
                  style: context.text.caption.copyWith(
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    color: isToday
                        ? AppPalette.white
                        : (future ? ff.inkFaint : ff.ink),
                  ),
                ),
              ),
              if (!future && d.states.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: MedicineSizes.monthDotGap,
                  runSpacing: MedicineSizes.monthDotGap,
                  children: [
                    for (final s in d.states)
                      Container(
                        width: MedicineSizes.monthDot,
                        height: MedicineSizes.monthDot,
                        decoration: miniDoseDot(context, s),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
