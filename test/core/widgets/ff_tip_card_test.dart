// FFTipCard — one tip per day (no repeats until the catalogue is used up),
// "Another tip" steps on and resets the next day; the health and prayer
// catalogues it rotates through.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/ff_tip_card.dart';
import 'package:focusflow/features/medicines/domain/services/health_tips.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_tips.dart';

import 'ff_test_harness.dart';

void main() {
  test('a different tip every day until all were shown (DST-safe)', () {
    const count = 30;
    final seen = {
      for (var d = 0; d < count; d++)
        FFTipCard.indexFor(DateTime(2026, 3, 15 + d, 23, 30), count),
    };
    expect(seen, hasLength(count));
    // Same day, any time → same tip.
    expect(
      FFTipCard.indexFor(DateTime(2026, 11, 1, 0, 5), count),
      FFTipCard.indexFor(DateTime(2026, 11, 1, 23, 55), count),
    );
  });

  test('catalogues: no duplicates; tradition tips are woven in', () {
    expect(HealthTips.all.toSet(), hasLength(HealthTips.all.length));
    expect(HealthTips.all.length, greaterThanOrEqualTo(30));
    final general = PrayerTips.forTradition(PrayerTradition.custom);
    for (final t in PrayerTradition.values) {
      final tips = PrayerTips.forTradition(t);
      expect(tips.toSet(), hasLength(tips.length), reason: t.name);
      expect(tips.toSet().containsAll(general), isTrue, reason: t.name);
      if (t != PrayerTradition.custom) {
        // Every third tip is the tradition's own.
        expect(general, isNot(contains(tips[2])), reason: t.name);
      }
    }
  });

  Widget card(DateTime day) => FFTipCard(
    title: 'Tip of the day',
    tips: const ['one', 'two', 'three'],
    day: day,
    icon: FontAwesomeIcons.heartPulse,
    colors: ModuleStyle.medicines.colors,
    footnote: 'Not advice.',
  );

  testWidgets('"Another tip" steps on; the next day starts fresh', (
    tester,
  ) async {
    final day = DateTime(2026, 11, 1);
    final first = ['one', 'two', 'three'][FFTipCard.indexFor(day, 3)];
    await pumpFF(tester, card(day));
    expect(find.text(first), findsOneWidget);
    expect(find.text('Not advice.'), findsOneWidget);

    await tester.tap(find.text('Another tip'));
    await tester.pumpAndSettle();
    expect(find.text(first), findsNothing);

    await pumpFF(tester, card(DateTime(2026, 11, 2)));
    await tester.pumpAndSettle();
    final next = [
      'one',
      'two',
      'three',
    ][FFTipCard.indexFor(DateTime(2026, 11, 2), 3)];
    expect(find.text(next), findsOneWidget);
  });

  testWidgets('real catalogues fit at 360 pt × 1.3, light and dark', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      for (final tips in [
        HealthTips.all,
        PrayerTips.forTradition(PrayerTradition.islam),
      ]) {
        for (var i = 0; i < tips.length; i++) {
          await pumpFF(
            tester,
            FFTipCard(
              title: 'Prayer tip of the day',
              tips: tips,
              day: DateTime(2000).add(Duration(days: i)),
              icon: FontAwesomeIcons.solidLightbulb,
              colors: ModuleStyle.prayers.colors,
              footnote: HealthTips.footnote,
            ),
            dark: dark,
          );
          expect(tester.takeException(), isNull);
        }
      }
    }
  });
}
