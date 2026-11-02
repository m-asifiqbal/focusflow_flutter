/// ============================================================
/// SKY PATH — where the sun (or moon) is on its half-circle right now
/// ============================================================
///
/// What: the four parts of the day (sunrise → sunset) and of the night
/// (sunset → sunrise) as fractions of that half, "now" as a fraction, the part
/// we are in and the time left in it.
///   • Day: Morning (→ mid morning) · Late morning (→ noon) · Afternoon
///     (→ Asr) · Evening (→ sunset).
///   • Night: Dusk (→ nightfall, Isha) · Night (→ midnight) · Late night
///     (→ the last third) · Before dawn (→ sunrise).
/// Without a saved location a plain 6 AM – 6 PM day (and 6 PM – 6 AM night)
/// is used.
/// Why: pure and testable; the curve, the body on it and the labels on the
/// Prayer card all read this one value.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';

/// The four parts of the day and of the night, in order.
enum SkyPart {
  morning,
  lateMorning,
  afternoon,
  evening,
  dusk,
  night,
  lateNight,
  beforeDawn;

  bool get isDay => index < 4;

  String get label => switch (this) {
    morning => tr('Morning'),
    lateMorning => tr('Late morning'),
    afternoon => tr('Afternoon'),
    evening => tr('Evening'),
    dusk => tr('Dusk'),
    night => tr('Night'),
    lateNight => tr('Late night'),
    beforeDawn => tr('Before dawn'),
  };
}

/// Where the sky stands at a moment: day or night, the part boundaries and
/// "now" as fractions of that half (sunrise → sunset, or sunset → sunrise),
/// and the time left in the current part.
@immutable
class SkyPath {
  const SkyPath({
    required this.isDay,
    required this.bounds,
    required this.now,
    required this.left,
    required this.until,
    required this.from,
    required this.to,
  });

  /// From the sun times of each day ([sunFor] → null = a plain 6 AM – 6 PM
  /// day).
  factory SkyPath.of(SolarDay? Function(DateTime day) sunFor, DateTime now) {
    final today = DateUtilsX.dateOnly(now);
    DateTime at(DateTime d, int minutes) => DateUtilsX.atMinutes(d, minutes);
    DateTime rise(DateTime d) => sunFor(d)?.sunrise ?? at(d, 6 * 60);
    DateTime set(DateTime d) => sunFor(d)?.sunset ?? at(d, 18 * 60);

    final List<DateTime> marks;
    final bool day;
    if (!now.isBefore(rise(today)) && now.isBefore(set(today))) {
      day = true;
      final s = sunFor(today);
      final r = rise(today);
      final noon = s?.noon ?? at(today, 12 * 60);
      marks = [
        r,
        r.add(noon.difference(r) ~/ 2),
        noon,
        s?.asr ?? at(today, 15 * 60 + 30),
        set(today),
      ];
    } else {
      // Before sunrise, the night began yesterday evening.
      day = false;
      final eve = now.isBefore(rise(today))
          ? DateUtilsX.addDays(today, -1)
          : today;
      final s = sunFor(eve);
      final next = DateUtilsX.addDays(eve, 1);
      marks = [
        set(eve),
        s?.nightfall ?? at(eve, 19 * 60 + 30),
        s?.midnight ?? at(next, 0),
        s?.lastThird ?? at(next, 2 * 60),
        rise(next),
      ];
    }
    final start = marks.first;
    final span = marks.last.difference(start).inSeconds;
    double f(DateTime t) =>
        span <= 0 ? 0 : (t.difference(start).inSeconds / span).clamp(0.0, 1.0);
    final bounds = <double>[0];
    for (var i = 1; i < marks.length - 1; i++) {
      bounds.add(math.max(bounds.last, f(marks[i])));
    }
    bounds.add(1);
    var until = marks.last;
    for (final m in marks.skip(1)) {
      if (m.isAfter(now)) {
        until = m;
        break;
      }
    }
    return SkyPath(
      isDay: day,
      bounds: List.unmodifiable(bounds),
      now: f(now),
      left: until.difference(now),
      until: until,
      from: start,
      to: marks.last,
    );
  }

  final bool isDay;

  /// 5 fractions: the half's start, three part boundaries, its end.
  final List<double> bounds;

  /// 0 … 1 through this half.
  final double now;

  /// Until the current part ends.
  final Duration left;

  /// When the current part ends.
  final DateTime until;

  /// The half's start and end (sunrise / sunset, or sunset / sunrise).
  final DateTime from;
  final DateTime to;

  SkyPart get part {
    var i = 0;
    while (i < 3 && now >= bounds[i + 1]) {
      i++;
    }
    return SkyPart.values[(isDay ? 0 : 4) + i];
  }
}
