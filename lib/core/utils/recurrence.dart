/// ============================================================
/// RECURRENCE — a practical RFC 5545 RRULE subset
///
/// What: parses and serialises RRULE text (FREQ, INTERVAL, BYDAY,
/// BYMONTHDAY, BYMONTH, COUNT, UNTIL), expands occurrences and builds the
/// short labels shown by the repeat sheets ("Weekly · Tue", "Monthly · last
/// Fri").
///
/// Why: tasks (next due date when a repeating task is completed), reminders
/// (next trigger) and the calendar (occurrences in a month) all store one
/// RRULE string and must agree on what it means. Everything here is pure Dart
/// and DST-safe: calendar maths runs on UTC dates and every occurrence is
/// rebuilt as a local wall time with `DateTime(y, m, d, hh, mm, ss)`. Adding
/// `Duration`s to local DateTimes would drift by an hour across DST changes.
///
/// Expansion is period based (day / week / month / year, stepping by
/// INTERVAL). Without COUNT it jumps straight to the period containing the
/// requested instant, so "next after 2030" for a rule that began in 2020 is
/// instant; with COUNT it has to walk from DTSTART to count occurrences.
/// Rules that can never match (Feb 30th) give up after 5000 empty periods.
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:focusflow/core/utils/date_utils.dart';

/// How often a [RecurrenceRule] repeats (RRULE `FREQ`).
enum RecurrenceFrequency { daily, weekly, monthly, yearly }

/// RRULE weekday codes, indexed by `DateTime.weekday - 1`.
const _dayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

/// Consecutive periods without a single occurrence before the expansion
/// decides the rule can never match again (guards impossible rules).
const _maxEmptyPeriods = 5000;

/// One BYDAY entry: a weekday (`DateTime.monday`..`DateTime.sunday`) plus an
/// optional ordinal (`2TU` → ordinal 2, `-1FR` → ordinal -1, `TU` → null,
/// meaning every such weekday). Ordinals only matter for MONTHLY/YEARLY rules.
@immutable
class WeekdayRule {
  const WeekdayRule(this.weekday, [this.ordinal])
    : assert(weekday >= DateTime.monday && weekday <= DateTime.sunday),
      assert(ordinal != 0, 'BYDAY ordinal must not be 0');

  /// `DateTime.monday` (1) … `DateTime.sunday` (7).
  final int weekday;

  /// nth (positive) or nth-from-last (negative) such weekday; null = all.
  final int? ordinal;

  @override
  bool operator ==(Object other) =>
      other is WeekdayRule &&
      other.weekday == weekday &&
      other.ordinal == ordinal;

  @override
  int get hashCode => Object.hash(weekday, ordinal);

  /// RRULE form: `TU`, `2TU`, `-1FR`.
  @override
  String toString() => '${ordinal ?? ''}${_dayCodes[weekday - 1]}';
}

/// A parsed recurrence rule (RFC 5545 RRULE subset). Occurrences are always
/// anchored to a series start (DTSTART) passed into the query methods.
@immutable
class RecurrenceRule {
  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.byWeekdays = const [],
    this.byMonthDays = const [],
    this.byMonths = const [],
    this.count,
    this.until,
  }) : assert(interval >= 1, 'INTERVAL must be >= 1'),
       assert(count == null || count >= 1, 'COUNT must be >= 1');

  /// Every [interval] days.
  factory RecurrenceRule.daily({int interval = 1}) =>
      RecurrenceRule(frequency: RecurrenceFrequency.daily, interval: interval);

  /// Monday to Friday (`FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR`).
  factory RecurrenceRule.weekdays() => const RecurrenceRule(
    frequency: RecurrenceFrequency.weekly,
    byWeekdays: _monToFri,
  );

  /// Every [interval] weeks on [weekdays] (`DateTime.monday`… values). An
  /// empty set means "on the start's weekday".
  factory RecurrenceRule.weekly(Iterable<int> weekdays, {int interval = 1}) {
    final days = weekdays.toSet().toList()..sort();
    if (days.any((d) => d < DateTime.monday || d > DateTime.sunday)) {
      throw ArgumentError.value(weekdays, 'weekdays', 'must be 1 (Mon)..7');
    }
    return RecurrenceRule(
      frequency: RecurrenceFrequency.weekly,
      interval: interval,
      byWeekdays: List.unmodifiable([for (final d in days) WeekdayRule(d)]),
    );
  }

  /// Every [interval] months on [dayOfMonth] (1..31, or -1 = last day). Null
  /// means "on the start's day of month".
  factory RecurrenceRule.monthly({int? dayOfMonth, int interval = 1}) {
    if (dayOfMonth != null && !_isValidMonthDay(dayOfMonth)) {
      throw ArgumentError.value(dayOfMonth, 'dayOfMonth', 'must be ±1..31');
    }
    return RecurrenceRule(
      frequency: RecurrenceFrequency.monthly,
      interval: interval,
      byMonthDays: dayOfMonth == null
          ? const []
          : List.unmodifiable([dayOfMonth]),
    );
  }

  /// Every [interval] years on the start's month and day.
  factory RecurrenceRule.yearly({int interval = 1}) =>
      RecurrenceRule(frequency: RecurrenceFrequency.yearly, interval: interval);

  /// Parses RRULE text (optional `RRULE:` prefix, case-insensitive). Throws a
  /// [FormatException] for anything outside the supported subset.
  factory RecurrenceRule.parse(String rrule) {
    Never fail(String message) => throw FormatException(message, rrule);

    var body = rrule.trim();
    if (body.toUpperCase().startsWith('RRULE:')) body = body.substring(6);

    RecurrenceFrequency? frequency;
    var interval = 1;
    var byWeekdays = const <WeekdayRule>[];
    var byMonthDays = const <int>[];
    var byMonths = const <int>[];
    int? count;
    DateTime? until;
    final seen = <String>{};

    for (final rawPart in body.split(';')) {
      final part = rawPart.trim();
      if (part.isEmpty) continue;
      final eq = part.indexOf('=');
      if (eq <= 0 || eq == part.length - 1) fail('Malformed part "$part"');
      final key = part.substring(0, eq).trim().toUpperCase();
      final value = part.substring(eq + 1).trim().toUpperCase();
      if (!seen.add(key)) fail('Duplicate $key');
      // Unlisted keys (WKST, X-…) are harmless and ignored.
      switch (key) {
        case 'FREQ':
          frequency =
              RecurrenceFrequency.values.firstWhereOrNull(
                (f) => f.name.toUpperCase() == value,
              ) ??
              fail('Unsupported FREQ "$value"');
        case 'INTERVAL':
          interval = _parseInt(value, 1, 9999) ?? fail('Bad INTERVAL');
        case 'COUNT':
          count = _parseInt(value, 1, 1 << 30) ?? fail('Bad COUNT');
        case 'UNTIL':
          until = _parseUntil(value) ?? fail('Bad UNTIL "$value"');
        case 'BYDAY':
          byWeekdays =
              _parseList(value, _parseWeekdayRule) ?? fail('Bad BYDAY');
        case 'BYMONTHDAY':
          byMonthDays =
              _parseList(value, (t) {
                final day = _parseInt(t, -31, 31);
                return day != null && day != 0 ? day : null;
              }) ??
              fail('Bad BYMONTHDAY');
        case 'BYMONTH':
          byMonths =
              _parseList(value, (t) => _parseInt(t, 1, 12)) ??
              fail('Bad BYMONTH');
        // Parts that would change the meaning: refuse rather than mis-expand.
        case 'BYSETPOS' || 'BYYEARDAY' || 'BYWEEKNO':
        case 'BYHOUR' || 'BYMINUTE' || 'BYSECOND':
          fail('Unsupported $key');
      }
    }
    if (frequency == null) fail('Missing FREQ');
    return RecurrenceRule(
      frequency: frequency,
      interval: interval,
      byWeekdays: byWeekdays,
      byMonthDays: byMonthDays,
      byMonths: byMonths,
      count: count,
      until: until,
    );
  }

  /// RRULE `FREQ`.
  final RecurrenceFrequency frequency;

  /// RRULE `INTERVAL` (>= 1): every n-th day/week/month/year.
  final int interval;

  /// RRULE `BYDAY`. Ordinals are ignored for DAILY/WEEKLY rules.
  final List<WeekdayRule> byWeekdays;

  /// RRULE `BYMONTHDAY`: 1..31, or -1..-31 counted from the month's end.
  final List<int> byMonthDays;

  /// RRULE `BYMONTH`: 1..12.
  final List<int> byMonths;

  /// RRULE `COUNT`: total occurrences including the start.
  final int? count;

  /// RRULE `UNTIL` (local, inclusive). Exactly local midnight means "through
  /// the end of that day".
  final DateTime? until;

  static const _monToFri = [
    WeekdayRule(DateTime.monday),
    WeekdayRule(DateTime.tuesday),
    WeekdayRule(DateTime.wednesday),
    WeekdayRule(DateTime.thursday),
    WeekdayRule(DateTime.friday),
  ];

  /// Like [RecurrenceRule.parse] but returns null for null, empty or invalid
  /// text (callers treat that as "does not repeat").
  static RecurrenceRule? tryParse(String? rrule) {
    if (rrule == null || rrule.trim().isEmpty) return null;
    try {
      return RecurrenceRule.parse(rrule);
    } on FormatException {
      return null;
    }
  }

  /// Canonical RRULE text (no `RRULE:` prefix), parts ordered
  /// FREQ;INTERVAL;BYMONTH;BYMONTHDAY;BYDAY;COUNT;UNTIL, INTERVAL omitted
  /// when 1. A midnight UNTIL is written as a date, anything else in UTC.
  String toRRule() => [
    'FREQ=${frequency.name.toUpperCase()}',
    if (interval != 1) 'INTERVAL=$interval',
    if (byMonths.isNotEmpty) 'BYMONTH=${byMonths.join(',')}',
    if (byMonthDays.isNotEmpty) 'BYMONTHDAY=${byMonthDays.join(',')}',
    if (byWeekdays.isNotEmpty) 'BYDAY=${byWeekdays.join(',')}',
    if (count != null) 'COUNT=$count',
    if (until != null) 'UNTIL=${_formatUntil(until!)}',
  ].join(';');

  /// True for "every weekday" (weekly or daily on exactly Mon–Fri).
  bool get isWeekdays =>
      (frequency == RecurrenceFrequency.weekly ||
          frequency == RecurrenceFrequency.daily) &&
      interval == 1 &&
      byMonthDays.isEmpty &&
      byMonths.isEmpty &&
      const ListEquality<int>().equals(_weekdaySet(), const [1, 2, 3, 4, 5]);

  /// First occurrence strictly after [after]. [start] is the series anchor
  /// (DTSTART): occurrences happen at its local time of day and it is always
  /// occurrence #1, even if it doesn't match the BY* parts. Returns [start]
  /// when [after] is before it, and null once the series has ended
  /// (COUNT/UNTIL) or the rule can never match again.
  DateTime? nextAfter(DateTime start, DateTime after) {
    final anchor = start.toLocal();
    if (after.isBefore(anchor)) return anchor;
    for (final occurrence in _expand(anchor, after)) {
      if (occurrence.isAfter(after)) return occurrence;
    }
    return null;
  }

  /// All occurrences in `[from, to)` (from inclusive, to exclusive),
  /// ascending, at most [limit] of them.
  List<DateTime> occurrencesBetween(
    DateTime start,
    DateTime from,
    DateTime to, {
    int limit = 1000,
  }) {
    final result = <DateTime>[];
    if (limit <= 0 || !to.isAfter(from)) return result;
    for (final occurrence in _expand(start.toLocal(), from)) {
      if (!occurrence.isBefore(to)) break;
      if (occurrence.isBefore(from)) continue;
      result.add(occurrence);
      if (result.length >= limit) break;
    }
    return result;
  }

  /// Human label, e.g. "Weekly · Tue", "Monthly · last Fri · 5 times".
  /// [start] fills in implied parts (weekly without BYDAY → its weekday).
  String label({DateTime? start}) {
    final total = count;
    final end = until;
    return [
      ..._patternLabel(start?.toLocal()),
      if (total != null) total == 1 ? '1 time' : '$total times',
      if (end != null) 'until ${DateFormats.of('MMM d').format(end.toLocal())}',
    ].join(' · ');
  }

  /// Copy with some fields replaced; [clearCount]/[clearUntil] drop the end.
  RecurrenceRule copyWith({
    RecurrenceFrequency? frequency,
    int? interval,
    List<WeekdayRule>? byWeekdays,
    List<int>? byMonthDays,
    List<int>? byMonths,
    int? count,
    DateTime? until,
    bool clearCount = false,
    bool clearUntil = false,
  }) => RecurrenceRule(
    frequency: frequency ?? this.frequency,
    interval: interval ?? this.interval,
    byWeekdays: byWeekdays ?? this.byWeekdays,
    byMonthDays: byMonthDays ?? this.byMonthDays,
    byMonths: byMonths ?? this.byMonths,
    count: clearCount ? null : count ?? this.count,
    until: clearUntil ? null : until ?? this.until,
  );

  @override
  bool operator ==(Object other) =>
      other is RecurrenceRule &&
      other.frequency == frequency &&
      other.interval == interval &&
      other.count == count &&
      other.until?.microsecondsSinceEpoch == until?.microsecondsSinceEpoch &&
      const ListEquality<WeekdayRule>().equals(other.byWeekdays, byWeekdays) &&
      const ListEquality<int>().equals(other.byMonthDays, byMonthDays) &&
      const ListEquality<int>().equals(other.byMonths, byMonths);

  @override
  int get hashCode => Object.hash(
    frequency,
    interval,
    count,
    until?.microsecondsSinceEpoch,
    const ListEquality<WeekdayRule>().hash(byWeekdays),
    const ListEquality<int>().hash(byMonthDays),
    const ListEquality<int>().hash(byMonths),
  );

  @override
  String toString() => toRRule();

  // ---------------------------------------------------------------- expansion

  /// Every occurrence in ascending order, starting with [anchor]. Without
  /// COUNT the walk starts at the period containing [pivot]: earlier periods
  /// can only hold occurrences before it.
  Iterable<DateTime> _expand(DateTime anchor, DateTime pivot) sync* {
    final total = count;
    final untilEnd = _untilExclusive();
    yield anchor;
    var emitted = 1;
    if (total != null && emitted >= total) return;

    var period = total == null && pivot.isAfter(anchor)
        ? _periodContaining(anchor, pivot.toLocal())
        : 0;
    for (var empty = 0; empty < _maxEmptyPeriods; period++) {
      var found = false;
      for (final candidate in _candidates(anchor, period)) {
        if (!candidate.isAfter(anchor)) continue;
        if (untilEnd != null && !candidate.isBefore(untilEnd)) return;
        yield candidate;
        found = true;
        if (total != null && ++emitted >= total) return;
      }
      empty = found ? 0 : empty + 1;
    }
  }

  /// Index of the period (in units of [interval]) that contains [pivot].
  int _periodContaining(DateTime anchor, DateTime pivot) {
    final units = switch (frequency) {
      RecurrenceFrequency.daily => _dayDiff(anchor, pivot),
      RecurrenceFrequency.weekly =>
        _dayDiff(_mondayOf(anchor), _mondayOf(pivot)) ~/ 7,
      RecurrenceFrequency.monthly =>
        (pivot.year - anchor.year) * 12 + pivot.month - anchor.month,
      RecurrenceFrequency.yearly => pivot.year - anchor.year,
    };
    return units <= 0 ? 0 : units ~/ interval;
  }

  /// Sorted candidate occurrences of [period] (before filtering by start).
  List<DateTime> _candidates(DateTime anchor, int period) {
    final step = period * interval;
    switch (frequency) {
      case RecurrenceFrequency.daily:
        final day = DateTime.utc(anchor.year, anchor.month, anchor.day + step);
        final weekdayOk =
            byWeekdays.isEmpty ||
            byWeekdays.any((r) => r.weekday == day.weekday);
        return weekdayOk && _passesDayFilters(day)
            ? [_at(anchor, day)]
            : const [];
      case RecurrenceFrequency.weekly:
        final monday = _mondayOf(anchor);
        final weekdays = byWeekdays.isEmpty ? [anchor.weekday] : _weekdaySet();
        final result = <DateTime>[];
        for (final weekday in weekdays) {
          final day = DateTime.utc(
            monday.year,
            monday.month,
            monday.day + step * 7 + weekday - DateTime.monday,
          );
          if (_passesDayFilters(day)) result.add(_at(anchor, day));
        }
        return result;
      case RecurrenceFrequency.monthly:
        final month = DateTime.utc(anchor.year, anchor.month + step);
        if (byMonths.isNotEmpty && !byMonths.contains(month.month)) {
          return const [];
        }
        return _daysOfMonth(anchor, month.year, month.month);
      case RecurrenceFrequency.yearly:
        final year = anchor.year + step;
        final months = byMonths.isEmpty
            ? [anchor.month]
            : (byMonths.toSet().toList()..sort());
        return [for (final m in months) ..._daysOfMonth(anchor, year, m)];
    }
  }

  /// BYMONTH / BYMONTHDAY used as filters (DAILY and WEEKLY rules).
  bool _passesDayFilters(DateTime day) {
    if (byMonths.isNotEmpty && !byMonths.contains(day.month)) return false;
    if (byMonthDays.isEmpty) return true;
    final length = _daysInMonth(day.year, day.month);
    return byMonthDays.any((d) => _resolveMonthDay(d, length) == day.day);
  }

  /// Occurrences inside one month (MONTHLY/YEARLY): BYMONTHDAY ∩ BYDAY, or
  /// the start's day of month when neither is given (skipped if missing).
  List<DateTime> _daysOfMonth(DateTime anchor, int year, int month) {
    final length = _daysInMonth(year, month);
    Set<int>? days;
    if (byMonthDays.isNotEmpty) {
      days = {for (final d in byMonthDays) ?_resolveMonthDay(d, length)};
    }
    if (byWeekdays.isNotEmpty) {
      final matches = _weekdayDaysInMonth(year, month, length);
      days = days == null ? matches : days.intersection(matches);
    }
    days ??= {if (anchor.day <= length) anchor.day};
    final sorted = days.toList()..sort();
    return [for (final d in sorted) _at(anchor, DateTime.utc(year, month, d))];
  }

  /// Days of [month] matching BYDAY (with ordinals: 2TU, -1FR, TU = all).
  Set<int> _weekdayDaysInMonth(int year, int month, int length) {
    final firstWeekday = DateTime.utc(year, month).weekday;
    final result = <int>{};
    for (final rule in byWeekdays) {
      final first = 1 + (rule.weekday - firstWeekday + 7) % 7;
      final all = [for (var d = first; d <= length; d += 7) d];
      final ordinal = rule.ordinal;
      if (ordinal == null) {
        result.addAll(all);
      } else if (ordinal > 0 && ordinal <= all.length) {
        result.add(all[ordinal - 1]);
      } else if (ordinal < 0 && -ordinal <= all.length) {
        result.add(all[all.length + ordinal]);
      }
    }
    return result;
  }

  /// Exclusive end bound from UNTIL (a midnight UNTIL covers the whole day).
  DateTime? _untilExclusive() {
    final end = until?.toLocal();
    if (end == null) return null;
    if (_isLocalMidnight(end)) {
      return DateTime(end.year, end.month, end.day + 1);
    }
    // An instant, not a wall time, so adding a Duration is DST-safe here.
    return end.add(const Duration(microseconds: 1));
  }

  /// Distinct BYDAY weekdays (ordinals dropped), Mon..Sun.
  List<int> _weekdaySet() =>
      byWeekdays.map((r) => r.weekday).toSet().toList()..sort();

  // ------------------------------------------------------------------- labels

  List<String> _patternLabel(DateTime? start) {
    final unit = switch (frequency) {
      RecurrenceFrequency.daily => 'days',
      RecurrenceFrequency.weekly => 'weeks',
      RecurrenceFrequency.monthly => 'months',
      RecurrenceFrequency.yearly => 'years',
    };
    final every = 'Every $interval $unit';
    final monthNames = byMonths.map(_monthName).join(', ');
    switch (frequency) {
      case RecurrenceFrequency.daily || RecurrenceFrequency.weekly:
        final weekdays = byWeekdays.isNotEmpty
            ? _weekdaySet()
            : [
                if (frequency == RecurrenceFrequency.weekly && start != null)
                  start.weekday,
              ];
        final simple = interval == 1 && byMonthDays.isEmpty && byMonths.isEmpty;
        if (simple &&
            (weekdays.isNotEmpty || frequency == RecurrenceFrequency.weekly)) {
          return _weekdaysLabel(weekdays);
        }
        return [
          if (interval > 1)
            every
          else
            frequency == RecurrenceFrequency.daily ? 'Daily' : 'Weekly',
          if (weekdays.isNotEmpty) weekdays.map(_weekdayName).join(', '),
          if (byMonthDays.isNotEmpty)
            byMonthDays.map(_monthDayLabel).join(', '),
          if (byMonths.isNotEmpty) monthNames,
        ];
      case RecurrenceFrequency.monthly:
        return [
          interval == 1 ? 'Monthly' : every,
          ?_dayLabel(start),
          if (byMonths.isNotEmpty) monthNames,
        ];
      case RecurrenceFrequency.yearly:
        return [interval == 1 ? 'Yearly' : every, ?_yearDayLabel(start)];
    }
  }

  /// Interval-1 weekly label for a weekday set ("Weekdays", "Weekly · Tue").
  static List<String> _weekdaysLabel(List<int> weekdays) {
    if (weekdays.isEmpty) return ['Weekly'];
    if (weekdays.length == 7) return ['Daily'];
    if (const ListEquality<int>().equals(weekdays, const [1, 2, 3, 4, 5])) {
      return ['Weekdays'];
    }
    if (const ListEquality<int>().equals(weekdays, const [6, 7])) {
      return ['Weekends'];
    }
    return ['Weekly', weekdays.map(_weekdayName).join(', ')];
  }

  /// Day-of-month part ("14th", "last day", "2nd Tue"); null when unknown.
  String? _dayLabel(DateTime? start) {
    final parts = [
      ...byMonthDays.map(_monthDayLabel),
      ...byWeekdays.map(_weekdayRuleLabel),
    ];
    if (parts.isEmpty && start != null) parts.add(_ordinal(start.day));
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Yearly date part ("Jun 13", "last day of Feb", "2nd Sun of May").
  String? _yearDayLabel(DateTime? start) {
    final months = byMonths.isNotEmpty
        ? (byMonths.toSet().toList()..sort())
        : [if (start != null) start.month];
    final day = byWeekdays.isEmpty
        ? (byMonthDays.isEmpty ? start?.day : byMonthDays.singleOrNull)
        : null;
    if (months.length == 1 &&
        day != null &&
        day > 0 &&
        day <= _daysInMonth(2000, months.single)) {
      return DateFormats.of('MMM d').format(DateTime(2000, months.single, day));
    }
    final dayText = _dayLabel(start);
    final monthText = months.map(_monthName).join(', ');
    if (dayText == null) return monthText.isEmpty ? null : monthText;
    return monthText.isEmpty ? dayText : '$dayText of $monthText';
  }

  static String _monthDayLabel(int day) => switch (day) {
    -1 => 'last day',
    < 0 => '${_ordinal(-day)} to last day',
    _ => _ordinal(day),
  };

  static String _weekdayRuleLabel(WeekdayRule rule) {
    final name = _weekdayName(rule.weekday);
    return switch (rule.ordinal) {
      null => 'every $name',
      -1 => 'last $name',
      final n when n < 0 => '${_ordinal(-n)} to last $name',
      final n => '${_ordinal(n)} $name',
    };
  }

  // Jan 3, 2000 was a Monday; the year 2000 is a leap year (Feb 29 exists).
  static String _weekdayName(int weekday) =>
      DateFormats.of('EEE').format(DateTime(2000, 1, 2 + weekday));

  static String _monthName(int month) =>
      DateFormats.of('MMM').format(DateTime(2000, month));

  // ------------------------------------------------------------------ parsing

  static final _intPattern = RegExp(r'^[+-]?\d{1,10}$');
  static final _byDayPattern = RegExp(
    r'^([+-]?\d{1,2})?(MO|TU|WE|TH|FR|SA|SU)$',
  );
  static final _untilPattern = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$',
  );

  static int? _parseInt(String text, int min, int max) {
    if (!_intPattern.hasMatch(text)) return null;
    final value = int.parse(text);
    return value < min || value > max ? null : value;
  }

  /// Comma list → unmodifiable list, or null if empty or any item is bad.
  static List<T>? _parseList<T extends Object>(
    String text,
    T? Function(String token) parseOne,
  ) {
    final items = <T>[];
    for (final token in text.split(',')) {
      final item = parseOne(token.trim());
      if (item == null) return null;
      items.add(item);
    }
    return List.unmodifiable(items);
  }

  static WeekdayRule? _parseWeekdayRule(String token) {
    final match = _byDayPattern.firstMatch(token);
    if (match == null) return null;
    final ordinal = match[1] == null ? null : int.parse(match[1]!);
    if (ordinal == 0) return null;
    return WeekdayRule(_dayCodes.indexOf(match[2]!) + 1, ordinal);
  }

  /// `yyyyMMdd` (local midnight = whole day), `yyyyMMddTHHmmss` (local) or
  /// `yyyyMMddTHHmmssZ` (UTC, converted to local).
  static DateTime? _parseUntil(String text) {
    final match = _untilPattern.firstMatch(text);
    if (match == null) return null;
    final [y, mo, d] = [for (var i = 1; i <= 3; i++) int.parse(match[i]!)];
    if (mo < 1 || mo > 12 || d < 1 || d > _daysInMonth(y, mo)) return null;
    if (match[4] == null) return DateTime(y, mo, d);
    final [h, mi, s] = [for (var i = 4; i <= 6; i++) int.parse(match[i]!)];
    if (h > 23 || mi > 59 || s > 59) return null;
    return match[7] == null
        ? DateTime(y, mo, d, h, mi, s)
        : DateTime.utc(y, mo, d, h, mi, s).toLocal();
  }

  static String _formatUntil(DateTime value) {
    final local = value.toLocal();
    if (_isLocalMidnight(local)) return _ymd(local);
    final utc = value.toUtc();
    return '${_ymd(utc)}T${_two(utc.hour)}${_two(utc.minute)}'
        '${_two(utc.second)}Z';
  }
}

/// String-level helpers so callers can work with stored RRULE text directly.
/// Null or invalid text means "does not repeat".
abstract final class Recurrence {
  /// Next occurrence strictly after [after]; null for no/invalid rule or
  /// when the series has ended.
  static DateTime? nextAfter(String? rrule, DateTime start, DateTime after) =>
      RecurrenceRule.tryParse(rrule)?.nextAfter(start, after);

  /// Occurrences in `[from, to)`. Without a (valid) rule the item happens
  /// once, at [start].
  static List<DateTime> occurrencesBetween(
    String? rrule,
    DateTime start,
    DateTime from,
    DateTime to, {
    int limit = 1000,
  }) {
    final rule = RecurrenceRule.tryParse(rrule);
    if (rule != null) {
      return rule.occurrencesBetween(start, from, to, limit: limit);
    }
    final inRange = !start.isBefore(from) && start.isBefore(to);
    return [if (inRange && limit > 0) start];
  }

  /// Repeat label for the editors and lists; 'Once' for no/invalid rule.
  static String label(String? rrule, {DateTime? start}) =>
      RecurrenceRule.tryParse(rrule)?.label(start: start) ?? 'Once';

  /// Whether [rrule] is a valid repeating rule.
  static bool isRepeating(String? rrule) =>
      RecurrenceRule.tryParse(rrule) != null;
}

// ------------------------------------------------------------- date helpers

bool _isValidMonthDay(int day) => day != 0 && day >= -31 && day <= 31;

int _daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// Day number for a BYMONTHDAY value (negative = from the end), or null when
/// that day doesn't exist in a month of [length] days (e.g. 31 in April).
int? _resolveMonthDay(int day, int length) {
  if (day > 0) return day <= length ? day : null;
  return -day <= length ? length + day + 1 : null;
}

/// Whole calendar days from [a]'s date to [b]'s date (DST-proof via UTC).
int _dayDiff(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Monday (as a UTC date) of the ISO week containing [d]'s date.
DateTime _mondayOf(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day - (d.weekday - DateTime.monday));

/// [day]'s calendar date at [anchor]'s local wall-clock time.
DateTime _at(DateTime anchor, DateTime day) => DateTime(
  day.year,
  day.month,
  day.day,
  anchor.hour,
  anchor.minute,
  anchor.second,
  anchor.millisecond,
  anchor.microsecond,
);

bool _isLocalMidnight(DateTime d) =>
    !d.isUtc &&
    d.hour == 0 &&
    d.minute == 0 &&
    d.second == 0 &&
    d.millisecond == 0 &&
    d.microsecond == 0;

String _two(int n) => n.toString().padLeft(2, '0');

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${_two(d.month)}${_two(d.day)}';

String _ordinal(int n) {
  final lastTwo = n % 100;
  if (lastTwo >= 11 && lastTwo <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}
