/// ============================================================
/// INSIGHTS VENN — three overlapping circles with a count per region
/// ============================================================
///
/// What: [InsightsVenn] draws three translucent circles (two on top, one
/// below) with the number of each region in it (the centre: all three)
/// and the circles' labels just outside; the circles grow in (not with
/// reduce motion). [InsightsFactChip] is the tinted pill used for the
/// plain-language reading under a diagram.
/// Why: Insights › Medicine (days by dose outcome) and Insights › Prayer
/// (days by prayer outcome) share it. A small CustomPainter — no chart
/// package needed.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';

/// Region counts: a, b, c alone; the pairs; all three.
typedef VennRegions = ({int a, int b, int c, int ab, int ac, int bc, int abc});

class InsightsVenn extends StatelessWidget {
  const InsightsVenn({
    required this.regions,
    required this.colors,
    required this.labels,
    required this.semanticLabel,
    super.key,
  });

  final VennRegions regions;

  /// Circle a (top start), b (top end), c (bottom).
  final (Color, Color, Color) colors;
  final (String, String, String) labels;

  /// What a screen reader says instead of the drawing.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    excludeSemantics: true,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: context.reduceMotion ? 1 : 0, end: 1),
      duration: context.motion(AppMotion.slow * 3),
      curve: Curves.easeOutBack,
      builder: (context, t, _) => SizedBox(
        height: InsightsDimens.vennHeight,
        child: CustomPaint(
          painter: _VennPainter(
            regions: regions,
            grow: t,
            colors: colors,
            labels: labels,
            number: context.text.rowTitle.copyWith(
              fontWeight: FontWeight.w700,
              color: context.ff.ink,
            ),
            label: context.text.caption.copyWith(fontWeight: FontWeight.w700),
            direction: Directionality.of(context),
          ),
        ),
      ),
    ),
  );
}

/// A tinted pill with a short fact ("12 perfect days").
class InsightsFactChip extends StatelessWidget {
  const InsightsFactChip({required this.color, required this.text, super.key});

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
    required this.regions,
    required this.grow,
    required this.colors,
    required this.labels,
    required this.number,
    required this.label,
    required this.direction,
  });

  final VennRegions regions;
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
    text('${regions.a}', away(a, centre, 0.55), number);
    text('${regions.b}', away(b, centre, 0.55), number);
    text('${regions.c}', away(c, centre, 0.45), number);
    text('${regions.ab}', away((a + b) / 2, centre, 0.9), number);
    text('${regions.ac}', away((a + c) / 2, centre, 0.75), number);
    text('${regions.bc}', away((b + c) / 2, centre, 0.75), number);
    text('${regions.abc}', centre, number);
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
      old.regions != regions ||
      old.grow != grow ||
      old.colors != colors ||
      old.labels != labels ||
      old.number != number;
}
