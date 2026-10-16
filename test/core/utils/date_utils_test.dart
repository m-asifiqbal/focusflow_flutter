/// DateUtilsX — calendar-day maths must ignore time of day and DST.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/utils/date_utils.dart';

void main() {
  group('daysBetween', () {
    test('ignores time of day', () {
      expect(
        DateUtilsX.daysBetween(
          DateTime(2026, 6, 13, 23, 59),
          DateTime(2026, 6, 14, 0, 1),
        ),
        1,
      );
      expect(
        DateUtilsX.daysBetween(DateTime(2026, 6, 13, 9), DateTime(2026, 6, 13)),
        0,
      );
    });

    test('counts calendar days across month / year / DST boundaries', () {
      // US DST starts 2026-03-08, EU DST 2026-03-29: a local-midnight
      // Duration is 23 h there, which `inDays` would truncate to 0.
      expect(
        DateUtilsX.daysBetween(DateTime(2026, 3, 7), DateTime(2026, 3, 8)),
        1,
      );
      expect(
        DateUtilsX.daysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 29)),
        1,
      );
      expect(
        DateUtilsX.daysBetween(DateTime(2026, 12, 31), DateTime(2027, 1, 1)),
        1,
      );
      expect(
        DateUtilsX.daysBetween(DateTime(2026, 3, 9), DateTime(2026, 3, 8)),
        -1,
      );
    });
  });

  group('relativeDay', () {
    final now = DateTime(2026, 3, 7, 22);

    test('labels neighbouring days', () {
      expect(DateUtilsX.relativeDay(DateTime(2026, 3, 7, 6), now), 'Today');
      expect(DateUtilsX.relativeDay(DateTime(2026, 3, 8, 1), now), 'Tomorrow');
      expect(DateUtilsX.relativeDay(DateTime(2026, 3, 6), now), 'Yesterday');
    });

    test('formats other days', () {
      expect(DateUtilsX.relativeDay(DateTime(2026, 6, 13), now), 'Sat, Jun 13');
      expect(
        DateUtilsX.relativeDay(DateTime(2027, 6, 13), now),
        'Jun 13, 2027',
      );
    });
  });
}
