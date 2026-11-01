/// ============================================================
/// PRAYER PROGRESS GRIDS — the Week, Month and Year views
/// ============================================================
///
/// * [PrayerWeekGrid] — the last 7 days: one row per prayer, one rounded
///   cell per day coloured by what happened.
/// * [PrayerMonthView] — a calendar month (‹ › to page back): each day's
///   date over a dot per prayer (filled = its outcome, ring = still open);
///   today's date on a disc.
/// * [PrayerYearView] — the last 53 weeks as a heatmap of the share prayed
///   each day ([FFHeatmap]) and each prayer's last 12 months as a bar.
/// [PrayerCellLegend] is the outcome key under Week and Month. Cells are
/// plain widgets (≤ 42 days); the heatmap is one CustomPaint.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_progress_views.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_stats.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/providers/prayer_progress_providers.dart';
import 'package:focusflow/features/prayers/presentation/widgets/progress/prayer_progress_card.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

String _percent(PrayerRate r) =>
    r.rate == null ? '—' : '${(r.rate! * 100).round()}%';

// ──────────────────────────────── Week ───────────────────────────────

class PrayerWeekGrid extends StatelessWidget {
  const PrayerWeekGrid({required this.progress, super.key});

  final PrayerProgress progress;

  static const double _cell = 14;
  static const double _nameWidth = 72;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final days = progress.weekDays;
    final initials = DateFormats.of('EEEEE');
    var week = PrayerRate.zero;
    for (final row in progress.week) {
      for (final c in row.cells) {
        week = week.add(c);
      }
    }
    Widget cell(PrayerCell c) => Container(
      height: _cell,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: PrayerStyle.cell(ff, c),
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrayerViewHeader(
          title: tr('Last 7 days'),
          summary: week.due == 0
              ? null
              : tr('{done} of {total} prayed', {
                  'done': week.done,
                  'total': week.due,
                }),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            const SizedBox(width: _nameWidth),
            for (final d in days)
              Expanded(
                child: Text(
                  initials.format(d),
                  textAlign: TextAlign.center,
                  style: text.meta.copyWith(
                    color: d == days.last ? ff.primary : ff.inkMuted,
                    fontWeight: d == days.last
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final row in progress.week)
          Semantics(
            label: tr('{name}: {done} of {due} days', {
              'name': row.prayer.displayName,
              'done': row.cells
                  .where(
                    (c) =>
                        c == PrayerCell.onTime ||
                        c == PrayerCell.late ||
                        c == PrayerCell.madeUp,
                  )
                  .length,
              'due': row.cells
                  .where((c) => c != PrayerCell.none && c != PrayerCell.pending)
                  .length,
            }),
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: _nameWidth,
                    child: Text(
                      row.prayer.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall.copyWith(fontSize: 12.5),
                    ),
                  ),
                  for (final c in row.cells) Expanded(child: cell(c)),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        const PrayerCellLegend(),
      ],
    );
  }
}

/// The outcome key: on time, late, made up, missed, excused.
class PrayerCellLegend extends StatelessWidget {
  const PrayerCellLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    return ExcludeSemantics(
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          for (final (c, label) in [
            (PrayerCell.onTime, tr('On time')),
            (PrayerCell.late, tr('Late')),
            (PrayerCell.madeUp, tr('Made up')),
            (PrayerCell.missed, tr('Missed')),
            (PrayerCell.excused, tr('Excused')),
          ])
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: PrayerStyle.cell(ff, c),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(label, style: text.meta.copyWith(color: ff.inkMuted)),
              ],
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Month ───────────────────────────────

class PrayerMonthView extends ConsumerWidget {
  const PrayerMonthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(prayerMonthViewProvider);
    if (days == null || days.isEmpty) return const PrayerViewLoading();
    final back = ref.watch(prayerMonthPageProvider);
    final page = ref.read(prayerMonthPageProvider.notifier);
    final weekStart = ref.watch(settingsProvider.select((s) => s.weekStartsOn));
    final today = ref.watch(todayProvider);
    var month = PrayerRate.zero;
    for (final d in days) {
      for (final c in d.cells) {
        month = month.add(c);
      }
    }
    final lead = (days.first.day.weekday - weekStart + 7) % 7;
    final slots = <PrayerMonthDay?>[
      for (var i = 0; i < lead; i++) null,
      ...days,
    ];
    while (slots.length % 7 != 0) {
      slots.add(null);
    }
    final labelStyle = context.text.sectionLabel.copyWith(
      color: context.ff.inkFaint,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrayerViewHeader(
          title: DateFormats.of('MMMM y').format(days.first.day),
          summary: month.due == 0
              ? null
              : '${tr('{done} of {total} prayed', {'done': month.done, 'total': month.due})} · ${_percent(month)}',
          arrows: (
            back: back > page.min ? () => page.step(-1) : null,
            forward: back < 0 ? () => page.step(1) : null,
            backLabel: tr('Previous month'),
            forwardLabel: tr('Next month'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: _MonthCell(day: slots[r * 7 + c], today: today),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        const PrayerCellLegend(),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({required this.day, required this.today});

  final PrayerMonthDay? day;
  final DateTime today;

  static const double _height = 48;
  static const double _date = 24;
  static const double _dot = 6;
  static const double _dotGap = 2;

  @override
  Widget build(BuildContext context) {
    final d = day;
    if (d == null) return const SizedBox(height: _height);
    final ff = context.ff;
    final isToday = DateUtilsX.isSameDay(d.day, today);
    final future = d.day.isAfter(today);
    var rate = PrayerRate.zero;
    for (final c in d.cells) {
      rate = rate.add(c);
    }
    return Semantics(
      label: d.cells.isEmpty
          ? null
          : tr('{date}: {done} of {total} prayed', {
              'date': DateFormats.of('MMMM d').format(d.day),
              'done': rate.done,
              'total': d.cells.length,
            }),
      excludeSemantics: d.cells.isNotEmpty,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _height),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: AppSpacing.xxs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _date,
                height: _date,
                alignment: Alignment.center,
                decoration: isToday
                    ? BoxDecoration(
                        color: PrayerStyle.module.solid,
                        shape: BoxShape.circle,
                      )
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
              if (!future && d.cells.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: _dotGap,
                  runSpacing: _dotGap,
                  children: [
                    for (final c in d.cells)
                      Container(
                        width: _dot,
                        height: _dot,
                        decoration: c == PrayerCell.pending
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: ff.inkFaint),
                              )
                            : BoxDecoration(
                                color: PrayerStyle.cell(ff, c),
                                shape: BoxShape.circle,
                              ),
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

// ──────────────────────────────── Year ───────────────────────────────

class PrayerYearView extends ConsumerWidget {
  const PrayerYearView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(prayerYearViewProvider);
    if (year == null) return const PrayerViewLoading();
    final weekStart = ref.watch(settingsProvider.select((s) => s.weekStartsOn));
    final ff = context.ff;
    final text = context.text;
    final good = ff.success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrayerViewHeader(
          title: tr('Last 12 months'),
          summary: year.isEmpty
              ? null
              : '${tr('{done} of {total} prayed', {'done': year.total.done, 'total': year.total.due})} · ${_percent(year.total)}',
        ),
        const SizedBox(height: AppSpacing.md),
        FFHeatmap(
          values: year.daily,
          end: year.end,
          weeks: PrayerYear.weeks,
          color: good,
          weekStart: weekStart,
          gap: 1,
          semanticLabel: tr(
            'Prayers over the last {weeks} weeks: {done} of {total} prayed',
            {
              'weeks': PrayerYear.weeks,
              'done': year.total.done,
              'total': year.total.due,
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FFHeatmapLegend(color: good, cell: 10),
        ),
        if (year.perPrayer.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          for (final (i, (prayer, rate)) in year.perPrayer.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            Semantics(
              label:
                  '${prayer.displayName}: ${_percent(rate)}, '
                  '${tr('{done} of {total} prayed', {'done': rate.done, 'total': rate.due})}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          prayer.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.rowTitle,
                        ),
                      ),
                      Text(
                        '${rate.done}/${rate.due} · ${_percent(rate)}',
                        style: text.caption.copyWith(
                          color: ff.inkMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: LinearProgressIndicator(
                      value: rate.rate ?? 0,
                      minHeight: PrayerStyle.progressBar,
                      color: PrayerStyle.of(prayer),
                      backgroundColor: PrayerStyle.of(
                        prayer,
                      ).withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        if (year.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
            child: Text(
              tr('Nothing marked in the last 12 months yet.'),
              style: text.body.copyWith(color: ff.inkMuted),
            ),
          ),
      ],
    );
  }
}
