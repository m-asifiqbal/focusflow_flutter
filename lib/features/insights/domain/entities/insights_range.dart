/// ============================================================
/// INSIGHTS RANGE — the chip selection and the day window it covers
/// ============================================================
///
/// What: [InsightsRange] is what the user picked (7 Days by default,
/// Today, 30 Days, 90 Days or a Custom day span); [InsightsRange.resolve]
/// turns it into an [InsightsWindow] of whole local days ending today,
/// and [InsightsWindow.previous] is the equal-length window right before
/// it (the baseline of every ▲/▼ delta).
/// Why: one place owns the calendar math so the provider, the aggregator
/// and the tests agree on boundaries. Days are built with
/// `DateUtilsX.addDays` (calendar arithmetic), never `Duration(days:)`, so
/// windows stay whole days across DST changes.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/utils/date_utils.dart';

/// The range chips, in mockup order (7 Days first = default).
enum InsightsPreset {
  week(7),
  today(1),
  month(30),
  quarter(90),
  custom(0);

  const InsightsPreset(this.days);

  /// Chip text in the active language (a getter: it follows a language
  /// switch).
  String get label => switch (this) {
    week => tr('7 Days'),
    today => tr('Today'),
    month => tr('30 Days'),
    quarter => tr('90 Days'),
    custom => tr('Custom'),
  };

  /// Window length in days (0 for [custom], which carries its own span).
  final int days;
}

@immutable
class InsightsRange {
  const InsightsRange._(this.preset, this.customStart, this.customEnd);

  /// A fixed-length preset ending today.
  /// Use [InsightsRange.custom] for [InsightsPreset.custom] spans.
  const InsightsRange.preset(this.preset)
    : assert(preset != InsightsPreset.custom, 'use InsightsRange.custom'),
      customStart = null,
      customEnd = null;

  /// Custom span of local days [start, end] (both inclusive; order-free).
  factory InsightsRange.custom(DateTime start, DateTime end) {
    final a = DateUtilsX.dateOnly(start);
    final b = DateUtilsX.dateOnly(end);
    return a.isAfter(b)
        ? InsightsRange._(InsightsPreset.custom, b, a)
        : InsightsRange._(InsightsPreset.custom, a, b);
  }

  /// The default: the last 7 days.
  static const InsightsRange initial = InsightsRange.preset(
    InsightsPreset.week,
  );

  final InsightsPreset preset;

  /// First / last day of a custom range (local midnights), else null.
  final DateTime? customStart;
  final DateTime? customEnd;

  bool get isCustom => preset == InsightsPreset.custom;

  /// The window for [today] (any instant of the day): presets end with
  /// today (inclusive); a custom range is used as picked.
  InsightsWindow resolve(DateTime today) {
    final end = DateUtilsX.dateOnly(today);
    if (isCustom) {
      return InsightsWindow(
        start: customStart!,
        end: DateUtilsX.addDays(customEnd!, 1),
      );
    }
    return InsightsWindow(
      start: DateUtilsX.addDays(end, -(preset.days - 1)),
      end: DateUtilsX.addDays(end, 1),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is InsightsRange &&
      other.preset == preset &&
      other.customStart == customStart &&
      other.customEnd == customEnd;

  @override
  int get hashCode => Object.hash(preset, customStart, customEnd);

  @override
  String toString() => isCustom
      ? 'InsightsRange(${DateUtilsX.dayKey(customStart!)}…'
            '${DateUtilsX.dayKey(customEnd!)})'
      : 'InsightsRange(${preset.label})';
}

/// Whole local days [start, end): [start] and [end] are local midnights.
@immutable
class InsightsWindow {
  InsightsWindow({required DateTime start, required DateTime end})
    : start = DateUtilsX.dateOnly(start),
      end = DateUtilsX.dateOnly(end);

  final DateTime start;

  /// Exclusive: the midnight after the last day.
  final DateTime end;

  /// Number of calendar days (DST-safe).
  int get days => DateUtilsX.daysBetween(start, end);

  /// The last day (inclusive).
  DateTime get lastDay => DateUtilsX.addDays(end, -1);

  /// Every day of the window, oldest first.
  List<DateTime> get dayList => [
    for (var i = 0; i < days; i++) DateUtilsX.addDays(start, i),
  ];

  /// The equal-length window that ends where this one starts.
  InsightsWindow get previous =>
      InsightsWindow(start: DateUtilsX.addDays(start, -days), end: start);

  /// Whether the instant [t] falls in [start, end).
  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  /// Day index of [t] in the window (0 = [start]); out-of-range values are
  /// returned as-is (negative / ≥ [days]). Calendar-based, so DST-safe.
  int dayIndexOf(DateTime t) => DateUtilsX.daysBetween(start, t);

  @override
  bool operator ==(Object other) =>
      other is InsightsWindow && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() =>
      'InsightsWindow(${DateUtilsX.dayKey(start)}…${DateUtilsX.dayKey(lastDay)})';
}
