/// ============================================================
/// MEDICINE GANTT CARD — "Medicine timeline" of Insights › Medicine
/// ============================================================
///
/// What: one bar per medicine over the selected period (7 or 30 days, or
/// 12 months): from the day the course started (or the period's first day)
/// to the day it ended / was archived (or the period's last day). The bar is
/// coloured by adherence like "By medicine" (green ≥ 90 %, amber ≥ 70 %,
/// red below); a flat edge means the course began before / continues after
/// the period. Tap a row to open the medicine.
/// Why: the other cards say how well doses went; this one says *when* each
/// course ran and which ones overlapped. It only reads
/// [MedicineInsights.perMedicine], so it adds no query or computation.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_insights.dart';
import 'package:focusflow/features/medicines/presentation/widgets/insights/medicine_insight_parts.dart';
import 'package:go_router/go_router.dart';

/// Where a medicine's course sits on the period's axis.
@immutable
class MedicineGanttSpan {
  const MedicineGanttSpan(this.start, this.end, this.before, this.after);

  /// First / last axis cell covered (inclusive, inside the axis).
  final int start;
  final int end;

  /// The course began before the period / goes on after it.
  final bool before;
  final bool after;
}

/// Cells on the axis of [i]: days (Daily, Monthly) or months (Yearly).
int medicineAxisUnits(MedicineInsights i) => i.period == MedicinePeriod.yearly
    ? 12
    : DateUtilsX.daysBetween(i.start, i.end);

/// The axis cell of [day] (can be outside 0…units-1).
int _unitOf(MedicineInsights i, DateTime day) =>
    i.period == MedicinePeriod.yearly
    ? (day.year - i.start.year) * 12 + day.month - i.start.month
    : DateUtilsX.daysBetween(i.start, DateUtilsX.dateOnly(day));

/// The span of [m] inside [i]'s period, or null when it doesn't overlap.
MedicineGanttSpan? medicineGanttSpan(Medicine m, MedicineInsights i) {
  final last = medicineAxisUnits(i) - 1;
  final from = _unitOf(i, m.startDate);
  // The course ends with its end date or when it was archived, whichever
  // comes first; none of them = still going.
  final stops = [?m.endDate, ?m.archivedAt];
  final stop = stops.isEmpty
      ? null
      : _unitOf(i, stops.reduce((a, b) => a.isBefore(b) ? a : b));
  final start = from < 0 ? 0 : from;
  final end = stop == null || stop > last ? last : stop;
  if (start > last || end < start) return null;
  return MedicineGanttSpan(start, end, from < 0, stop == null || stop > last);
}

/// Axis labels: weekday initials (7 days), every 5th day (30 days) or month
/// initials (12 months).
List<FFGanttTick> medicineAxisTicks(MedicineInsights i) {
  final n = medicineAxisUnits(i);
  switch (i.period) {
    case MedicinePeriod.daily:
      final f = DateFormats.of('EEEEE');
      return [
        for (var u = 0; u < n; u++)
          FFGanttTick(u, f.format(DateUtilsX.addDays(i.start, u))),
      ];
    case MedicinePeriod.monthly:
      final f = DateFormats.of('d');
      return [
        for (var u = 0; u < n; u += 5)
          FFGanttTick(u, f.format(DateUtilsX.addDays(i.start, u))),
      ];
    case MedicinePeriod.yearly:
      final f = DateFormats.of('MMMMM');
      return [
        for (var u = 0; u < n; u++)
          FFGanttTick(u, f.format(DateTime(i.start.year, i.start.month + u))),
      ];
  }
}

class MedicineGanttCard extends StatelessWidget {
  const MedicineGanttCard({required this.insights, super.key});

  final MedicineInsights insights;

  @override
  Widget build(BuildContext context) {
    final rows = <(Medicine, MedicineShare, MedicineGanttSpan)>[];
    for (final share in insights.perMedicine) {
      final span = medicineGanttSpan(share.medicine, insights);
      if (span != null) rows.add((share.medicine, share, span));
    }
    // Oldest course first, like a project plan.
    rows.sort((a, b) {
      final c = a.$3.start.compareTo(b.$3.start);
      return c != 0 ? c : a.$1.name.compareTo(b.$1.name);
    });
    final palette = FFGantt.palette(context);
    final bars = <FFGanttBar>[
      for (final (i, (m, share, span)) in rows.indexed)
        _bar(context, m, share, span, palette[i % palette.length]),
    ];
    return MedicineInsightCard(
      title: tr('Medicine timeline'),
      caption: tr('When each medicine ran, with its adherence'),
      child: FFGantt(
        bars: bars,
        units: medicineAxisUnits(insights),
        ticks: medicineAxisTicks(insights),
        todayUnit: medicineAxisUnits(insights) - 1,
      ),
    );
  }

  static FFGanttBar _bar(
    BuildContext context,
    Medicine m,
    MedicineShare share,
    MedicineGanttSpan span,
    Color rowColor,
  ) {
    final ff = context.ff;
    final c = share.counts;
    final a = c.adherence;
    // The % keeps the traffic-light colour; the bar has the row's own.
    final color = a == null
        ? ff.inkMuted
        : (a >= 0.9 ? ff.success : (a >= 0.7 ? ff.warning : ff.danger));
    final name = m.name.trim().isEmpty ? tr('Untitled medicine') : m.name;
    final percent = a == null ? null : '${(a * 100).round()}%';
    return FFGanttBar(
      label: m.isPaused ? '$name · ${tr('Paused')}' : name,
      trailing: percent,
      trailingColor: color,
      startUnit: span.start,
      endUnit: span.end,
      color: m.isPaused ? rowColor.withValues(alpha: 0.5) : rowColor,
      semanticLabel: tr('{name}: {percent} taken, {taken} of {total}', {
        'name': name,
        'percent': percent ?? '—',
        'taken': c.taken,
        'total': c.total,
      }),
      onTap: () => context.push(AppRoutes.medicine(m.id)),
    );
  }
}
