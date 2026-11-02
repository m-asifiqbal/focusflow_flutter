/// ============================================================
/// PRAYER SKY PAINTER — the sky, the curve and the sun or moon on it
/// ============================================================
///
/// What: one painter for the Prayer card's sky, back to front:
///   1. the scene — sky, stars, the sun's glow or the moon's halo, clouds,
///      hills (SkyScene) — in an off-screen layer;
///   2. a soft elliptical mask over that layer, so the sky *melts* into the
///      card's gradient on the text side (the hills continue the card's
///      colour);
///   3. the four-part curve with the sun or moon in front of it, and any
///      cloud over the body (SkyCurve).
/// Why: the mask is cheap on one layer and the curve stays crisp above it.
/// The scene is mirrored in right-to-left languages (text on the right, sky
/// on the left); the curve is a dial and is not.
/// Repaints from the ambient clock (clouds, stars), the intro and the
/// sunrise / sunset fade — never from a rebuild of the widget tree.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_curve.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_frame.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_scene.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_sprites.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_tones.dart';

export 'package:focusflow/features/prayers/presentation/widgets/sky/sky_frame.dart';

class PrayerSkyPainter extends CustomPainter {
  PrayerSkyPainter({
    required this.frame,
    required this.ground,
    required this.rtl,
    required this.southern,
    required this.moonAge,
    required this.animated,
    required this.ambient,
    required this.intro,
    required this.swap,
    required this.sprites,
  }) : super(
         repaint: Listenable.merge([ambient, intro, swap, sprites.revision]),
       );

  final SkyFrame frame;

  /// The card's accent colour (the hills are this, darkened).
  final Color ground;
  final bool rtl;
  final bool southern;
  final double moonAge;

  /// False for a still sky (reduce motion): no shooting star, no turning rays.
  final bool animated;

  /// Seconds; clouds, stars and rays are functions of this alone.
  final ValueListenable<double> ambient;

  /// 0 → 1: the body travels from the curve's start to "now".
  final Animation<double> intro;

  /// 0 → 1: the curve of the other half fades out, this one in.
  final Animation<double> swap;
  final SkySprites sprites;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w < 10 || h < 10) return;
    final lay = SkyLayout.of(w, rtl: rtl);
    final yb = lay.horizon;
    final t = ambient.value;
    final path = frame.path, sky = frame.colors, day = path.isDay;
    final f = path.now * Curves.easeInOutCubic.transform(intro.value);
    final alt = math.sin(f * math.pi);
    final body = Offset(
      lay.cxL - lay.radius * math.cos(f * math.pi),
      yb - lay.radius * math.sin(f * math.pi),
    );
    final bodyColor = day ? sunColor(alt) : moonColor(alt);
    final placed = SkyScene.place(sprites.clouds, w, yb, t);
    final occ = _cover(placed, body, day);

    // The scene, in a layer of its own, then melted into the card.
    final rect = Offset.zero & size;
    canvas
      ..saveLayer(rect, Paint())
      ..save();
    if (rtl) {
      canvas
        ..translate(w, 0)
        ..scale(-1, 1);
    }
    SkyScene.sky(canvas, rect, yb, t, sky, animated: animated);
    SkyScene.bodyLight(
      canvas,
      body,
      alt,
      day,
      bodyColor,
      t,
      animated: animated,
      moonAge: moonAge,
    );
    SkyScene.clouds(canvas, rect, placed, sky, body, bodyColor, day, w);
    if (occ > .04) SkyScene.seep(canvas, body, bodyColor, occ);
    SkyScene.hills(canvas, w, h, yb, sky, ground);
    SkyScene.melt(canvas, w, h);
    canvas
      ..restore()
      ..restore();

    // The curve and the body, crisp, above the scene.
    final prev = frame.previous;
    final fading = prev != null && swap.value < 1;
    if (prev != null && fading) {
      SkyCurve.paint(
        canvas,
        lay,
        prev,
        1,
        1 - swap.value,
        null,
        sprites: sprites,
        moonAge: moonAge,
        southern: southern,
      );
    }
    SkyCurve.paint(
      canvas,
      lay,
      path,
      f,
      fading ? swap.value : 1,
      (body: body, color: bodyColor, placed: placed, sky: sky, occ: occ, w: w),
      sprites: sprites,
      moonAge: moonAge,
      southern: southern,
    );
  }

  /// How much of the body the clouds cover (0 … 1): five points across its
  /// disc, so a half-covered sun reads as half covered.
  static double _cover(List<PlacedCloud> placed, Offset body, bool day) {
    final r0 = (day ? PrayerStyle.sunRadius : PrayerStyle.moonRadius) * .7;
    var occ = 0.0;
    for (final d in [
      Offset.zero,
      Offset(r0, 0),
      Offset(-r0, 0),
      Offset(0, r0),
      Offset(0, -r0),
    ]) {
      var a = 0.0;
      for (final c in placed) {
        final cover = c.sprite.coverAt(
          body.dx + d.dx - c.x,
          body.dy + d.dy - c.y,
        );
        a = 1 - (1 - a) * (1 - cover);
      }
      occ += a / 5;
    }
    return occ;
  }

  @override
  bool shouldRepaint(PrayerSkyPainter old) =>
      old.frame != frame ||
      old.ground != ground ||
      old.rtl != rtl ||
      old.southern != southern ||
      old.moonAge != moonAge ||
      old.animated != animated;
}
