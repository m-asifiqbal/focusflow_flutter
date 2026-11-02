/// ============================================================
/// SKY PALETTE — the colour of the sky at any minute of the day
/// ============================================================
///
/// What: [SkyPalette.at] blends between twelve looks (deep night, pre-dawn,
/// first light, sunrise, morning, noon, afternoon, golden hour, sunset,
/// dusk, nightfall, midnight) that are pinned to the day's own sun times:
/// sunrise / sunset ± minutes, noon, nightfall and the middle of the night
/// (a plain 6 AM – 6 PM day without a location). Each look carries the
/// three sky colours, how many stars show, how clouds are tinted and how
/// dark the hills are. [SkyMoon] gives the moon's age and lit fraction.
/// Why: the scene on the Prayer card follows the same sunrise and sunset as
/// the curve, so the colours, the stars and the moon agree with the clock.
/// Scene art, not UI chrome: these colours are the same in light and dark
/// mode and with every accent (the hills take the accent from the card).
/// ============================================================
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';

/// One look of the sky.
@immutable
class SkyColors {
  const SkyColors({
    required this.top,
    required this.mid,
    required this.horizon,
    required this.stars,
    required this.cloudTint,
    required this.cloudTintAlpha,
    required this.hillFront,
    required this.hillBack,
  });

  /// Sky colours from the zenith down to the horizon.
  final Color top;
  final Color mid;
  final Color horizon;

  /// 0 … 1: how many stars show.
  final double stars;

  /// What clouds are tinted with (pink at sunset, deep blue at night) and
  /// how strongly (0 = white, as at noon).
  final Color cloudTint;
  final double cloudTintAlpha;

  /// 0 … 1: how much black is mixed into the card's accent to colour the
  /// near and far hills.
  final double hillFront;
  final double hillBack;

  static SkyColors lerp(SkyColors a, SkyColors b, double t) => SkyColors(
    top: Color.lerp(a.top, b.top, t)!,
    mid: Color.lerp(a.mid, b.mid, t)!,
    horizon: Color.lerp(a.horizon, b.horizon, t)!,
    stars: a.stars + (b.stars - a.stars) * t,
    cloudTint: Color.lerp(a.cloudTint, b.cloudTint, t)!,
    cloudTintAlpha:
        a.cloudTintAlpha + (b.cloudTintAlpha - a.cloudTintAlpha) * t,
    hillFront: a.hillFront + (b.hillFront - a.hillFront) * t,
    hillBack: a.hillBack + (b.hillBack - a.hillBack) * t,
  );
}

const _white = Color(0xFFFFFFFF);

const _deepNight = SkyColors(
  top: Color(0xFF050A1F),
  mid: Color(0xFF0A1736),
  horizon: Color(0xFF123055),
  stars: 1,
  cloudTint: Color(0xFF0F1B40),
  cloudTintAlpha: .82,
  hillFront: .74,
  hillBack: .58,
);
const _preDawn = SkyColors(
  top: Color(0xFF0B1740),
  mid: Color(0xFF243A78),
  horizon: Color(0xFF3E5A96),
  stars: .9,
  cloudTint: Color(0xFF14234F),
  cloudTintAlpha: .75,
  hillFront: .70,
  hillBack: .54,
);
const _firstLight = SkyColors(
  top: Color(0xFF1D2F6E),
  mid: Color(0xFF6B5A9C),
  horizon: Color(0xFFE08F7C),
  stars: .35,
  cloudTint: Color(0xFFC97A8A),
  cloudTintAlpha: .45,
  hillFront: .55,
  hillBack: .42,
);
const _sunrise = SkyColors(
  top: Color(0xFF3D6EC0),
  mid: Color(0xFFF0A98B),
  horizon: Color(0xFFFFC47A),
  stars: 0,
  cloudTint: Color(0xFFFF9F78),
  cloudTintAlpha: .5,
  hillFront: .30,
  hillBack: .18,
);
const _morning = SkyColors(
  top: Color(0xFF2A78D0),
  mid: Color(0xFF5AA4E4),
  horizon: Color(0xFFA5D6F6),
  stars: 0,
  cloudTint: _white,
  cloudTintAlpha: 0,
  hillFront: .17,
  hillBack: .02,
);
const _noon = SkyColors(
  top: Color(0xFF1F68C2),
  mid: Color(0xFF3F93DE),
  horizon: Color(0xFF79C2EE),
  stars: 0,
  cloudTint: _white,
  cloudTintAlpha: 0,
  hillFront: .17,
  hillBack: .02,
);
const _afternoon = SkyColors(
  top: Color(0xFF2872CA),
  mid: Color(0xFF4A9BE0),
  horizon: Color(0xFF93CDF0),
  stars: 0,
  cloudTint: _white,
  cloudTintAlpha: 0,
  hillFront: .17,
  hillBack: .02,
);
const _golden = SkyColors(
  top: Color(0xFF3A72C0),
  mid: Color(0xFF86A8D0),
  horizon: Color(0xFFF7C07A),
  stars: 0,
  cloudTint: Color(0xFFFFD9A8),
  cloudTintAlpha: .3,
  hillFront: .24,
  hillBack: .12,
);
const _sunset = SkyColors(
  top: Color(0xFF3B4F9A),
  mid: Color(0xFFD0678A),
  horizon: Color(0xFFFF8A4C),
  stars: 0,
  cloudTint: Color(0xFFFF8F6A),
  cloudTintAlpha: .55,
  hillFront: .38,
  hillBack: .26,
);
const _dusk = SkyColors(
  top: Color(0xFF1C2A66),
  mid: Color(0xFF5D3F8A),
  horizon: Color(0xFFD4616F),
  stars: .25,
  cloudTint: Color(0xFF8A4A7A),
  cloudTintAlpha: .6,
  hillFront: .58,
  hillBack: .46,
);
const _nightfall = SkyColors(
  top: Color(0xFF0C1538),
  mid: Color(0xFF1B2C63),
  horizon: Color(0xFF2A4577),
  stars: .85,
  cloudTint: Color(0xFF16224D),
  cloudTintAlpha: .78,
  hillFront: .70,
  hillBack: .56,
);

abstract final class SkyPalette {
  /// The sky at [now], blended from the two looks around it.
  static SkyColors at(DateTime now, SolarDay? Function(DateTime day) sunFor) {
    final today = DateUtilsX.dateOnly(now);
    final keys = <(DateTime, SkyColors)>[
      for (var d = -1; d <= 1; d++)
        ..._keysOf(DateUtilsX.addDays(today, d), sunFor),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    var i = 0;
    while (i < keys.length - 2 && !keys[i + 1].$1.isAfter(now)) {
      i++;
    }
    final (t0, a) = keys[i];
    final (t1, b) = keys[i + 1];
    final span = t1.difference(t0).inMilliseconds;
    if (span <= 0) return a;
    final u = (now.difference(t0).inMilliseconds / span).clamp(0.0, 1.0);
    return SkyColors.lerp(a, b, u * u * (3 - 2 * u));
  }

  /// One day's looks, pinned to its sun times.
  static List<(DateTime, SkyColors)> _keysOf(
    DateTime d,
    SolarDay? Function(DateTime day) sunFor,
  ) {
    final s = sunFor(d);
    final rise = s?.sunrise ?? DateUtilsX.atMinutes(d, 6 * 60);
    final set = s?.sunset ?? DateUtilsX.atMinutes(d, 18 * 60);
    final noon = s?.noon ?? DateUtilsX.atMinutes(d, 12 * 60);
    final night = s?.nightfall ?? DateUtilsX.atMinutes(d, 19 * 60 + 30);
    final mid =
        s?.midnight ?? DateUtilsX.atMinutes(DateUtilsX.addDays(d, 1), 0);
    Duration m(int v) => Duration(minutes: v);
    return [
      (rise.subtract(m(84)), _deepNight),
      (rise.subtract(m(42)), _preDawn),
      (rise.subtract(m(12)), _firstLight),
      (rise.add(m(9)), _sunrise),
      (rise.add(m(72)), _morning),
      (noon, _noon),
      (set.subtract(m(108)), _afternoon),
      (set.subtract(m(36)), _golden),
      (set.subtract(m(3)), _sunset),
      (set.add(m(27)), _dusk),
      (night, _nightfall),
      (mid, _deepNight),
    ];
  }
}

/// The moon: its age in days and how much of it is lit.
abstract final class SkyMoon {
  static const double synodic = 29.530588853;

  /// Days since the last new moon (0 … 29.53), good to about half a day.
  static double age(DateTime t) {
    final days =
        t.toUtc().difference(DateTime.utc(2000, 1, 6, 18, 14)).inMilliseconds /
        Duration.millisecondsPerDay;
    return (days % synodic + synodic) % synodic;
  }

  /// 0 (new) … 1 (full).
  static double lit(double age) =>
      (1 - math.cos(age / synodic * 2 * math.pi)) / 2;
}
