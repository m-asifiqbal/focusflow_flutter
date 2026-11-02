/// ============================================================
/// CALENDAR RULES — does a calendar rule fall on a day?
/// ============================================================
///
/// What: [CalendarRules.matches] answers whether a [CalendarRule] is on a
/// civil day (the rule's ±1 day nudge applied), [nextDates] lists the coming
/// dates (the editor's preview) and [describe] says the rule in words.
/// Why: one pure place for every tradition's calendar days, built on the
/// Hijri, Hebrew, Christian and lunar engines in `services/calendars/`.
/// A tithi is read at 06:00 local time (≈ sunrise, the "udaya tithi" rule)
/// unless the rule names an hour (Pradosh and Sankashti are evening days).
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/prayers/domain/entities/calendar_rule.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/calendars/christian_calendar.dart';
import 'package:focusflow/features/prayers/domain/services/calendars/hebrew_calendar.dart';
import 'package:focusflow/features/prayers/domain/services/calendars/lunar_calendar.dart';
import 'package:focusflow/features/prayers/domain/services/hijri_date.dart';

abstract final class CalendarRules {
  /// Whether [rule] is on [day] (only its y/m/d count). [hijriAdjust] is the
  /// saved Hijri correction of the moon sighting.
  static bool matches(CalendarRule rule, DateTime day, {int hijriAdjust = 0}) {
    final d = DateUtilsX.addDays(DateUtilsX.dateOnly(day), -rule.shift);
    final arg = rule.arg;
    switch (rule.kind) {
      case 'hspan':
        final p = arg.split('-').map(int.tryParse).toList();
        if (p.length != 3 || p.contains(null)) return false;
        final h = HijriDate.fromGregorian(d, adjustDays: hijriAdjust);
        return h.month == p[0] && h.day >= p[1]! && h.day <= p[2]!;
      case 'hdays':
        final days = _ints(arg);
        final h = HijriDate.fromGregorian(d, adjustDays: hijriAdjust);
        return days.contains(h.day);
      case 'hfast':
        return HebrewCalendar.isFast(arg, d);
      case 'hebrew':
        return switch (arg) {
          'roshchodesh' => HebrewCalendar.isRoshChodesh(d),
          'omer' => HebrewCalendar.omerTonight(d) != null,
          'chanukah' => HebrewCalendar.chanukahTonight(d) != null,
          _ => false,
        };
      case 'season':
        return _season(arg, d);
      case 'fixed':
        return _fixed(arg, d);
      case 'tithi':
        final at = arg.split('@');
        final hour = at.length > 1 ? int.tryParse(at[1]) ?? 6 : 6;
        final t = LunarCalendar.tithiAt(DateTime(d.year, d.month, d.day, hour));
        return _ints(at.first).contains(t);
      case 'moon':
        final p = LunarCalendar.phaseDay(d);
        return p != null && _ints(arg).contains(p);
    }
    return false;
  }

  static Set<int> _ints(String s) =>
      s.split(',').map((e) => int.tryParse(e.trim())).whereType<int>().toSet();

  static bool _season(String id, DateTime d) {
    final s = ChristianCalendar.season(d);
    switch (id) {
      case 'lent':
        // Ash Wednesday to Holy Saturday; Sundays are not fast days.
        return (s == LiturgicalSeason.lent || s == LiturgicalSeason.holyWeek) &&
            d.weekday != DateTime.sunday;
      case 'holyweek':
        return s == LiturgicalSeason.holyWeek;
      case 'advent':
        return s == LiturgicalSeason.advent;
      case 'eastertide':
        return s == LiturgicalSeason.eastertide;
      case 'greatlent':
        // Clean Monday (48 days before Pascha) to Holy Saturday.
        final n = DateUtilsX.daysBetween(ChristianCalendar.pascha(d.year), d);
        return n >= -48 && n <= -1;
    }
    return false;
  }

  static bool _fixed(String arg, DateTime d) {
    final m = RegExp(r'^(\d+)-(\d+)\.\.(\d+)-(\d+)$').firstMatch(arg);
    if (m == null) return false;
    final from = int.parse(m[1]!) * 100 + int.parse(m[2]!);
    final to = int.parse(m[3]!) * 100 + int.parse(m[4]!);
    final here = d.month * 100 + d.day;
    return from <= to ? here >= from && here <= to : here >= from || here <= to;
  }

  /// The next [count] dates of [rule] from [from] (inclusive), looking at
  /// most [horizon] days ahead.
  static List<DateTime> nextDates(
    CalendarRule rule,
    DateTime from, {
    int count = 3,
    int hijriAdjust = 0,
    int horizon = 800,
  }) {
    final out = <DateTime>[];
    var d = DateUtilsX.dateOnly(from);
    for (var i = 0; i < horizon && out.length < count; i++) {
      if (matches(rule, d, hijriAdjust: hijriAdjust)) out.add(d);
      d = DateUtilsX.addDays(d, 1);
    }
    return out;
  }

  /// The rules a tradition offers in the editor, in the order shown.
  static List<CalendarRule> choices(PrayerTradition t) {
    List<CalendarRule> of(List<String> keys) => [
      for (final k in keys) CalendarRule(k),
    ];
    final islam = of([
      'hspan:9-1-30',
      'hdays:13,14,15',
      'hspan:12-9-9',
      'hspan:1-10-10',
      'hspan:10-2-7',
      'hspan:10-1-1',
      'hspan:12-10-10',
      'hspan:12-1-10',
    ]);
    final judaism = of([
      for (final id in HebrewCalendar.fastIds) 'hfast:$id',
      'hebrew:roshchodesh',
      'hebrew:omer',
      'hebrew:chanukah',
    ]);
    final christianity = of([
      'season:lent',
      'season:holyweek',
      'season:advent',
      'season:eastertide',
      'season:greatlent',
      'fixed:11-15..12-24',
      'fixed:8-1..8-14',
    ]);
    final hinduism = of([
      'tithi:11,26',
      'tithi:13,28@18',
      'tithi:19@20',
      'tithi:15',
      'tithi:30',
    ]);
    final buddhism = of(['moon:0,1,2,3', 'moon:2', 'moon:0,2']);
    return switch (t) {
      PrayerTradition.islam => islam,
      PrayerTradition.judaism => judaism,
      PrayerTradition.christianity => christianity,
      PrayerTradition.hinduism => hinduism,
      PrayerTradition.buddhism => buddhism,
      PrayerTradition.custom => [
        ...islam,
        ...judaism,
        ...christianity,
        ...hinduism,
        ...buddhism,
      ],
    };
  }

  /// "Ramadan", "Ekadashi" … a short phrase for the rule.
  static String describe(CalendarRule rule) {
    final arg = rule.arg;
    return switch (rule.key) {
      'hspan:12-9-9' => tr('Day of Arafah'),
      'hspan:1-10-10' => tr('Day of Ashura'),
      'hspan:10-2-7' => tr('Six days of Shawwal'),
      'hspan:10-1-1' => tr('Eid al-Fitr'),
      'hspan:12-10-10' => tr('Eid al-Adha'),
      'hspan:12-1-10' => tr('First ten days of Dhu al-Hijjah'),
      'hdays:13,14,15' => tr('White days (13th – 15th)'),
      'tithi:11,26' => tr('Ekadashi (11th lunar day)'),
      'tithi:13,28@18' => tr('Pradosh (13th lunar day, dusk)'),
      'tithi:19@20' => tr('Sankashti Chaturthi'),
      'tithi:15' => tr('Purnima (full moon)'),
      'tithi:30' => tr('Amavasya (new moon)'),
      'moon:0,1,2,3' => tr('Uposatha (four moon days)'),
      'moon:2' => tr('Full-moon day (Poya)'),
      'moon:0,2' => tr('New and full moon'),
      'fixed:11-15..12-24' => tr('Nativity fast'),
      'fixed:8-1..8-14' => tr('Dormition fast'),
      _ => switch (rule.kind) {
        'hspan' => _describeSpan(arg),
        'hdays' => tr('Days {days} of each Hijri month', {'days': arg}),
        'hfast' => _fastName(arg),
        'hebrew' => switch (arg) {
          'roshchodesh' => tr('Rosh Chodesh'),
          'omer' => tr('Counting of the Omer'),
          _ => tr('Chanukah'),
        },
        'season' => switch (arg) {
          'lent' => tr('Lent'),
          'holyweek' => tr('Holy Week'),
          'advent' => tr('Advent'),
          'eastertide' => tr('Eastertide'),
          _ => tr('Great Lent'),
        },
        'fixed' => tr('A fixed fasting period'),
        'tithi' => tr('Lunar day'),
        'moon' => tr('Moon day'),
        _ => '',
      },
    };
  }

  static String _describeSpan(String arg) {
    final p = arg.split('-').map(int.tryParse).toList();
    if (p.length != 3 || p.contains(null)) return '';
    final month = hijriMonthName(p[0]!);
    if (p[1] == 1 && p[2]! >= 29) return month;
    if (p[1] == p[2]) {
      return tr('{day} {month}', {'day': '${p[1]}', 'month': month});
    }
    return tr('{from}–{to} {month}', {
      'from': '${p[1]}',
      'to': '${p[2]}',
      'month': month,
    });
  }

  /// The name of Hebrew fast [id].
  static String _fastName(String id) => switch (id) {
    'gedaliah' => tr('Fast of Gedaliah'),
    'tevet' => tr('Tenth of Tevet'),
    'esther' => tr('Fast of Esther'),
    'tammuz' => tr('Seventeenth of Tammuz'),
    'tishabav' => tr("Tisha B'Av"),
    _ => tr('Yom Kippur'),
  };
}
