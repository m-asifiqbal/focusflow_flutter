/// ============================================================
/// QUICK CAPTURE PARSER — "Pay rent tomorrow 9am" → reminder
/// ============================================================
///
/// What: a local, rule-based English parser for the Quick Add capture field
/// (screen 04). It recognises
///   * days: today · tonight · tomorrow · day after tomorrow · weekdays
///     ("fri", "on Monday", "next tue") · next week / month · weekend ·
///     "Jun 20" / "20 June" / "the 15th" / ISO dates · "in N days/weeks/months"
///   * times: 9am · 9:30 pm · 21:30 · at 9 · noon · midnight · "in the
///     evening" · "in 2 hours" / "in 30 min"
///   * repeats: every day / week / month / year / other week / weekday /
///     Monday and Wednesday · daily / weekly …
///   * `#tags`, priorities (`!high` `!m` `!!!` `p1`), leading "remind me to".
/// Every recognised token is removed; what is left is the title.
///
/// Kind (prompt 04): a time → Reminder; a date, repeat or priority without a
/// time → Task; otherwise a Note.
///
/// Why: two-tap capture without any network or ML — deterministic, fast and
/// fully unit-tested (test/features/quick_add/domain/).
/// ============================================================
library;

import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/utils/recurrence.dart';
import 'package:focusflow/features/quick_add/domain/entities/quick_capture.dart';
import 'package:focusflow/features/quick_add/domain/services/quick_capture_patterns.dart';

typedef _P = QuickCapturePatterns;
typedef _W = QuickCaptureWords;

class QuickCaptureParser {
  const QuickCaptureParser({
    this.weekStartsOn = DateTime.monday,
    this.defaultReminderMinutes = 9 * 60,
  });

  /// `DateTime.monday`…: anchors "next week" / "next Tuesday".
  final int weekStartsOn;

  /// Time used by "remind me to …" phrases that name no time.
  final int defaultReminderMinutes;

  /// Parses [input] relative to [now]. [defaultDay] (Calendar long-press)
  /// is used when the phrase names no day.
  QuickCapture parse(String input, DateTime now, {DateTime? defaultDay}) {
    final s = _Scan(input);
    final today = DateUtilsX.dateOnly(now);
    final nowMinutes = now.hour * 60 + now.minute;

    // ── Tags, priority, "remind me" ──
    final tags = <String>[];
    for (final m in s.takeAll(_P.tag)) {
      final t = m[1]!;
      if (!tags.any((x) => x.toLowerCase() == t.toLowerCase())) tags.add(t);
    }
    final priority = _priority(s.take(_P.priority));
    final forceReminder = s.take(_P.remindMe) != null;

    // ── Repeat ──
    final repeat = _repeat(s);
    String? pod = repeat?.partOfDay;

    // ── Day ──
    DateTime? day;
    Duration? offset;
    var rollIfPast = false;
    if (s.take(_P.inHalfHour) != null) {
      offset = const Duration(minutes: 30);
    } else if (s.take(_P.inOffset) case final m?) {
      final n = m[1] != null ? int.parse(m[1]!) : _W.number(m[2]!);
      final unit = m[3]!.toLowerCase();
      if (unit.startsWith('mo')) {
        day = _W.addMonths(today, n);
      } else if (unit.startsWith('m')) {
        offset = Duration(minutes: n);
      } else if (unit.startsWith('h')) {
        offset = Duration(hours: n);
      } else if (unit.startsWith('d')) {
        day = DateUtilsX.addDays(today, n);
      } else {
        day = DateUtilsX.addDays(today, 7 * n);
      }
    }
    if (day == null && offset == null) {
      (day, pod, rollIfPast) = _day(s, today, pod);
    }

    // ── Time ──
    var (time, ambiguous) = _time(s);
    if (s.take(_P.partOfDay) case final m?) pod ??= m[1];
    if (time == null && pod != null) {
      time = _W.partOfDayMinutes(pod);
    } else if (time != null &&
        ambiguous &&
        time < 12 * 60 &&
        const {'afternoon', 'evening', 'night'}.contains(pod?.toLowerCase())) {
      time += 12 * 60;
    }
    if (offset != null) {
      final at = now.add(offset);
      day = DateUtilsX.dateOnly(at);
      time ??= at.hour * 60 + at.minute;
    }

    // ── Resolve ──
    String? rrule;
    if (repeat != null) {
      day ??= repeat.firstDay(today);
      rrule = repeat.rule(day).toRRule();
    }
    if (forceReminder) time ??= defaultReminderMinutes;
    if (time != null && day == null) {
      day = defaultDay != null
          ? DateUtilsX.dateOnly(defaultDay)
          : (time > nowMinutes ? today : DateUtilsX.addDays(today, 1));
    }
    if (rollIfPast &&
        time != null &&
        day == today &&
        time <= nowMinutes &&
        repeat == null) {
      day = DateUtilsX.addDays(today, 7);
    }
    if (day == null && defaultDay != null) {
      day = DateUtilsX.dateOnly(defaultDay);
    }

    final kind = time != null
        ? QuickCaptureKind.reminder
        : (day != null || priority != null || rrule != null)
        ? QuickCaptureKind.task
        : QuickCaptureKind.note;
    return QuickCapture(
      title: _title(s.text, consumed: s.consumed),
      kind: kind,
      day: day,
      timeMinutes: time,
      priority: priority,
      tags: List.unmodifiable(tags),
      repeatRule: rrule,
    );
  }

  static int? _priority(RegExpMatch? m) {
    if (m == null) return null;
    if (m[2] != null) return m[2]!.length;
    if (m[3] != null) return 4 - int.parse(m[3]!);
    final w = m[1]!.toLowerCase();
    if (w.startsWith('h') || w == 'urgent') return 3;
    if (w.startsWith('m')) return 2;
    return 1;
  }

  static _Repeat? _repeat(_Scan s) {
    if (s.take(_P.everyWeekday) != null) return const _Repeat.weekdays();
    if (s.take(_P.everyWeekend) != null) {
      return const _Repeat.weekly([DateTime.saturday, DateTime.sunday]);
    }
    if (s.take(_P.everyWeekdays) case final m?) {
      final days = [
        for (final w in m[1]!.split(RegExp(r'[^A-Za-z]+')))
          if (w.length >= 3 && w.toLowerCase() != 'and') _W.weekday(w),
      ];
      return _Repeat.weekly(days, partOfDay: m[2]);
    }
    if (s.take(_P.everyPartOfDay) case final m?) {
      return _Repeat(RecurrenceFrequency.daily, partOfDay: m[1]);
    }
    if (s.take(_P.everyInterval) case final m?) {
      final interval = m[1] != null ? 2 : int.tryParse(m[2] ?? '') ?? 1;
      return _Repeat(_frequency(m[3]!), interval: interval < 1 ? 1 : interval);
    }
    if (s.take(_P.repeatWord) case final m?) {
      final w = m[1]!.toLowerCase();
      return _Repeat(
        w == 'annually' ? RecurrenceFrequency.yearly : _frequency(w),
      );
    }
    return null;
  }

  static RecurrenceFrequency _frequency(String w) =>
      switch (w.toLowerCase().substring(0, 2)) {
        'da' => RecurrenceFrequency.daily,
        'we' => RecurrenceFrequency.weekly,
        'mo' => RecurrenceFrequency.monthly,
        _ => RecurrenceFrequency.yearly,
      };

  /// The phrase's day (if any), part of day and whether a bare weekday that
  /// is today should roll a week when its time has passed.
  (DateTime?, String?, bool) _day(_Scan s, DateTime today, String? pod) {
    if (s.take(_P.dayWord) case final m?) {
      final w = m[1]!.toLowerCase();
      final p = m[2] ?? (w == 'tonight' ? 'night' : null);
      final add = w.contains('after')
          ? 2
          : (w == 'today' || w == 'tonight')
          ? 0
          : 1;
      return (DateUtilsX.addDays(today, add), pod ?? p, false);
    }
    if (s.take(_P.relativePeriod) case final m?) {
      final which = m[1]!.toLowerCase();
      final period = m[2]!.toLowerCase();
      final next = which != 'this';
      final day = switch (period) {
        'week' => DateUtilsX.addDays(
          DateUtilsX.startOfWeek(today, weekStartsOn),
          next ? 7 : 6,
        ),
        'month' =>
          next
              ? DateTime(today.year, today.month + 1)
              : DateTime(today.year, today.month + 1, 0),
        _ =>
          which == 'next'
              ? _W.nextWeeks(today, DateTime.saturday, weekStartsOn)
              : _weekend(today),
      };
      return (day, pod, false);
    }
    if (s.take(_P.weekend) != null) return (_weekend(today), pod, false);
    final wd = s.take(
      _P.weekday,
      // "sat", "sun", "wed" alone are ordinary words; they need a lead-in.
      accept: (m) =>
          !m[0]!.toLowerCase().startsWith(m[2]!.toLowerCase()) ||
          !_W.ambiguousWeekdays.contains(m[2]!.toLowerCase()),
    );
    if (wd != null) {
      final weekday = _W.weekday(wd[2]!);
      final next = wd[1]?.toLowerCase() == 'next';
      final day = next
          ? _W.nextWeeks(today, weekday, weekStartsOn)
          : _W.upcoming(today, weekday);
      return (day, pod ?? wd[3], !next);
    }
    if (s.take(_P.isoDate) case final m?) {
      final d = _W.validDay(
        int.parse(m[1]!),
        int.parse(m[2]!),
        int.parse(m[3]!),
      );
      if (d != null) return (d, pod, false);
    }
    final md = s.take(
      _P.monthDay,
      accept: (m) => _dateOf(m[1]!, m[2]!, m[3], today) != null,
    );
    if (md != null) return (_dateOf(md[1]!, md[2]!, md[3], today), pod, false);
    final dm = s.take(
      _P.dayMonth,
      accept: (m) => _dateOf(m[2]!, m[1]!, m[3], today) != null,
    );
    if (dm != null) return (_dateOf(dm[2]!, dm[1]!, dm[3], today), pod, false);
    final od = s.take(
      _P.ordinalDay,
      accept: (m) => int.parse(m[1]!) >= 1 && int.parse(m[1]!) <= 31,
    );
    if (od != null) {
      final n = int.parse(od[1]!);
      var month = DateTime(today.year, today.month);
      for (var i = 0; i < 12; i++) {
        final d = _W.validDay(month.year, month.month, n);
        if (d != null && !d.isBefore(today)) return (d, pod, false);
        month = DateTime(month.year, month.month + 1);
      }
    }
    return (null, pod, false);
  }

  static DateTime _weekend(DateTime today) => today.weekday == DateTime.sunday
      ? today
      : _W.upcoming(today, DateTime.saturday);

  /// "Jun" "20" [year] → the next such day on or after [today].
  static DateTime? _dateOf(
    String month,
    String day,
    String? year,
    DateTime today,
  ) {
    final m = _W.month(month);
    final d = int.parse(day);
    if (year != null) return _W.validDay(int.parse(year), m, d);
    final thisYear = _W.validDay(today.year, m, d);
    if (thisYear != null && !thisYear.isBefore(today)) return thisYear;
    return _W.validDay(today.year + 1, m, d);
  }

  /// Explicit time in minutes and whether its am/pm was implied.
  static (int?, bool) _time(_Scan s) {
    if (s.take(_P.amPm, accept: (m) => _amPm(m) != null) case final m?) {
      return (_amPm(m), false);
    }
    if (s.take(_P.clock24) case final m?) {
      final h = int.parse(m[1]!);
      return (h * 60 + int.parse(m[2]!), h < 12);
    }
    if (s.take(_P.atHour, accept: (m) => int.parse(m[1] ?? m[2]!) <= 23)
        case final m?) {
      final h = int.parse(m[1] ?? m[2]!);
      // "at 3" means 3 pm; 7–11 mornings; 12 noon; 13–23 as written.
      final hour = h >= 1 && h <= 6 ? h + 12 : h;
      return (hour * 60, hour < 12);
    }
    if (s.take(_P.noonMidnight) case final m?) {
      return (m[1]!.toLowerCase() == 'midnight' ? 0 : 12 * 60, false);
    }
    return (null, false);
  }

  static int? _amPm(RegExpMatch m) {
    final h = int.parse(m[1]!);
    final min = int.parse(m[2] ?? '0');
    if (h < 1 || h > 12 || min > 59) return null;
    final pm = m[3]!.toLowerCase().startsWith('p');
    return ((h % 12) + (pm ? 12 : 0)) * 60 + min;
  }

  static String _title(String text, {required bool consumed}) {
    var t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (consumed) {
      while (true) {
        final m = _P.danglingEnd.firstMatch(t);
        if (m == null) break;
        t = t.substring(0, m.start).trim();
      }
      t = t.replaceFirst(_P.danglingStart, '');
    }
    t = t.replaceAllMapped(_P.spaceBeforePunct, (m) => m[1]!).trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }
}

/// A recognised "every …" phrase, turned into an RRULE once the day is known.
class _Repeat {
  const _Repeat(this.frequency, {this.interval = 1, this.partOfDay})
    : weekdays = const [],
      workweek = false;
  const _Repeat.weekly(this.weekdays, {this.partOfDay})
    : frequency = RecurrenceFrequency.weekly,
      interval = 1,
      workweek = false;
  const _Repeat.weekdays()
    : frequency = RecurrenceFrequency.weekly,
      interval = 1,
      weekdays = const [],
      partOfDay = null,
      workweek = true;

  final RecurrenceFrequency frequency;
  final int interval;
  final List<int> weekdays;
  final bool workweek;
  final String? partOfDay;

  /// First occurrence on or after [today].
  DateTime firstDay(DateTime today) {
    final days = workweek ? const [1, 2, 3, 4, 5] : weekdays;
    if (days.isEmpty) return today;
    return [
      for (final d in days) _W.upcoming(today, d),
    ].reduce((a, b) => a.isBefore(b) ? a : b);
  }

  RecurrenceRule rule(DateTime day) {
    if (workweek) return RecurrenceRule.weekdays();
    return switch (frequency) {
      RecurrenceFrequency.daily => RecurrenceRule.daily(interval: interval),
      RecurrenceFrequency.weekly => RecurrenceRule.weekly(
        weekdays.isEmpty ? [day.weekday] : weekdays,
        interval: interval,
      ),
      RecurrenceFrequency.monthly => RecurrenceRule.monthly(
        dayOfMonth: day.day,
        interval: interval,
      ),
      RecurrenceFrequency.yearly => RecurrenceRule.yearly(interval: interval),
    };
  }
}

/// The phrase being parsed; recognised tokens are blanked out in place so
/// later patterns can't re-match them and the remainder is the title.
class _Scan {
  _Scan(String input) : text = input.replaceAll(RegExp(r'\s'), ' ');

  String text;
  bool consumed = false;

  /// First match of [re] that [accept] allows; blanks it out.
  RegExpMatch? take(RegExp re, {bool Function(RegExpMatch m)? accept}) {
    for (final m in re.allMatches(text)) {
      if (m.end == m.start || (accept != null && !accept(m))) continue;
      _blank(m.start, m.end);
      return m;
    }
    return null;
  }

  /// Every match of [re]; all blanked out.
  List<RegExpMatch> takeAll(RegExp re) {
    final all = re.allMatches(text).where((m) => m.end > m.start).toList();
    for (final m in all) {
      _blank(m.start, m.end);
    }
    return all;
  }

  void _blank(int start, int end) {
    text = text.replaceRange(start, end, ' ' * (end - start));
    consumed = true;
  }
}
