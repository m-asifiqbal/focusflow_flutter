/// ============================================================
/// UNIFORM LABEL SCALE — one text scale for a row of sibling labels
/// ============================================================
///
/// What: [uniformLabelScaler] measures every label of a row of
/// equal-width tiles / chips and returns one [TextScaler] that makes the
/// widest label fit; every sibling uses it, so "Today" and "Upcoming"
/// (stat tiles, screen 10) or "Today" and "Next week" (WHEN chips,
/// screen 13) render at the same size.
/// Why: a separate FittedBox per label shrinks only the long ones, so at
/// 360 pt × 1.3 the row looked uneven. Labels that already fit keep the
/// user's text scale untouched.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The text scaler to apply to every label of a row so the widest of
/// [labels] (rendered in [style]) fits in [maxWidth] logical pixels.
/// Returns the ambient scaler when they all fit.
TextScaler uniformLabelScaler(
  BuildContext context, {
  required Iterable<String> labels,
  required TextStyle style,
  required double maxWidth,
}) {
  final base = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  var widest = 0.0;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: direction,
      textScaler: base,
      maxLines: 1,
    )..layout();
    widest = math.max(widest, painter.width);
    painter.dispose();
  }
  if (widest <= maxWidth || widest <= 0 || maxWidth <= 0) return base;
  final size = style.fontSize ?? 14;
  // A hair under the exact ratio so rounding never re-triggers a FittedBox.
  final factor = (maxWidth / widest) * 0.995;
  return TextScaler.linear(base.scale(size) / size * factor);
}
