/// ============================================================
/// SKY PIXELS — the maths that draws clouds and the moon's face
/// ============================================================
///
/// What: value noise, the cloud art direction ([CloudSpec]s), and the pixel
/// generators: a cumulus (noise density field, lumpy dome, flat belly,
/// feathered edge, shaded by how much cloud lies between each point and the
/// light), a wisp (stretched noise) and a moon face for a phase (dark maria,
/// bright craters, sphere-lit so the terminator is soft, a trace of
/// earthshine). Premultiplied RGBA, as the engine expects.
/// Why: pure functions, no engine calls — sky_sprites.dart turns them into
/// images and caches them.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';

/// Value noise on a 64 × 64 lattice (smooth between points) and its
/// fractal sum.
final class SkyNoise {
  SkyNoise(int seed) {
    final r = math.Random(seed);
    for (var i = 0; i < _v.length; i++) {
      _v[i] = r.nextDouble();
    }
  }

  final Float32List _v = Float32List(4096);

  double _at(int x, int y) => _v[((y & 63) << 6) | (x & 63)];

  double value(double x, double y) {
    final xi = x.floor(), yi = y.floor();
    final xf = x - xi, yf = y - yi;
    final u = xf * xf * (3 - 2 * xf), w = yf * yf * (3 - 2 * yf);
    final a = _at(xi, yi) + (_at(xi + 1, yi) - _at(xi, yi)) * u;
    final b = _at(xi, yi + 1) + (_at(xi + 1, yi + 1) - _at(xi, yi + 1)) * u;
    return a + (b - a) * w;
  }

  double fbm(double x, double y, [int octaves = 4]) {
    var sum = 0.0, amp = .5, freq = 1.0, total = 0.0;
    for (var i = 0; i < octaves; i++) {
      sum += amp * value(x * freq + i * 17.3, y * freq + i * 9.1);
      total += amp;
      amp *= .5;
      freq *= 2.03;
    }
    return sum / total;
  }
}

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

double _sstep(double a, double b, double v) {
  final t = _clamp01((v - a) / (b - a));
  return t * t * (3 - 2 * t);
}

/// Premultiplied RGBA pixels (what the engine expects) and the straight
/// alpha of each pixel, for hit tests.
class SkyPixels {
  SkyPixels(this.width, this.height)
    : rgba = Uint8List(width * height * 4),
      alpha = Uint8List(width * height);

  final int width;
  final int height;
  final Uint8List rgba;
  final Uint8List alpha;

  void put(int x, int y, double r, double g, double b, double a) {
    final i = (y * width + x) * 4;
    rgba[i] = (r * a).round().clamp(0, 255);
    rgba[i + 1] = (g * a).round().clamp(0, 255);
    rgba[i + 2] = (b * a).round().clamp(0, 255);
    rgba[i + 3] = (a * 255).round().clamp(0, 255);
    alpha[y * width + x] = rgba[i + 3];
  }
}

/// What a cloud is, and how it drifts (art-directed, so the sky always
/// looks composed: small hazy clouds low and slow, bigger clearer ones
/// higher and quicker, thin streaks highest).
@immutable
class CloudSpec {
  const CloudSpec({
    required this.w,
    required this.h,
    required this.seed,
    required this.yc,
    required this.speed,
    required this.x0,
    required this.alpha,
    this.wisp = false,
  });

  /// Logical size of the cloud body.
  final double w;
  final double h;
  final int seed;

  /// Where its middle floats, in px from the card's top (the horizon is
  /// [PrayerStyle.skyHorizon]).
  final double yc;

  /// Drift in px per second towards the melt, and its start offset.
  final double speed;
  final double x0;
  final double alpha;
  final bool wisp;
}

const List<CloudSpec> kCloudSpecs = [
  CloudSpec(w: 38, h: 17, seed: 11, yc: 112, speed: 3.2, x0: 40, alpha: .78),
  CloudSpec(w: 56, h: 25, seed: 12, yc: 76, speed: 5.0, x0: 170, alpha: .9),
  CloudSpec(w: 78, h: 33, seed: 13, yc: 52, speed: 7.5, x0: 290, alpha: .97),
  CloudSpec(w: 44, h: 21, seed: 14, yc: 98, speed: 2.8, x0: 330, alpha: .75),
  CloudSpec(w: 62, h: 28, seed: 15, yc: 64, speed: 5.6, x0: 90, alpha: .88),
  CloudSpec(
    w: 70,
    h: 6,
    seed: 16,
    yc: 44,
    speed: 2.4,
    x0: 120,
    alpha: .8,
    wisp: true,
  ),
  CloudSpec(
    w: 92,
    h: 8,
    seed: 17,
    yc: 60,
    speed: 3.0,
    x0: 300,
    alpha: .8,
    wisp: true,
  ),
];

/// Pixels of a fair-weather cumulus: a lumpy dome, a feathered edge, a
/// flat belly; light comes from the top left.
(SkyPixels, double, double) cloudPixels(CloudSpec spec) {
  const pad = 8.0, scale = 1.5;
  final w = spec.w, h = spec.h;
  final cw = w + pad * 2, ch = h * 1.15 + pad * 2;
  final pw = (cw * scale).round(), ph = (ch * scale).round();
  final out = SkyPixels(pw, ph);
  final rnd = math.Random(spec.seed);
  final noise = SkyNoise(spec.seed);
  final ox = rnd.nextDouble() * 50, oy = rnd.nextDouble() * 50;
  final base = (ch - pad - h * .12) * scale;
  final rx = w / 2 * scale, dome = h * scale * .95, cx0 = pw / 2;
  final k = 3.4 / pw; // about three big lumps across the cloud
  double dens(double x, double y) {
    final u = (x - cx0) / rx;
    final double e;
    if (y > base) {
      e =
          math.max(0.0, 1 - u * u) *
          math.max(0.0, 1 - (y - base) / (3 * scale));
    } else {
      final vy = (base - y) / dome;
      e = 1 - (u * u + vy * vy * 1.15);
    }
    return e * 1.15 + (noise.fbm(x * k + ox, y * k * 1.4 + oy, 3) - .5) * .95;
  }

  final st = 2.6 * scale;
  const lx = -.6, ly = -.8;
  for (var y = 0; y < ph; y++) {
    for (var x = 0; x < pw; x++) {
      final d = dens(x.toDouble(), y.toDouble());
      if (d < .4) continue;
      final a = _sstep(.42, .78, d);
      if (a <= 0) continue;
      var sum = 0.0;
      for (var j = 1; j <= 3; j++) {
        sum += math.max(0.0, dens(x + lx * st * j, y + ly * st * j));
      }
      var b = _clamp01(.32 + math.exp(-.42 * sum) * .9);
      b -= _clamp01((y - (base - dome * .5)) / (dome * .5)) * .3; // belly
      b = math.pow(_clamp01(b), 1.15).toDouble();
      out.put(
        x,
        y,
        142 + (255 - 142) * b,
        160 + (255 - 160) * b,
        194 + (255 - 194) * b,
        a * 242 / 255,
      );
    }
  }
  return (out, cw, ch);
}

/// A thin high streak: stretched noise, no shading.
(SkyPixels, double, double) wispPixels(CloudSpec spec) {
  const pad = 6.0, scale = 1.5;
  final w = spec.w, h = spec.h;
  final cw = w + pad * 2, ch = h * 3 + pad * 2;
  final pw = (cw * scale).round(), ph = (ch * scale).round();
  final out = SkyPixels(pw, ph);
  final rnd = math.Random(spec.seed);
  final noise = SkyNoise(spec.seed);
  final ox = rnd.nextDouble() * 50, oy = rnd.nextDouble() * 50;
  final rx = w / 2 * scale, ry = h * 1.3 * scale;
  for (var y = 0; y < ph; y++) {
    for (var x = 0; x < pw; x++) {
      final u = (x - pw / 2) / rx, v = (y - ph / 2) / ry;
      final e = 1 - (u * u + v * v);
      if (e < -.5) continue;
      final d =
          e * 1.2 +
          (noise.fbm(x / pw * 2.6 + ox, y / ph * 7 + oy, 3) - .5) * 1.1;
      final a = _sstep(.5, .95, d) * .55;
      if (a > 0) out.put(x, y, 255, 255, 255, a);
    }
  }
  return (out, cw, ch);
}

/// Pixels per logical px of a moon sprite.
const int kMoonSpriteScale = 4;

/// A moon face for [age] days, lit from the right while it waxes (from the
/// left in the southern hemisphere), [size] logical px across.
SkyPixels moonPixels(double age, {required bool southern}) {
  const s = kMoonSpriteScale;
  final radius = PrayerStyle.moonRadius;
  final d = ((radius * 2 + 2) * s).ceil();
  final out = SkyPixels(d, d);
  final rad = radius * s;
  final noise = SkyNoise(42);
  final p = age / 29.530588853 * 2 * math.pi;
  final lx = math.sin(p) * (southern ? -1 : 1), lz = -math.cos(p);
  // x, y (disc units, y down), radii, how dark.
  const maria = <List<double>>[
    [-.28, -.38, .30, .22, .62],
    [.18, -.38, .17, .15, .66],
    [.62, -.30, .12, .09, .70],
    [.30, -.05, .20, .17, .66],
    [.52, .18, .13, .11, .60],
    [.34, .30, .08, .07, .55],
    [-.60, 0, .26, .30, .55],
    [-.45, .22, .17, .15, .50],
    [-.45, .45, .10, .09, .60],
    [-.20, .45, .15, .12, .50],
    [-.05, -.78, .34, .06, .40],
    [0, -.12, .10, .09, .50],
    [-.10, .10, .08, .07, .35],
  ];
  // x, y, radius, brightness: bright craters (Tycho, Copernicus, …).
  const craters = <List<double>>[
    [-.10, .78, .07, .95],
    [-.34, .02, .05, .80],
    [-.55, -.28, .035, .90],
    [-.64, .06, .04, .70],
  ];
  double blob(
    double a,
    double x,
    double y,
    double cx,
    double cy,
    double rx,
    double ry,
  ) {
    final dx = (x - cx) / rx, dy = (y - cy) / ry;
    final dd = math.sqrt(dx * dx + dy * dy);
    if (dd >= 1) return 0;
    return a * (dd < .65 ? 1 - .2 * dd / .65 : .8 * (1 - (dd - .65) / .35));
  }

  for (var py = 0; py < d; py++) {
    for (var px = 0; px < d; px++) {
      final x = (px + .5 - d / 2) / rad, y = (py + .5 - d / 2) / rad;
      final d2 = x * x + y * y;
      if (d2 > 1.04) continue;
      final dist = math.sqrt(d2);
      final nz = math.sqrt(math.max(0.0, 1 - d2));
      final sh = _sstep(0, .3, x * lx + nz * lz);
      // Highland mottling, maria, craters.
      final mot = noise.fbm(x * 6 + 3, y * 6 + 7, 3) - .5;
      var r = 220 + mot * 22, g = 217 + mot * 22, b = 207 + mot * 22;
      for (final m in maria) {
        final a = blob(m[4], x, y, m[0], m[1], m[2], m[3]);
        if (a > 0) {
          r += (84 - r) * a;
          g += (90 - g) * a;
          b += (104 - b) * a;
        }
      }
      for (final c in craters) {
        final a = blob(c[3], x, y, c[0], c[1], c[2], c[2]);
        if (a > 0) {
          r += (255 - r) * a;
          g += (255 - g) * a;
          b += (250 - b) * a;
        }
      }
      final k = .09 + .91 * sh;
      out.put(
        px,
        py,
        r * k + 2 * (1 - sh),
        g * k + 4 * (1 - sh),
        b * k + 10 * (1 - sh),
        _clamp01((1 - dist) * rad + .5),
      );
    }
  }
  return out;
}
