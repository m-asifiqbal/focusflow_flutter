/// ============================================================
/// PRAYER SUN ARC — the sun's path today, on the Prayer hero card
/// ============================================================
///
/// What: a half arc from sunrise (start) to sunset (end) over a dashed
/// horizon, split into the day's four parts — morning (sunrise → mid
/// morning), late morning (→ noon), afternoon (→ Asr) and evening
/// (→ sunset) — with small gaps between them. The part of the day already
/// gone is bright, the rest faint; the sun sits where it is now, glowing,
/// and the current part's name is under it with a small "1h 29m left"
/// countdown — the time left in this part of the day (this waqt: noon → Asr is
/// Dhuhr's, Asr → sunset is Asr's). Sunrise and sunset times below the
/// ends. Before sunrise / after sunset the arc is dim, a moon shows
/// instead and the countdown runs to sunrise.
/// The sun travels from sunrise to "now" when the card appears and glides
/// on as the minutes pass (no animation with reduce motion).
/// Why: the user asked for a sense of where the day stands, in the space
/// the hero card had free beside the prayer's name.
/// Sun times come from the saved location; without one the arc uses a
/// plain 6 AM – 6 PM day and leaves the times out (they would be made up).
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';

/// The four parts of the daylight, in order.
enum SunPart { morning, lateMorning, afternoon, evening }

extension SunPartLabel on SunPart {
  String get label => switch (this) {
    SunPart.morning => tr('Morning'),
    SunPart.lateMorning => tr('Late morning'),
    SunPart.afternoon => tr('Afternoon'),
    SunPart.evening => tr('Evening'),
  };
}

/// Where the day stands: the part boundaries and "now" as fractions of
/// sunrise → sunset (now < 0 before sunrise, > 1 after sunset).
@immutable
class SunPath {
  const SunPath({required this.bounds, required this.now, required this.left});

  /// From today's sun times ([sun] null = a plain 6 AM – 6 PM day).
  factory SunPath.of(SolarDay? sun, DateTime now) {
    final day = DateUtilsX.dateOnly(now);
    final rise = sun?.sunrise ?? DateUtilsX.atMinutes(day, 6 * 60);
    final noon = sun?.noon ?? DateUtilsX.atMinutes(day, 12 * 60);
    final asr = sun?.asr ?? DateUtilsX.atMinutes(day, 15 * 60 + 30);
    final set = sun?.sunset ?? DateUtilsX.atMinutes(day, 18 * 60);
    final span = set.difference(rise).inSeconds;
    double f(DateTime t) => span <= 0 ? 0 : t.difference(rise).inSeconds / span;
    final mid = rise.add(noon.difference(rise) ~/ 2);
    final ends = [mid, noon, asr.isBefore(noon) ? noon : asr, set];
    // Time left in this part; at night, until the next sunrise (tomorrow's
    // is close enough to today's + 1 day for a countdown).
    final DateTime until;
    if (now.isBefore(rise)) {
      until = rise;
    } else if (!now.isBefore(set)) {
      until = rise.add(const Duration(days: 1));
    } else {
      until = ends.firstWhere((e) => e.isAfter(now), orElse: () => set);
    }
    return SunPath(
      bounds: [0, f(mid), f(noon), f(asr).clamp(f(noon), 1.0), 1],
      now: f(now),
      left: until.difference(now),
    );
  }

  /// 5 fractions: sunrise, mid morning, noon, Asr, sunset.
  final List<double> bounds;
  final double now;

  /// Until this part ends (at night: until sunrise).
  final Duration left;

  bool get isDay => now >= 0 && now <= 1;

  /// The part of the day at [now] (null at night).
  SunPart? get part {
    if (!isDay) return null;
    for (var i = 1; i < bounds.length; i++) {
      if (now < bounds[i]) return SunPart.values[i - 1];
    }
    return SunPart.evening;
  }
}

class PrayerSunArc extends StatelessWidget {
  const PrayerSunArc({
    required this.sun,
    required this.now,
    required this.use24h,
    required this.color,
    super.key,
  });

  /// Today's sun times (null without a location).
  final SolarDay? sun;
  final DateTime now;
  final bool use24h;

  /// Ink on the card (the hero's on-gradient white).
  final Color color;

  @override
  Widget build(BuildContext context) {
    final path = SunPath.of(sun, now);
    final part = path.part;
    final s = sun;
    final label = context.text.meta.copyWith(
      color: color.withValues(alpha: 0.78),
      fontSize: PrayerStyle.sunArcLabel,
    );
    String at(DateTime t) => PrayerFormat.time(t, use24h: use24h);
    return Semantics(
      label: [
        if (part != null) part.label else tr('Night'),
        if (part != null)
          tr('{time} left', {'time': PrayerFormat.duration(path.left)})
        else
          tr('Sunrise in {time}', {'time': PrayerFormat.duration(path.left)}),
        if (s != null) tr('Sunrise {time}', {'time': at(s.sunrise)}),
        if (s != null) tr('Sunset {time}', {'time': at(s.sunset)}),
      ].join(', '),
      excludeSemantics: true,
      child: SizedBox(
        width: PrayerStyle.sunArcWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: PrayerStyle.sunArcHeight,
              child: TweenAnimationBuilder<double>(
                // From sunrise to now on first show, then glides on.
                tween: Tween(
                  begin: context.reduceMotion ? path.now : 0,
                  end: path.now,
                ),
                duration: context.motion(AppMotion.slow * 4),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => CustomPaint(
                  size: const Size(
                    PrayerStyle.sunArcWidth,
                    PrayerStyle.sunArcHeight,
                  ),
                  painter: _ArcPainter(
                    bounds: path.bounds,
                    now: t,
                    day: path.isDay,
                    ink: color,
                    sun: PrayerStyle.sun,
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        bottom: AppSpacing.xs,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (part == null)
                            Icon(
                              FontAwesomeIcons.solidMoon,
                              size: PrayerStyle.sunArcMoon,
                              color: color.withValues(alpha: 0.9),
                            )
                          else
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                part.label,
                                maxLines: 1,
                                style: label.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          _Countdown(
                            text: part == null
                                ? tr('Sunrise in {time}', {
                                    'time': PrayerFormat.duration(path.left),
                                  })
                                : tr('{time} left', {
                                    'time': PrayerFormat.duration(path.left),
                                  }),
                            color: color,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (s != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(at(s.sunrise), maxLines: 1, style: label),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(at(s.sunset), maxLines: 1, style: label),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "1h 29m left": plain small text under the part's name — the time left
/// in this waqt, no chip (user's choice), tabular digits so it doesn't
/// jiggle as it counts down.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    // Fits inside the arc's opening.
    constraints: const BoxConstraints(maxWidth: PrayerStyle.sunArcWidth * 0.68),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        style: context.text.meta.copyWith(
          fontSize: PrayerStyle.sunLeftFont,
          fontWeight: FontWeight.w600,
          color: color.withValues(alpha: 0.85),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ),
  );
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.bounds,
    required this.now,
    required this.day,
    required this.ink,
    required this.sun,
  });

  final List<double> bounds;
  final double now;
  final bool day;
  final Color ink;
  final Color sun;

  /// Angle gap between two parts.
  static const double _gap = 0.05;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = PrayerStyle.sunArcStroke;
    final pad = PrayerStyle.sunDot + 2;
    final r = math.min(size.width / 2 - pad, size.height - pad);
    final centre = Offset(size.width / 2, size.height - stroke / 2);
    final rect = Rect.fromCircle(center: centre, radius: r);
    // RTL is not mirrored: the sun rises in the east (left) on any script,
    // like a clock face.
    double angle(double f) => math.pi + f.clamp(0.0, 1.0) * math.pi;

    // Horizon.
    final dash = Paint()
      ..color = ink.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawLine(
        Offset(x, centre.dy),
        Offset(math.min(x + 3, size.width), centre.dy),
        dash,
      );
    }

    final faint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = ink.withValues(alpha: day ? 0.28 : 0.18);
    final bright = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = ink.withValues(alpha: 0.95);
    for (var i = 0; i < bounds.length - 1; i++) {
      final a = angle(bounds[i]) + (i == 0 ? 0 : _gap / 2);
      final b = angle(bounds[i + 1]) - (i == bounds.length - 2 ? 0 : _gap / 2);
      if (b <= a) continue;
      canvas.drawArc(rect, a, b - a, false, faint);
      if (!day) continue;
      final lit = math.min(b, angle(now));
      if (lit > a) canvas.drawArc(rect, a, lit - a, false, bright);
    }

    if (!day) return;
    final t = angle(now);
    final at = centre + Offset(math.cos(t) * r, math.sin(t) * r);
    canvas.drawCircle(
      at,
      PrayerStyle.sunDot * 2,
      Paint()..color = sun.withValues(alpha: 0.25),
    );
    canvas.drawCircle(at, PrayerStyle.sunDot, Paint()..color = sun);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.now != now ||
      old.day != day ||
      old.ink != ink ||
      old.sun != sun ||
      old.bounds.length != bounds.length ||
      [
        for (var i = 0; i < bounds.length; i++) old.bounds[i] != bounds[i],
      ].any((d) => d);
}
