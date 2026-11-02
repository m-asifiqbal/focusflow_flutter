/// ============================================================
/// LUNAR CALENDAR — tithi, moon days and the days of the moon's phases
/// ============================================================
///
/// What: the elongation of the Moon from the Sun (Meeus, *Astronomical
/// Algorithms* ch. 47 — the 30 largest terms of the Moon's longitude, and the
/// Sun's equation of centre), from which: the **tithi** at an instant (30 per
/// lunar month, each 12° of elongation: 1 – 15 the waxing Shukla fortnight, 16
/// – 30 the waning Krishna one, so 15 is Purnima and 30 Amavasya), the
/// **tithi at local sunrise** (the day a tithi is observed, by the common
/// "udaya tithi" rule), and the civil **day a phase falls on** (new moon,
/// quarters, full moon — Uposatha days).
/// Why: offline, no ephemeris tables. Accuracy: the Moon's longitude is good to
/// about 0.1° (≈ 12 minutes of a tithi), so the tithi of a day is exact except
/// within minutes of a boundary; Hindu traditions also disagree on rules
/// (Smarta and Vaishnava Ekadashi can differ by a day) and Buddhist calendars
/// follow national almanacs. Every use in the app says "approximate" and lets
/// the person nudge a day.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:focusflow/core/l10n/tr.dart';

abstract final class LunarCalendar {
  static const double _deg = math.pi / 180;

  /// Julian day of a UTC instant.
  static double julianDay(DateTime utc) =>
      utc.millisecondsSinceEpoch / 86400000 + 2440587.5;

  static double _norm(double d) => ((d % 360) + 360) % 360;

  /// The Sun's apparent longitude, degrees (Meeus ch. 25, low accuracy).
  static double sunLongitude(double jd) {
    final t = (jd - 2451545) / 36525;
    final l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t;
    final m = (357.52911 + 35999.05029 * t - 0.0001537 * t * t) * _deg;
    final c =
        (1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(m) +
        (0.019993 - 0.000101 * t) * math.sin(2 * m) +
        0.000289 * math.sin(3 * m);
    final omega = (125.04 - 1934.136 * t) * _deg;
    return _norm(l0 + c - 0.00569 - 0.00478 * math.sin(omega));
  }

  /// (D, M, M', F, coefficient × 1e-6°) — the largest terms of Meeus Table
  /// 47.A for the Moon's longitude.
  static const List<List<num>> _terms = [
    [0, 0, 1, 0, 6288774],
    [2, 0, -1, 0, 1274027],
    [2, 0, 0, 0, 658314],
    [0, 0, 2, 0, 213618],
    [0, 1, 0, 0, -185116],
    [0, 0, 0, 2, -114332],
    [2, 0, -2, 0, 58793],
    [2, -1, -1, 0, 57066],
    [2, 0, 1, 0, 53322],
    [2, -1, 0, 0, 45758],
    [0, 1, -1, 0, -40923],
    [1, 0, 0, 0, -34720],
    [0, 1, 1, 0, -30383],
    [2, 0, 0, -2, 15327],
    [0, 0, 1, 2, -12528],
    [0, 0, 1, -2, 10980],
    [4, 0, -1, 0, 10675],
    [0, 0, 3, 0, 10034],
    [4, 0, -2, 0, 8548],
    [2, 1, -1, 0, -7888],
    [2, 1, 0, 0, -6766],
    [1, 0, -1, 0, -5163],
    [1, 1, 0, 0, 4987],
    [2, -1, 1, 0, 4036],
    [2, 0, 2, 0, 3994],
    [4, 0, 0, 0, 3861],
    [2, 0, -3, 0, 3665],
    [0, 1, -2, 0, -2689],
  ];

  /// The Moon's longitude, degrees.
  static double moonLongitude(double jd) {
    final t = (jd - 2451545) / 36525;
    final lp = 218.3164477 + 481267.88123421 * t - 0.0015786 * t * t;
    final d = (297.8501921 + 445267.1114034 * t - 0.0018819 * t * t) * _deg;
    final m = (357.5291092 + 35999.0502909 * t - 0.0001536 * t * t) * _deg;
    final mp = (134.9633964 + 477198.8675055 * t + 0.0087414 * t * t) * _deg;
    final f = (93.272095 + 483202.0175233 * t - 0.0036539 * t * t) * _deg;
    final e = 1 - 0.002516 * t - 0.0000074 * t * t;
    var sum = 0.0;
    for (final r in _terms) {
      final arg = r[0] * d + r[1] * m + r[2] * mp + r[3] * f;
      final factor = r[1].abs() == 1 ? e : (r[1].abs() == 2 ? e * e : 1.0);
      sum += r[4] * factor * math.sin(arg);
    }
    // Venus, Jupiter and the flattening of the Earth.
    final a1 = (119.75 + 131.849 * t) * _deg;
    final a2 = (53.09 + 479264.29 * t) * _deg;
    sum +=
        3958 * math.sin(a1) +
        1962 * math.sin((lp * _deg) - f) +
        318 * math.sin(a2);
    return _norm(lp + sum / 1e6);
  }

  /// The Moon ahead of the Sun by this many degrees (0 = new, 180 = full).
  static double elongation(DateTime utc) {
    final jd = julianDay(utc);
    return _norm(moonLongitude(jd) - sunLongitude(jd));
  }

  /// 1 … 30 at the instant.
  static int tithi(DateTime utc) => (elongation(utc) / 12).floor() + 1;

  /// The tithi at [at] (any zone).
  static int tithiAt(DateTime at) => tithi(at.toUtc());

  /// "Shukla Ekadashi", "Krishna Chaturthi", "Purnima", "Amavasya".
  static String tithiName(int tithi) {
    if (tithi == 15) return tr('Purnima');
    if (tithi == 30) return tr('Amavasya');
    final paksha = tithi < 15 ? tr('Shukla') : tr('Krishna');
    final names = [
      tr('Pratipada'),
      tr('Dwitiya'),
      tr('Tritiya'),
      tr('Chaturthi'),
      tr('Panchami'),
      tr('Shashthi'),
      tr('Saptami'),
      tr('Ashtami'),
      tr('Navami'),
      tr('Dashami'),
      tr('Ekadashi'),
      tr('Dwadashi'),
      tr('Trayodashi'),
      tr('Chaturdashi'),
    ];
    return tr('{paksha} {tithi}', {
      'paksha': paksha,
      'tithi': names[(tithi - 1) % 15],
    });
  }

  /// The moon day for Buddhist lay observance: 0 new, 1 first quarter,
  /// 2 full, 3 last quarter — the phase crossed during the civil [day]
  /// (local midnight to midnight), or null.
  static int? phaseDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final a = elongation(start.toUtc());
    var b = elongation(end.toUtc());
    if (b < a) b += 360; // wrapped past the new moon
    for (var q = 0; q < 4; q++) {
      final mark = q * 90.0;
      for (final m in [mark, mark + 360]) {
        if (a <= m && m < b) return q;
      }
    }
    return null;
  }

  /// Names of [phaseDay] values.
  static String phaseName(int phase) => switch (phase) {
    0 => tr('New moon'),
    1 => tr('First quarter moon'),
    2 => tr('Full moon'),
    _ => tr('Last quarter moon'),
  };
}
