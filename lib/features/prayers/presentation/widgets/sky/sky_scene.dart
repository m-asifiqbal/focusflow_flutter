/// ============================================================
/// SKY SCENE — the layers behind the curve on the Prayer card
/// ============================================================
///
/// What: the sky gradient, stars and the odd shooting star, the sun's glow
/// and soft rays or the moon's halo, the drifting clouds (tinted by the
/// hour, lit from the sun or moon, dissolving before the text column),
/// haze and two ridges of hills in the card's accent colour, and the soft
/// elliptical mask that melts the whole scene into the card's gradient.
/// Why: split from the painter so each file stays small; everything here
/// is stateless — the painter passes in the moment and the config.
/// ============================================================
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_palette.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_sprites.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_tones.dart';

/// A cloud at its place at one moment.
class PlacedCloud {
  const PlacedCloud(this.sprite, this.x, this.y, this.alpha);

  final CloudSprite sprite;
  final double x;
  final double y;
  final double alpha;
}

class _Star {
  const _Star(
    this.ux,
    this.uy,
    this.r,
    this.a,
    this.speed,
    this.phase,
    this.big,
  );

  final double ux, uy, r, a, speed, phase;
  final bool big;
}

final List<_Star> _stars = () {
  final r = math.Random(977);
  return [
    for (var i = 0; i < 70; i++)
      _Star(
        r.nextDouble(),
        r.nextDouble(),
        .35 + r.nextDouble() * .55,
        .4 + r.nextDouble() * .6,
        .8 + r.nextDouble() * 1.8,
        r.nextDouble() * math.pi * 2,
        r.nextDouble() > .93,
      ),
  ];
}();

abstract final class SkyScene {
  /// The clouds at time [t] (seconds), far (small) to near, wisps behind
  /// all, drifting towards the text.
  static List<PlacedCloud> place(
    List<CloudSprite> sprites,
    double w,
    double yb,
    double t,
  ) {
    final out = <PlacedCloud>[];
    for (final s in sprites) {
      final sp = s.spec;
      final span = w + 2 * s.cssW;
      final x = ((sp.x0 - sp.speed * t) % span + span) % span - s.cssW;
      final y = (sp.yc - s.cssH * .55)
          .clamp(32.0, math.max(32.0, yb - s.cssH + 4))
          .toDouble();
      out.add(PlacedCloud(s, x, y, sp.alpha));
    }
    out.sort(
      (a, b) => (a.sprite.spec.wisp ? -1.0 : a.sprite.spec.w).compareTo(
        b.sprite.spec.wisp ? -1.0 : b.sprite.spec.w,
      ),
    );
    return out;
  }

  /// The gradient, the stars and (while it is dark and [animated]) the odd
  /// shooting star.
  static void sky(
    Canvas canvas,
    Rect rect,
    double yb,
    double t,
    SkyColors sky, {
    required bool animated,
  }) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, yb + 10),
          [sky.top, sky.mid, sky.horizon],
          const [0, .58, 1],
        ),
    );
    if (sky.stars <= .02) return;
    final w = rect.width;
    final paint = Paint();
    for (final s in _stars) {
      final x = ui.lerpDouble(.28 * w, w - 4, s.ux)!;
      final y = 4 + math.pow(s.uy, 1.3).toDouble() * (yb - 10);
      final a = clamp01(
        s.a *
            (.65 + .35 * math.sin(t * s.speed + s.phase)) *
            sky.stars *
            math.pow(1 - y / yb, .4).toDouble(),
      );
      paint.color = Color.fromRGBO(255, 255, 255, a);
      canvas.drawCircle(Offset(x, y), s.r, paint);
      if (s.big) {
        paint
          ..color = Color.fromRGBO(255, 255, 255, a * .6)
          ..strokeWidth = .6;
        canvas
          ..drawLine(Offset(x - 3, y), Offset(x + 3, y), paint)
          ..drawLine(Offset(x, y - 3), Offset(x, y + 3), paint);
      }
    }
    if (!animated || sky.stars < .5) return;
    const period = 13.0;
    final idx = (t / period).floor(), ph = (t % period) / period;
    if (ph >= .05) return;
    final rr = math.Random(idx * 97 + 11);
    final p = ph / .05;
    final sx = w * (.5 + rr.nextDouble() * .42), sy = 8 + rr.nextDouble() * 36;
    final head = Offset(sx - 80 * p, sy + 30 * p),
        tail = head + const Offset(46, -17);
    canvas.drawLine(
      head,
      tail,
      Paint()
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(head, tail, [
          Color.fromRGBO(255, 255, 255, .9 * (1 - p * .5) * sky.stars),
          const Color(0x00FFFFFF),
        ]),
    );
  }

  /// The sun's glow and soft rays, or the moon's halo (behind the clouds).
  static void bodyLight(
    Canvas canvas,
    Offset body,
    double alt,
    bool day,
    Color c,
    double t, {
    required bool animated,
    required double moonAge,
  }) {
    Paint glow(double radius, List<double> alphas, List<double> stops) =>
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = ui.Gradient.radial(body, radius, [
            for (final a in alphas) c.withValues(alpha: a),
          ], stops);
    if (day) {
      final hr = 70 + 110 * (1 - alt);
      canvas.drawCircle(
        body,
        hr,
        glow(hr, [.40 + .1 * (1 - alt), .14, 0], const [0, .35, 1]),
      );
      canvas.save();
      canvas.translate(body.dx, body.dy);
      if (animated) canvas.rotate(t * .05);
      final ray = Path()
        ..moveTo(0, -4)
        ..lineTo(90, -.6)
        ..lineTo(90, .6)
        ..lineTo(0, 4)
        ..close();
      final rayPaint = Paint()
        ..blendMode = BlendMode.screen
        ..color = c.withValues(alpha: .07 * (.6 + .4 * alt));
      for (var i = 0; i < 12; i++) {
        canvas.rotate(math.pi * 2 / 12);
        canvas.drawPath(ray, rayPaint);
      }
      canvas.restore();
      final gr = PrayerStyle.sunRadius * 3.6;
      canvas.drawCircle(
        body,
        gr,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = ui.Gradient.radial(
            body,
            gr,
            [
              sunHigh.withValues(alpha: .9),
              c.withValues(alpha: .55),
              c.withValues(alpha: 0),
            ],
            const [0, .3, 1],
          ),
      );
    } else {
      final lit = SkyMoon.lit(moonAge);
      final mr = PrayerStyle.moonRadius * (1 + .12 * (1 - alt));
      canvas
        ..drawCircle(
          body,
          mr * 9,
          glow(mr * 9, [.06 + .1 * lit, 0], const [0, 1]),
        )
        ..drawCircle(
          body,
          mr * 3.4,
          glow(mr * 3.4, [.1 + .26 * lit, 0], const [0, 1]),
        );
    }
  }

  /// Clouds into a layer of their own: tinted by the hour, lit from the
  /// body, dissolved before the text column. With [feather] (> 0) only a
  /// soft disc of that radius around the body is kept.
  static void clouds(
    Canvas canvas,
    Rect bounds,
    List<PlacedCloud> items,
    SkyColors sky,
    Offset body,
    Color bodyColor,
    bool day,
    double w, {
    double feather = 0,
  }) {
    canvas.saveLayer(bounds, Paint());
    for (final it in items) {
      final dst = Rect.fromLTWH(it.x, it.y, it.sprite.cssW, it.sprite.cssH);
      if (!dst.overlaps(bounds)) continue;
      canvas.drawImageRect(
        it.sprite.image,
        Rect.fromLTWH(0, 0, it.sprite.pw.toDouble(), it.sprite.ph.toDouble()),
        dst,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Color.fromRGBO(0, 0, 0, it.alpha),
      );
    }
    canvas.drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          Offset(.34 * w, 0),
          Offset(.6 * w, 0),
          const [Color(0x00000000), Color(0xFF000000)],
        ),
    );
    if (feather > 0) {
      canvas.drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.radial(
            body,
            feather,
            const [Color(0xFF000000), Color(0x00000000)],
            const [.5, 1],
          ),
      );
    }
    if (sky.cloudTintAlpha > .01) {
      canvas.drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.srcATop
          ..color = sky.cloudTint.withValues(alpha: sky.cloudTintAlpha),
      );
    }
    final lr = day ? 80.0 : 56.0;
    final light = day
        ? bodyColor
        : Color.lerp(bodyColor, const Color(0xFFC8D7FF), .5)!;
    canvas.drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.srcATop
        ..shader = ui.Gradient.radial(body, lr, [
          light.withValues(alpha: day ? .5 : .4),
          light.withValues(alpha: 0),
        ]),
    );
    canvas.restore();
  }

  /// Light seeping through a cloud that sits on the body.
  static void seep(Canvas canvas, Offset body, Color c, double occ) {
    canvas.drawCircle(
      body,
      42,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = ui.Gradient.radial(body, 42, [
          c.withValues(alpha: .38 * occ),
          c.withValues(alpha: 0),
        ]),
    );
  }

  /// Haze on the horizon, then a far and a near ridge of hills in [ground]
  /// (the card's accent) darkened by the hour.
  static void hills(
    Canvas canvas,
    double w,
    double h,
    double yb,
    SkyColors sky,
    Color ground,
  ) {
    canvas.drawRect(
      Rect.fromLTWH(0, yb - 24, w, 32),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, yb - 24),
          Offset(0, yb + 8),
          [
            sky.horizon.withValues(alpha: 0),
            sky.horizon.withValues(alpha: .32),
            sky.horizon.withValues(alpha: 0),
          ],
          const [0, .75, 1],
        ),
    );
    Path ridge(double base, double amp, double ph) {
      final p = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w + 4; x += 4) {
        p.lineTo(
          x,
          yb +
              base +
              amp * math.sin(x * .022 + ph) +
              amp * .5 * math.sin(x * .051 + ph * 1.9),
        );
      }
      return p
        ..lineTo(w, h)
        ..close();
    }

    final back = Color.lerp(ground, hillShade, sky.hillBack)!;
    canvas.drawPath(
      ridge(-3, 4.5, 1.3),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, yb - 8), Offset(0, h), [
          back.withValues(alpha: .92),
          Color.lerp(back, hillShade, .35)!.withValues(alpha: .92),
        ]),
    );
    final front = Color.lerp(ground, hillShade, sky.hillFront)!;
    canvas.drawPath(
      ridge(10, 5.5, 4.1),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, yb), Offset(0, h), [
          front,
          Color.lerp(front, hillShade, .4)!,
        ]),
    );
  }

  /// Fades the scene out towards the text: a soft ellipse of the card.
  static void melt(Canvas canvas, double w, double h) {
    final rx = .66 * w, ry = 1.4 * h;
    canvas
      ..save()
      ..translate(.86 * w, .52 * h)
      ..scale(1, ry / rx)
      ..drawRect(
        Rect.fromLTRB(-4 * (w + h), -4 * (w + h), 4 * (w + h), 4 * (w + h)),
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.radial(
            Offset.zero,
            rx,
            const [
              Color(0xFF000000),
              Color(0xFF000000),
              Color(0xD6000000),
              Color(0x8C000000),
              Color(0x3D000000),
              Color(0x0F000000),
              skyClear,
            ],
            const [0, .5, .58, .7, .84, .94, 1],
          ),
      )
      ..restore();
  }
}
