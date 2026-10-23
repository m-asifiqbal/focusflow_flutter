/// ============================================================
/// MEDICINE VENN CARD — which kinds of days you had
/// ============================================================
///
/// Three overlapping circles — ON TIME, LATE, MISSED/SKIPPED — and in each
/// region the number of days whose doses ended that way (the centre: days
/// with all three). Drawn with a small CustomPainter (no chart package
/// needed): translucent fills so the overlaps read as overlaps, numbers in
/// the region centres, labels outside the circles. The circles grow in.
/// Below, the plain-language reading of the biggest numbers.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_no_data.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_insights.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';
import 'package:focusflow/features/medicines/presentation/widgets/insights/medicine_insight_parts.dart';

class DoseVennCard extends StatelessWidget {
  const DoseVennCard({required this.insights, super.key});

  final MedicineInsights insights;

  @override
  Widget build(BuildContext context) {
    final v = insights.venn;
    final onTime = DoseOutcome.onTime.color(context);
    final late = DoseOutcome.late.color(context);
    final missed = DoseOutcome.missed.color(context);
    return MedicineInsightCard(
      title: tr('Your days at a glance'),
      caption: tr(
        '{count, plural, one {# day with doses} other {# days with doses}}',
        {'count': v.days},
      ),
      child: v.days == 0
          ? InsightsNoData(message: tr('No doses were due in this period.'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  label: tr(
                    'Venn diagram of days. {a} days all on time, {b} days with a late dose only, {c} days with a missed or skipped dose only, {d} days with several kinds.',
                    {
                      'a': v.onTimeOnly,
                      'b': v.lateOnly,
                      'c': v.missedOnly,
                      'd': v.onTimeLate + v.onTimeMissed + v.lateMissed + v.all,
                    },
                  ),
                  excludeSemantics: true,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: context.reduceMotion ? 1 : 0, end: 1),
                    duration: context.motion(AppMotion.slow * 3),
                    curve: Curves.easeOutBack,
                    builder: (context, t, _) => SizedBox(
                      height: MedicineSizes.vennHeight,
                      child: CustomPaint(
                        painter: _VennPainter(
                          venn: v,
                          grow: t,
                          colors: (onTime, late, missed),
                          labels: (
                            DoseOutcome.onTime.label,
                            DoseOutcome.late.label,
                            tr('Missed / skipped'),
                          ),
                          number: context.text.rowTitle.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.ff.ink,
                          ),
                          label: context.text.caption.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          direction: Directionality.of(context),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _Fact(
                      color: onTime,
                      text: tr(
                        '{count, plural, one {# perfect day} other {# perfect days}}',
                        {'count': v.onTimeOnly},
                      ),
                    ),
                    if (v.lateOnly + v.onTimeLate > 0)
                      _Fact(
                        color: late,
                        text: tr(
                          '{count, plural, one {# day all taken, some late} other {# days all taken, some late}}',
                          {'count': v.lateOnly + v.onTimeLate},
                        ),
                      ),
                    if (v.missedOnly + v.onTimeMissed + v.lateMissed + v.all >
                        0)
                      _Fact(
                        color: missed,
                        text: tr(
                          '{count, plural, one {# day with a dose not taken} other {# days with a dose not taken}}',
                          {
                            'count':
                                v.missedOnly +
                                v.onTimeMissed +
                                v.lateMissed +
                                v.all,
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Text(
      text,
      style: context.text.caption.copyWith(
        color: context.ff.ink,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _VennPainter extends CustomPainter {
  _VennPainter({
    required this.venn,
    required this.grow,
    required this.colors,
    required this.labels,
    required this.number,
    required this.label,
    required this.direction,
  });

  final DoseVenn venn;
  final TextDirection direction;

  /// 0 → 1 as the circles grow in.
  final double grow;
  final (Color, Color, Color) colors;
  final (String, String, String) labels;
  final TextStyle number;
  final TextStyle label;

  @override
  void paint(Canvas canvas, Size size) {
    // Three circles of radius r: two on top, one below, overlapping by
    // about 40 % of a radius.
    // Room for a label line above the top circles and below the bottom
    // one; the three circles span 3.05 radii from top to bottom.
    final labelRoom = AppSpacing.xl + AppSpacing.xs;
    final full = math.min(
      size.width / 3.2,
      (size.height - 2 * labelRoom) / 3.05,
    );
    final r = full * grow;
    if (r <= 0) return;
    final cx = size.width / 2;
    final top = labelRoom + full;
    final dx = r * 0.62;
    final a = Offset(cx - dx, top);
    final b = Offset(cx + dx, top);
    final c = Offset(cx, top + r * 1.05);
    for (final (o, col) in [(a, colors.$1), (b, colors.$2), (c, colors.$3)]) {
      canvas.drawCircle(o, r, Paint()..color = col.withValues(alpha: 0.22));
      canvas.drawCircle(
        o,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppSpacing.xxs
          ..color = col.withValues(alpha: 0.85),
      );
    }
    if (grow < 0.6) return;
    final centre = (a + b + c) / 3;
    void text(String s, Offset at, TextStyle style) {
      final p = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: direction,
        maxLines: 1,
      )..layout();
      p.paint(canvas, at - Offset(p.width / 2, p.height / 2));
    }

    Offset away(Offset o, Offset from, double k) => o + (o - from) * k;
    // Single regions: pushed away from the centre; pairs: between two.
    text('${venn.onTimeOnly}', away(a, centre, 0.55), number);
    text('${venn.lateOnly}', away(b, centre, 0.55), number);
    text('${venn.missedOnly}', away(c, centre, 0.45), number);
    text('${venn.onTimeLate}', away((a + b) / 2, centre, 0.9), number);
    text('${venn.onTimeMissed}', away((a + c) / 2, centre, 0.75), number);
    text('${venn.lateMissed}', away((b + c) / 2, centre, 0.75), number);
    text('${venn.all}', centre, number);
    // Labels just outside the circles.
    text(
      labels.$1,
      Offset(a.dx - r * 0.35, a.dy - r - AppSpacing.md),
      label.copyWith(color: colors.$1),
    );
    text(
      labels.$2,
      Offset(b.dx + r * 0.35, b.dy - r - AppSpacing.md),
      label.copyWith(color: colors.$2),
    );
    text(
      labels.$3,
      Offset(c.dx, c.dy + r + AppSpacing.md),
      label.copyWith(color: colors.$3),
    );
  }

  @override
  bool shouldRepaint(_VennPainter old) =>
      old.venn != venn ||
      old.grow != grow ||
      old.colors != colors ||
      old.labels != labels ||
      old.number != number;
}
