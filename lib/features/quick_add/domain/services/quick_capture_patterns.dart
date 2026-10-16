/// ============================================================
/// QUICK CAPTURE PATTERNS — the vocabulary of the quick-capture parser
/// ============================================================
///
/// What: every regular expression and word table [QuickCaptureParser]
/// understands (English): tags, priorities, "remind me", repeats, relative
/// offsets, day words, weekdays, month dates and times, plus the small date
/// helpers that turn a match into a calendar day.
///
/// Why separate: keeps the parser's resolution logic readable and each
/// pattern documented in one place. Pure Dart, no Flutter.
/// ============================================================
library;

import 'package:focusflow/core/utils/date_utils.dart';

RegExp _re(String source) =>
    RegExp(source, caseSensitive: false, unicode: true);

const _wd =
    r'(?:monday|mon|tuesday|tues|tue|wednesday|weds|wed|thursday|thurs|thur|'
    r'thu|friday|fri|saturday|sat|sunday|sun)';
const _month =
    r'(?:january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|'
    r'august|aug|september|sept|sep|october|oct|november|nov|december|dec)';

/// Optional lead-in word that belongs to the date ("on Monday", "by Fri").
const _lead = r'(?:(?:due\s+on|on|by|due|before|until|for)\s+)?';

/// Optional part of day after a day word ("tomorrow evening").
const _pod = r'(?:\s+(?:in\s+the\s+)?(morning|afternoon|evening|night))?';

const _numberWords =
    r'an?|one|two|three|four|five|six|seven|eight|nine|ten|'
    r'eleven|twelve';

abstract final class QuickCapturePatterns {
  /// `#home`, `#side-project` → group 1 is the tag.
  static final tag = _re(r'(?<=^|\s)#([\p{L}\p{N}_\-/]+)');

  /// `!high` `!h` `!!!` `p1` … → group 1 word, group 2 bangs, group 3 pN.
  static final priority = _re(
    r'(?<=^|\s)(?:!(high|hi|h|urgent|medium|med|m|low|lo|l)|(!{1,3})|p([1-3]))'
    r'(?=\s|$)',
  );

  /// Leading "remind me (to|about)" — forces a reminder.
  static final remindMe = _re(
    r'^\s*(?:please\s+)?remind\s+me\b(?:\s+(?:to|about|that)\b)?',
  );

  // ── Repeats ──
  static final everyWeekday = _re(r'\bevery\s+weekdays?\b');
  static final everyWeekend = _re(r'\bevery\s+weekends?\b');

  /// "every mon and wed" → group 1 is the weekday list.
  static final everyWeekdays = _re(
    '\\bevery\\s+($_wd\\b(?:\\s*(?:,|and|&)\\s*$_wd\\b)*)$_pod',
  );

  /// "every morning" → daily at the part of day.
  static final everyPartOfDay = _re(
    r'\bevery\s+(morning|afternoon|evening|night)\b',
  );

  /// "every day", "every other week", "every 3 months".
  static final everyInterval = _re(
    r'\bevery\s+(?:(other)\s+|(\d{1,2})\s+)?(day|week|month|year)s?\b',
  );
  static final repeatWord = _re(r'\b(daily|weekly|monthly|yearly|annually)\b');

  // ── Relative offsets ──
  static final inHalfHour = _re(r'\bin\s+half\s+an?\s+hour\b');

  /// "in 2 days", "in an hour", "in 30min" → group 1 digits, 2 word, 3 unit.
  static final inOffset = _re(
    '\\bin\\s+(?:(\\d{1,3})\\s*|($_numberWords)\\s+)'
    r'(minutes?|mins?|hours?|hrs?|h|days?|weeks?|wks?|months?)\b',
  );

  // ── Days ──
  /// group 1 day word, group 2 part of day.
  static final dayWord = _re(
    '\\b$_lead((?:the\\s+)?day\\s+after\\s+tomorrow|today|tonight|tomorrow|'
    'tomorow|tmrw|tmr)\\b$_pod',
  );

  /// "next week", "this weekend", "next month" → group 1, group 2.
  static final relativePeriod = _re(
    '\\b$_lead(next|this|coming)\\s+(week|weekend|month)\\b',
  );
  static final weekend = _re('\\b$_lead(?:the\\s+)?weekend\\b');

  /// group 1 next/this, group 2 weekday, group 3 part of day.
  static final weekday = _re(
    '\\b$_lead(?:(next|this|coming)\\s+)?($_wd)\\b$_pod',
  );

  /// "Jun 20", "june 20th, 2027" → group 1 month, 2 day, 3 year.
  static final monthDay = _re(
    '\\b$_lead($_month)\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b'
    r'(?:,?\s+(\d{4})\b)?',
  );

  /// "20 June", "the 3rd of May" → group 1 day, 2 month, 3 year.
  static final dayMonth = _re(
    '\\b$_lead(?:the\\s+)?(\\d{1,2})(?:st|nd|rd|th)?\\s+(?:of\\s+)?($_month)\\b'
    r'(?:,?\s+(\d{4})\b)?',
  );

  /// "on the 15th" → group 1 day of month.
  static final ordinalDay = _re(
    r'\b(?:(?:on|by|due)\s+)?the\s+(\d{1,2})(?:st|nd|rd|th)\b',
  );

  /// ISO `2026-10-20` → groups 1-3.
  static final isoDate = _re(r'\b(\d{4})-(\d{2})-(\d{2})\b');

  // ── Times ──
  /// "9am", "9:30 pm", "at 7.15a.m." → group 1 hour, 2 minute, 3 am/pm.
  static final amPm = _re(
    r'(?<![\p{L}\p{N}:.])(?:at\s+|@\s*)?(\d{1,2})(?:[:.](\d{2}))?\s*'
    r'(a\.?m\.?|p\.?m\.?)(?![\p{L}\p{N}])',
  );

  /// "21:30", "at 9:05" → group 1 hour, 2 minute.
  static final clock24 = _re(
    r'(?<![\p{L}\p{N}:.])(?:at\s+|@\s*)?([01]?\d|2[0-3]):([0-5]\d)'
    r'(?![\p{N}:])',
  );

  /// "at 9", "@ 18", "5 o'clock" → group 1 or 2 is the hour.
  static final atHour = _re(
    r"(?:\bat\s+|@\s*)(\d{1,2})(?![\p{L}\p{N}:%.])|"
    r"\b(\d{1,2})\s*o['’]?clock\b",
  );
  static final noonMidnight = _re(r'\b(?:at\s+)?(noon|midday|midnight)\b');
  static final partOfDay = _re(
    r'\b(?:in\s+the|this)\s+(morning|afternoon|evening)\b',
  );

  /// Words left dangling at the end of a title once tokens are removed.
  static final danglingEnd = _re(
    r'(?:(?:^|\s)(?:at|on|by|due|in|for|from|every|this|next|the|before|'
    r'until|and|&|@)|\s*[,;:\-–—])$',
  );
  static final danglingStart = _re(r'^(?:[,;:\-–—]|and\b)\s*');
  static final spaceBeforePunct = _re(r'\s+([,;:.!?])');
}

/// Shared word tables and day maths for the parser.
abstract final class QuickCaptureWords {
  /// `DateTime.monday`… for a weekday name / abbreviation.
  static int weekday(String name) =>
      switch (name.toLowerCase().substring(0, 3)) {
        'mon' => DateTime.monday,
        'tue' => DateTime.tuesday,
        'wed' => DateTime.wednesday,
        'thu' => DateTime.thursday,
        'fri' => DateTime.friday,
        'sat' => DateTime.saturday,
        _ => DateTime.sunday,
      };

  /// 1–12 for a month name / abbreviation.
  static int month(String name) => const {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  }[name.toLowerCase().substring(0, 3)]!;

  /// "a" / "an" / "one" … "twelve" → number.
  static int number(String word) => switch (word.toLowerCase()) {
    'a' || 'an' || 'one' => 1,
    'two' => 2,
    'three' => 3,
    'four' => 4,
    'five' => 5,
    'six' => 6,
    'seven' => 7,
    'eight' => 8,
    'nine' => 9,
    'ten' => 10,
    'eleven' => 11,
    _ => 12,
  };

  /// Minutes after midnight for a part of day.
  static int partOfDayMinutes(String pod) => switch (pod.toLowerCase()) {
    'morning' => 9 * 60,
    'afternoon' => 15 * 60,
    'evening' => 18 * 60,
    _ => 20 * 60,
  };

  /// Abbreviations that are also ordinary words: only dates with a lead-in
  /// ("on sat", "next wed").
  static const ambiguousWeekdays = {'sat', 'sun', 'wed', 'mar'};

  /// The next [weekday] on or after [today].
  static DateTime upcoming(DateTime today, int weekday) =>
      DateUtilsX.addDays(today, (weekday - today.weekday + 7) % 7);

  /// [weekday] in the week after the one containing [today].
  static DateTime nextWeeks(DateTime today, int weekday, int weekStartsOn) {
    final start = DateUtilsX.addDays(
      DateUtilsX.startOfWeek(today, weekStartsOn),
      7,
    );
    return DateUtilsX.addDays(start, (weekday - weekStartsOn + 7) % 7);
  }

  /// [day] plus [months] calendar months, clamped to the month's last day.
  static DateTime addMonths(DateTime day, int months) {
    final first = DateTime(day.year, day.month + months);
    final last = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, day.day > last ? last : day.day);
  }

  /// A valid local day or null ("Feb 30").
  static DateTime? validDay(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1) return null;
    if (day > DateTime(year, month + 1, 0).day) return null;
    return DateTime(year, month, day);
  }
}
