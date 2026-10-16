/// InsightsRange windows and the rule-based weekly tip.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/insights/domain/entities/insights_range.dart';
import 'package:focusflow/features/insights/domain/entities/insights_snapshot.dart';
import 'package:focusflow/features/insights/domain/services/insights_tips.dart';

void main() {
  final now = DateTime(2026, 10, 15, 18); // Thursday
  DateTime day(int d, [int h = 0]) => DateTime(2026, 10, d, h);

  group('InsightsRange', () {
    test('presets end today and the previous window is adjacent', () {
      for (final p in InsightsPreset.values.where(
        (p) => p != InsightsPreset.custom,
      )) {
        final w = InsightsRange.preset(p).resolve(now);
        expect(w.days, p.days, reason: p.label);
        expect(w.lastDay, day(15));
        expect(w.end, day(16));
        expect(w.previous.days, p.days);
        expect(w.previous.end, w.start);
      }
      expect(InsightsRange.initial.preset, InsightsPreset.week);
      expect(InsightsRange.initial.resolve(now).start, day(9));
    });

    test('custom ranges are inclusive and order-free', () {
      final a = InsightsRange.custom(day(12, 9), day(3));
      expect(a, InsightsRange.custom(day(3), day(12)));
      final w = a.resolve(now);
      expect(w.start, day(3));
      expect(w.end, day(13));
      expect(w.days, 10);
      expect(w.previous.start, DateTime(2026, 9, 23));
    });
  });

  group('InsightsTips', () {
    final week = InsightsRange.initial.resolve(now);
    List<ProductivityPoint> daily([List<int>? tasks]) => [
      for (var i = 0; i < 7; i++)
        ProductivityPoint(
          start: DateTime(2026, 10, 9 + i),
          days: 1,
          tasks: tasks?[i] ?? 0,
          habits: 0,
        ),
    ];

    InsightsTip pick({
      List<DateTime> completed = const [],
      List<ProductivityPoint>? points,
      RatioMetric consistency = RatioMetric.zero,
      int focus = 0,
    }) => InsightsTips.pick(
      window: week,
      completedAt: completed,
      daily: points ?? daily(),
      consistency: consistency,
      focusMinutes: focus,
    );

    test('generic without enough data', () {
      final tip = pick(completed: [day(10, 9), day(11, 9)]);
      expect(tip.kind, TipKind.generic);
      expect(tip.isPersonal, isFalse);
    });

    test('morning: 2× more tasks before noon', () {
      final tip = pick(
        completed: [
          for (final h in [8, 9, 10, 11]) day(10, h),
          day(12, 14),
          day(13, 15),
        ],
      );
      expect(tip.kind, TipKind.morning);
      expect(tip.body, startsWith('You complete 2× more tasks before noon.'));
    });

    test('evening lead names the evening', () {
      final tip = pick(
        completed: [
          for (final h in [18, 19, 20, 21, 22]) day(11, h),
        ],
      );
      expect(tip.kind, TipKind.evening);
    });

    test('balanced day → most productive weekday', () {
      final tip = pick(
        completed: [
          day(9, 9),
          day(10, 9),
          day(11, 15),
          day(12, 16),
          day(13, 10),
          day(14, 17),
        ],
        // Oct 9 = Friday … Oct 15 = Thursday.
        points: daily([1, 1, 1, 1, 1, 1, 6]),
      );
      expect(tip.kind, TipKind.weekday);
      expect(tip.body, startsWith('Thursday is your most productive day.'));
    });

    test('low habit consistency, then focus suggestion', () {
      expect(
        pick(consistency: const RatioMetric(done: 2, total: 10)).kind,
        TipKind.habits,
      );
      expect(
        pick(completed: [day(10, 9), day(11, 15), day(12, 18)]).kind,
        TipKind.focus,
      );
      expect(
        pick(completed: [day(10, 9), day(11, 15), day(12, 18)], focus: 25).kind,
        TipKind.generic,
      );
    });
  });
}
