/// ============================================================
/// SKY TONES — small shared helpers of the Prayer card's sky painters
/// ============================================================
///
/// What: clamp / smoothstep, the sun's colour by height (orange at the
/// horizon → warm yellow → pale overhead), the moon's (amber low → pale
/// high) and the few constant colours the scene layers share.
/// Why: the scene and the curve both paint the sun and moon and must agree
/// on their colour.
/// ============================================================
library;

import 'dart:ui';

import 'package:focusflow/features/prayers/presentation/prayer_style.dart';

double clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

/// 0 below [a], 1 above [b], smooth between.
double sstep(double a, double b, double v) {
  final t = clamp01((v - a) / (b - a));
  return t * t * (3 - 2 * t);
}

const skyClear = Color(0x00000000);
const sunHigh = Color(0xFFFFF4C2);
const _sunLow = Color(0xFFFF8A3D);
const _moonLow = Color(0xFFFFD9AE);

/// What the hills are darkened with.
const hillShade = Color(0xFF001914);

/// The sun's colour at [alt] (0 horizon … 1 overhead).
Color sunColor(double alt) => alt < .4
    ? Color.lerp(_sunLow, PrayerStyle.sun, alt / .4)!
    : Color.lerp(PrayerStyle.sun, sunHigh, (alt - .4) / .6)!;

/// The moon's colour at [alt].
Color moonColor(double alt) =>
    Color.lerp(_moonLow, PrayerStyle.moon, clamp01(alt * 2.4))!;
