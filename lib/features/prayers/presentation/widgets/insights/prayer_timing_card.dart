/// ============================================================
/// PRAYER TIMING CARD — "When you pray" (a Gantt of the day)
/// ============================================================
///
/// What: one row per prayer on a shared time-of-day axis: a soft bar for
/// its typical window in the period, a solid bar for the middle half of
/// the times it was marked, and a tick at the usual (median) time — with
/// "Usually 1:32 PM" over the bar. Hour lines and labels below every 2,
/// 3 or 6 hours, whatever fits the span. RTL mirrors the axis.
/// Why: the outcome charts say *whether* prayers were kept; this says
/// *when* — early in the window or close to its end.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';
import 'package:focusflow/features/medicines/presentation/widgets/insights/medicine_insight_parts.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_insights.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_timing.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class PrayerTimingCard extends ConsumerWidget {
  const PrayerTimingCard({required this.insights, super.key});

  final PrayerInsights insights;

  /// Whether there is anything to draw.
  static bool hasData(PrayerInsights s) => s.timing.any((t) => t.marks > 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final rows = insights.timing;
    final axis = _Axis.of(rows);
    String at(int m) => DateUtilsX.minutesToTime(m, use24h: use24h);
    return MedicineInsightCard(
      title: tr('When you pray'),
      caption: tr("Each prayer's window and when you usually mark it"),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in rows) ...[
            Semantics(
              label: [
                t.prayer.displayName,
                tr('window {from} to {to}', {
                  'from': at(t.windowStart),
                  'to': at(_endOf(t)),
                }),
                if (t.median case final m?)
                  tr('usually marked at {time}', {'time': at(m)})
                else
                  tr('Not marked yet'),
              ].join(', '),
              excludeSemantics: true,
              child: _Row(
                timing: t,
                axis: axis,
                usually: t.median == null
                    ? tr('Not marked yet')
                    : tr('Usually {time}', {'time': at(t.median!)}),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          ExcludeSemantics(
            child: _AxisLabels(axis: axis, use24h: use24h),
          ),
          const SizedBox(height: AppSpacing.md),
          ExcludeSemantics(
            child: Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.xs,
              children: [
                _Key(label: tr('Prayer window'), style: _KeyStyle.window),
                _Key(label: tr('Most of your marks'), style: _KeyStyle.marks),
                _Key(label: tr('Usual time'), style: _KeyStyle.median),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The end drawn for a window: its end, or an hour after an open start.
int _endOf(PrayerTiming t) => t.windowEnd ?? t.windowStart + 60;

/// The time-of-day range shown, in minutes after midnight, and its ticks.
class _Axis {
  const _Axis(this.lo, this.hi, this.step);

  factory _Axis.of(List<PrayerTiming> rows) {
    var lo = Duration.minutesPerDay * 2, hi = 0;
    for (final t in rows) {
      lo = math.min(lo, math.min(t.windowStart, t.q1 ?? t.windowStart));
      hi = math.max(hi, math.max(_endOf(t), t.q3 ?? 0));
    }
    if (hi <= lo) hi = lo + 60;
    final hours = (hi - lo) / 60;
    final step = (hours <= 8 ? 2 : (hours <= 15 ? 3 : 6)) * 60;
    return _Axis(
      (lo / step).floor() * step,
      math.max((hi / step).ceil() * step, (lo / step).floor() * step + step),
      step,
    );
  }

  final int lo;
  final int hi;
  final int step;

  double x(int m, double width) =>
      ((m - lo) / (hi - lo)).clamp(0.0, 1.0) * width;

  Iterable<int> get ticks sync* {
    for (var t = lo; t <= hi; t += step) {
      yield t;
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.timing, required this.axis, required this.usually});

  final PrayerTiming timing;
  final _Axis axis;
  final String usually;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final t = timing;
    final color = PrayerStyle.of(t.prayer);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t.prayer.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.rowTitle.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                usually,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: text.caption.copyWith(
                  color: t.median == null ? ff.inkFaint : ff.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: InsightsDimens.ganttBar,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              double x(int m) => axis.x(m, w);
              final ws = x(t.windowStart);
              final we = x(_endOf(t));
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final tick in axis.ticks)
                    PositionedDirectional(
                      start: x(tick) - 0.5,
                      top: 0,
                      bottom: 0,
                      width: 1,
                      child: ColoredBox(color: ff.divider),
                    ),
                  PositionedDirectional(
                    start: ws,
                    width: math.max(we - ws, AppSpacing.xs),
                    top: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  ),
                  if (t.q1 != null && t.q3 != null)
                    PositionedDirectional(
                      start: x(t.q1!),
                      width: math.max(
                        x(t.q3!) - x(t.q1!),
                        InsightsDimens.ganttBar - AppSpacing.xs,
                      ),
                      top: AppSpacing.xxs,
                      bottom: AppSpacing.xxs,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                      ),
                    ),
                  if (t.median != null)
                    PositionedDirectional(
                      start: x(t.median!) - InsightsDimens.ganttTick / 2,
                      width: InsightsDimens.ganttTick,
                      top: -AppSpacing.xxs,
                      bottom: -AppSpacing.xxs,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: ff.ink,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.axis, required this.use24h});

  final _Axis axis;
  final bool use24h;

  static const double _labelWidth = 48;

  @override
  Widget build(BuildContext context) {
    final style = context.text.caption.copyWith(color: context.ff.inkFaint);
    final fmt = DateFormats.of(use24h ? 'HH:mm' : 'h a');
    final height = MediaQuery.textScalerOf(
      context,
    ).scale((style.fontSize ?? AppSpacing.md) * 1.5);
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          return Stack(
            children: [
              for (final tick in axis.ticks)
                PositionedDirectional(
                  start: (axis.x(tick, w) - _labelWidth / 2).clamp(
                    0.0,
                    math.max(0.0, w - _labelWidth),
                  ),
                  width: _labelWidth,
                  top: 0,
                  bottom: 0,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      fmt.format(DateUtilsX.atMinutes(DateTime(2000), tick)),
                      maxLines: 1,
                      style: style,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

enum _KeyStyle { window, marks, median }

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.style});

  final String label;
  final _KeyStyle style;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    // Neutral: every row has its own colour.
    final color = ff.inkMuted;
    final swatch = switch (style) {
      _KeyStyle.window => Container(
        width: AppSpacing.lg + AppSpacing.xs,
        height: InsightsDimens.legendDot,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
      _KeyStyle.marks => Container(
        width: AppSpacing.lg,
        height: InsightsDimens.legendDot - AppSpacing.xxs,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
      _KeyStyle.median => Container(
        width: InsightsDimens.ganttTick,
        height: InsightsDimens.legendDot + AppSpacing.xxs,
        decoration: BoxDecoration(
          color: ff.ink,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: context.text.caption),
      ],
    );
  }
}
