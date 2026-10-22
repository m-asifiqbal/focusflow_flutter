/// ============================================================
/// INSIGHTS TOKENS + FORMAT — sizes measured on design/25_insights.png
/// ============================================================
///
/// What: the few measurements specific to Insights (390-pt mockup) and
/// the number formatting shared by the KPI cards, chart tooltips and the
/// share image ("84%", "24.5", "▲ 12%", "45 d").
/// Why: widgets never hard-code sizes, and every place formats a metric
/// the same way.
/// ============================================================
library;

import 'dart:ui' show Color;

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/features/habits/domain/services/streak_calculator.dart';

abstract final class InsightsDimens {
  // KPI cards
  static const double kpiPadding = 16;
  static const double kpiLabelTracking = 0.8;
  static const double kpiDeltaIcon = 12;
  static const double kpiMinHeight = 88;
  static const double kpiValue = 26;
  static const double kpiDelta = 12.5;
  static const double kpiGap = 12;

  // Cards
  static const double cardPadding = 20;
  static const double cardTitle = 17;
  static const double cardGap = 16;

  // Line chart
  static const double chartHeight = 150;
  static const double lineWidth = 3;
  static const double dotRadius = 4.5;
  static const double dotStroke = 2.5;

  // Donut
  static const double donut = 120;
  static const double donutStroke = 20;
  static const double donutGap = 24;
  static const double legendDot = 10;
  static const double legendRow = 30;
  static const double legendText = 15;

  // Streaks
  static const double streakTile = 44;
  static const double streakBar = 8;
  static const double streakBarWidth = 84;
  static const double streakValue = 15;

  // Tip
  static const double tipIcon = 18;
  static const double tipTitle = 18;
  static const double tipBody = 14;

  // Focus timer
  static const double timerRing = 200;
  static const double timerStroke = 12;
  static const double timerDigits = 44;

  static const double noDataIcon = 22;

  // Skeleton
  static const double chartSkeleton = 210;
  static const double splitSkeleton = 180;

  /// Below the chips, above the KPI grid.
  static const double chipsGap = 10;

  /// Content opacity while another range is loading.
  static const double staleOpacity = 0.45;
}

abstract final class InsightsColors {
  /// The tip's lightbulb (amber in both modes, as in the mockup).
  static const Color tipBulb = AppPalette.amber300;

  /// Text on the accent gradient (tip card, share watermark): white in both
  /// modes, since the gradient is the same in light and dark.
  static const Color onGradient = AppPalette.white;
}

abstract final class InsightsFormat {
  /// 0.84 → "84%"; null → "—".
  static String percent(double? rate) =>
      rate == null ? '—' : '${(rate * 100).round()}%';

  /// Minutes → hours with one decimal, trailing ".0" dropped: 1470 → "24.5",
  /// 120 → "2".
  static String hours(int minutes) {
    final h = minutes / 60;
    final s = h.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  /// Signed delta text without the arrow: 12 → "12%", for [unit] "%"/"h"/"".
  static String delta(num value, String unit) {
    final v = value.abs();
    final text = v is int
        ? '$v'
        : (v.toStringAsFixed(1).endsWith('.0')
              ? v.toStringAsFixed(0)
              : v.toStringAsFixed(1));
    return '$text$unit';
  }

  /// "45 d" / "3 w".
  static String streakShort(HabitStreak s) => s.unit == StreakUnit.weeks
      ? tr('{n} w', {'n': s.current})
      : tr('{n} d', {'n': s.current});

  /// "45 days" / "1 week" (screen readers).
  static String streakLong(HabitStreak s) => s.label;
}
