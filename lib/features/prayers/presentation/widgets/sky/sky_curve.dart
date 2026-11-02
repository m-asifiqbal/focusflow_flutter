/// ============================================================
/// SKY CURVE — the four-part curve with the sun or moon in front of it
/// ============================================================
///
/// What: the dashed horizon, the four parts with small gaps (the part
/// already gone bright, the rest faint, a soft shadow under all of it), the
/// sun or moon on it *in front of the line*, and — for the current half —
/// any cloud over the body drawn in front of it again (feathered into the
/// curve around it) with a ring that keeps its place readable while it is
/// hidden. The sun fades in as it clears the horizon and out as it sets.
/// Why: this is the instrument of the card, so it is painted crisp above
/// the masked scene; it is a dial and is not mirrored for right-to-left
/// languages (the sun still rises on its left).
/// ============================================================
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_frame.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_palette.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_path.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_pixels.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_scene.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_sprites.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_tones.dart';

/// What the current half needs besides the curve: where the body is in the
/// scene (left-to-right space), the clouds that may cover it and how much.
typedef SkyLive = ({
  Offset body,
  Color color,
  List<PlacedCloud> placed,
  SkyColors sky,
  double occ,
  double w,
});

abstract final class SkyCurve {
  /// The curve for [p] with the body at [fShow] (0 … 1 along it), at
  /// [opacity]. [live] is given for the current half only.
  static void paint(
    Canvas canvas,
    SkyLayout lay,
    SkyPath p,
    double fShow,
    double opacity,
    SkyLive? live, {
    required SkySprites sprites,
    required double moonAge,
    required bool southern,
  }) {
    if (opacity < .01) return;
    final r = lay.radius, yb = lay.horizon, cx = lay.cx;
    final area = Rect.fromLTWH(cx - r - 24, yb - r - 28, 2 * r + 48, r + 56);
    if (opacity < 1) {
      canvas.saveLayer(area, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    }
    _line(canvas, lay, p, fShow);

    // The body, in front of the line.
    final alt = math.sin(fShow * math.pi);
    final at = Offset(
      cx - r * math.cos(fShow * math.pi),
      yb - r * math.sin(fShow * math.pi),
    );
    final alpha = sstep(0, .07, alt);
    if (alpha > .01) {
      if (p.isDay) {
        _sun(canvas, at, sunColor(alt), alpha);
      } else {
        _moon(canvas, at, alt, alpha, sprites, moonAge, southern);
      }
    }
    if (live != null) _cloudOver(canvas, lay, p, at, live);
    if (opacity < 1) canvas.restore();
  }

  /// The dashed horizon and the four parts with a soft shadow under them.
  static void _line(Canvas canvas, SkyLayout lay, SkyPath p, double fShow) {
    final r = lay.radius, yb = lay.horizon, cx = lay.cx;
    final rect = Rect.fromCircle(center: Offset(cx, yb), radius: r);
    final dash = Paint()
      ..color = const Color(0x6BFFFFFF)
      ..strokeWidth = 1;
    for (var x = cx - r - 16; x < cx + r + 16; x += 6) {
      canvas.drawLine(
        Offset(x, yb),
        Offset(math.min(x + 3, cx + r + 16), yb),
        dash,
      );
    }
    const gap = .065;
    final segments = <(double, double, double)>[];
    for (var i = 0; i < 4; i++) {
      final a0 = math.pi + p.bounds[i] * math.pi + (i == 0 ? 0 : gap / 2);
      final a1 = math.pi + p.bounds[i + 1] * math.pi - (i == 3 ? 0 : gap / 2);
      if (a1 > a0) {
        segments.add((a0, a1, math.min(a1, math.pi + fShow * math.pi)));
      }
    }
    Paint stroke(Color c, [MaskFilter? blur]) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = PrayerStyle.skyArcStroke
      ..strokeCap = StrokeCap.round
      ..color = c
      ..maskFilter = blur;
    final shadow = stroke(
      const Color(0x59022838),
      const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas
      ..save()
      ..translate(0, 1);
    for (final (a0, a1, _) in segments) {
      canvas.drawArc(rect, a0, a1 - a0, false, shadow);
    }
    canvas.restore();
    final faint = stroke(const Color(0x4DFFFFFF));
    final bright = stroke(Color.fromRGBO(255, 255, 255, p.isDay ? .95 : .85));
    for (final (a0, a1, lit) in segments) {
      canvas.drawArc(rect, a0, a1 - a0, false, faint);
      if (lit > a0) canvas.drawArc(rect, a0, lit - a0, false, bright);
    }
  }

  /// A cloud over the body goes in front of it again, and a ring marks the
  /// place while it is hidden.
  static void _cloudOver(
    Canvas canvas,
    SkyLayout lay,
    SkyPath p,
    Offset at,
    SkyLive live,
  ) {
    if (live.occ > .02) {
      final rf =
          (p.isDay ? PrayerStyle.sunRadius : PrayerStyle.moonRadius) * 3.2;
      canvas.save();
      if (lay.rtl) {
        canvas
          ..translate(live.w, 0)
          ..scale(-1, 1);
      }
      SkyScene.clouds(
        canvas,
        Rect.fromCircle(center: live.body, radius: rf),
        live.placed,
        live.sky,
        live.body,
        live.color,
        p.isDay,
        live.w,
        feather: rf,
      );
      canvas.restore();
    }
    if (live.occ > .12) {
      final ink = Color.fromRGBO(255, 255, 255, .9 * live.occ);
      canvas
        ..drawCircle(
          at,
          12.5,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        )
        ..drawCircle(at, 2, Paint()..color = ink);
    }
  }

  static void _sun(Canvas canvas, Offset at, Color c, double alpha) {
    const r = PrayerStyle.sunRadius;
    canvas
      ..drawCircle(
        at,
        r * 2.4,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = ui.Gradient.radial(at, r * 2.4, [
            c.withValues(alpha: .5 * alpha),
            c.withValues(alpha: 0),
          ]),
      )
      ..drawCircle(
        at,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            at,
            r,
            [
              const Color(0xFFFFFDF0).withValues(alpha: alpha),
              Color.lerp(
                c,
                const Color(0xFFFFFFEB),
                .45,
              )!.withValues(alpha: alpha),
              c.withValues(alpha: alpha),
            ],
            const [0, .7, 1],
          ),
      );
  }

  static void _moon(
    Canvas canvas,
    Offset at,
    double alt,
    double alpha,
    SkySprites sprites,
    double moonAge,
    bool southern,
  ) {
    final mr = PrayerStyle.moonRadius * (1 + .12 * (1 - alt));
    final img = sprites.moon(moonAge, southern: southern);
    if (img == null) {
      // While its face is being drawn: a plain pale disc.
      canvas.drawCircle(
        at,
        mr,
        Paint()..color = moonColor(alt).withValues(alpha: .9 * alpha),
      );
      return;
    }
    // The sprite has a little margin around the disc.
    final side = img.width / kMoonSpriteScale * (mr / PrayerStyle.moonRadius);
    final warm = 1 - clamp01(alt * 2.4);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromCenter(center: at, width: side, height: side),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(0, 0, 0, alpha)
        ..colorFilter = warm > .02
            ? ColorFilter.mode(
                const Color(0xFFFFBE78).withValues(alpha: .5 * warm),
                BlendMode.srcATop,
              )
            : null,
    );
  }
}
