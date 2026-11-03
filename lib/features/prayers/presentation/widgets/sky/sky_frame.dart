/// ============================================================
/// SKY FRAME — what the Prayer card's sky shows, and where things sit
/// ============================================================
///
/// What: [SkyFrame] is the second's worth of data the painter draws (the
/// half of the day we are in, the sky's colours, and the half that is
/// fading out after a sunrise / sunset); [SkyLayout] places the curve on a
/// card of a given width.
/// Why: the painter, the text labels over it and the tests all need the
/// same geometry.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_palette.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_path.dart';

/// What the painter shows right now (recomputed every second).
@immutable
class SkyFrame {
  const SkyFrame({required this.path, required this.colors, this.previous});

  final SkyPath path;
  final SkyColors colors;

  /// The half before the last sunrise / sunset, while it fades out.
  final SkyPath? previous;
}

/// Where the curve sits on a card [width] wide.
@immutable
class SkyLayout {
  const SkyLayout({
    required this.width,
    required this.rtl,
    required this.radius,
  });

  factory SkyLayout.of(double width, {bool rtl = false}) => SkyLayout(
    width: width,
    rtl: rtl,
    radius: (PrayerStyle.skyArcRadius * math.min(1.0, width / 358 + .05))
        .roundToDouble(),
  );

  final double width;
  final bool rtl;
  final double radius;

  double get horizon => PrayerStyle.skyHorizon;

  /// The curve's centre in left-to-right space (the sky is drawn there and
  /// mirrored afterwards).
  double get cxL => width - PrayerStyle.skyEdge - (radius + 12);

  /// Its centre on the card.
  double get cx => rtl ? width - cxL : cxL;

  /// How far the curve's near foot (with its glow) is from the card's
  /// *start* edge — the text side. Anything on the text side (the time-left
  /// bar) must stop short of it. Mirrored with the sky, so it is the same
  /// number in right-to-left.
  double get nearEdge => cxL - radius - 12;
}
