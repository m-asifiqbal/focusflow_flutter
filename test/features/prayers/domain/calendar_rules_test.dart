/// Calendar rules: the stored text, the matching against each tradition's
/// calendar, the ±1 day nudge, and a prayer that repeats by a rule instead of
/// by weekday.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/prayers/domain/entities/calendar_rule.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/calendar_rules.dart';
import 'package:focusflow/features/prayers/domain/services/hijri_date.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

bool on(String key, DateTime day, {int shift = 0, int adjust = 0}) =>
    CalendarRules.matches(
      CalendarRule(key, shift: shift),
      day,
      hijriAdjust: adjust,
    );

void main() {
  test('the stored text round-trips and rejects junk', () {
    const r = CalendarRule('hfast:tishabav', shift: 1);
    expect(r.serialized, 'hfast:tishabav|1');
    expect(CalendarRule.parse(r.serialized), r);
    expect(CalendarRule.parse('moon:0,2')?.shift, 0);
    expect(CalendarRule.parse('moon:0,2|9')?.shift, 1); // clamped
    expect(CalendarRule.parse(''), isNull);
    expect(CalendarRule.parse(null), isNull);
    expect(CalendarRule.parse('nonsense'), isNull);
  });

  test('Hijri rules', () {
    final first = HijriDate(1448, 9, 1).toGregorian();
    final last = HijriDate(1448, 9, 30).toGregorian();
    expect(on('hspan:9-1-30', first), isTrue);
    expect(on('hspan:9-1-30', last), isTrue);
    expect(
      on('hspan:9-1-30', d(first.year, first.month, first.day - 1)),
      isFalse,
    );
    // Arafah and Ashura are single days.
    final arafah = HijriDate(1448, 12, 9).toGregorian();
    expect(on('hspan:12-9-9', arafah), isTrue);
    expect(on('hspan:12-9-9', arafah.add(const Duration(days: 1))), isFalse);
    // The six of Shawwal start the day after Eid.
    final eid = HijriDate(1448, 10, 1).toGregorian();
    expect(on('hspan:10-2-7', eid), isFalse);
    expect(on('hspan:10-2-7', eid.add(const Duration(days: 1))), isTrue);
    // The white days: the 13th – 15th of any month.
    final white = HijriDate(1448, 3, 14).toGregorian();
    expect(on('hdays:13,14,15', white), isTrue);
    // The saved correction moves the day.
    expect(on('hspan:9-1-30', first, adjust: -1), isFalse);
  });

  test('the nudge moves a rule by a day', () {
    final av9 = d(2026, 7, 23);
    expect(on('hfast:tishabav', av9), isTrue);
    expect(on('hfast:tishabav', av9, shift: 1), isFalse);
    expect(on('hfast:tishabav', d(2026, 7, 24), shift: 1), isTrue);
    expect(on('hfast:tishabav', d(2026, 7, 22), shift: -1), isTrue);
  });

  test('Hebrew rules', () {
    expect(on('hfast:yomkippur', d(2026, 9, 21)), isTrue);
    expect(on('hebrew:omer', d(2026, 4, 2)), isTrue);
    expect(on('hebrew:omer', d(2026, 5, 21)), isFalse);
    expect(on('hebrew:chanukah', d(2026, 12, 6)), isTrue);
    expect(on('hebrew:roshchodesh', d(2026, 10, 12)), isTrue);
  });

  test('Christian seasons', () {
    // 2026: Ash Wednesday 18 Feb, Easter 5 Apr, Pascha 12 Apr.
    expect(on('season:lent', d(2026, 2, 18)), isTrue);
    expect(on('season:lent', d(2026, 2, 22)), isFalse); // a Sunday
    expect(on('season:lent', d(2026, 2, 23)), isTrue);
    expect(on('season:lent', d(2026, 4, 4)), isTrue);
    expect(on('season:lent', d(2026, 4, 5)), isFalse);
    expect(on('season:holyweek', d(2026, 3, 29)), isTrue);
    expect(on('season:advent', d(2026, 12, 10)), isTrue);
    expect(on('season:advent', d(2026, 11, 28)), isFalse);
    expect(on('season:greatlent', d(2026, 2, 23)), isTrue); // Clean Monday
    expect(on('season:greatlent', d(2026, 2, 22)), isFalse);
    expect(on('season:greatlent', d(2026, 4, 11)), isTrue);
    expect(on('season:greatlent', d(2026, 4, 12)), isFalse);
  });

  test('fixed ranges wrap the year end', () {
    expect(on('fixed:11-15..1-6', d(2026, 12, 25)), isTrue);
    expect(on('fixed:11-15..1-6', d(2027, 1, 3)), isTrue);
    expect(on('fixed:11-15..1-6', d(2027, 2, 3)), isFalse);
    expect(on('fixed:8-1..8-14', d(2026, 8, 14)), isTrue);
    expect(on('fixed:8-1..8-14', d(2026, 8, 15)), isFalse);
  });

  test('lunar days: a month has two Ekadashis and about one full moon', () {
    final from = d(2026, 11, 1);
    final ekadashi = CalendarRules.nextDates(
      const CalendarRule('tithi:11,26'),
      from,
      count: 10,
      horizon: 60,
    );
    expect(ekadashi.length, inInclusiveRange(3, 5)); // 60 days ≈ 4 Ekadashis
    final full = CalendarRules.nextDates(
      const CalendarRule('tithi:15'),
      from,
      count: 10,
      horizon: 60,
    );
    expect(full.length, inInclusiveRange(1, 3));
    final uposatha = CalendarRules.nextDates(
      const CalendarRule('moon:0,1,2,3'),
      from,
      count: 20,
      horizon: 30,
    );
    expect(uposatha.length, inInclusiveRange(3, 5));
  });

  test('a calendar rule replaces the weekdays', () {
    final now = d(2026, 1, 1);
    final p = Prayer.draft(now: now).copyWith(
      weekdaysMask: 1, // Mondays only — ignored once a rule is set
      calendar: const CalendarRule('hfast:tishabav'),
    );
    expect(PrayerSchedule.isDueOn(p, d(2026, 7, 23)), isTrue); // a Thursday
    expect(PrayerSchedule.isDueOn(p, d(2026, 7, 20)), isFalse); // a Monday
    final plain = p.copyWith(clearCalendar: true);
    expect(PrayerSchedule.isDueOn(plain, d(2026, 7, 20)), isTrue);
    expect(plain.calendar, isNull);
  });
}
