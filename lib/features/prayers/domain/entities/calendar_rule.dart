/// ============================================================
/// CALENDAR RULE — "repeat on the days of a religious calendar"
/// ============================================================
///
/// What: a practice that repeats by a calendar instead of by weekday — Hijri
/// days (Ramadan, Ayyam al-Bid, Arafah, Ashura, the six of Shawwal, the Eids),
/// the Hebrew fast days / Rosh Chodesh / the Omer / Chanukah, the Christian
/// seasons (Lent, Holy Week, Advent, the Orthodox Great Lent, the fixed-date
/// fasts) and the lunar days (Ekadashi, Pradosh, Sankashti, Purnima,
/// Amavasya; the Uposatha moon days). A rule is a short text key plus a
/// [shift] of −1 / 0 / +1 days — the person's local correction, because
/// moon-based days differ by region and almanac.
/// Why a text key: it is stored in one nullable column (`calendar_rule`),
/// travels in backups and exports unchanged, and an older install that does
/// not know it simply ignores it. The matching lives in
/// `CalendarRules` (domain/services), pure Dart.
///
/// Keys (`name:arg`):
///  * `hspan:M-D1-D2` — Hijri month M, days D1 – D2 (Ramadan `9-1-30`,
///    Arafah `12-9-9`, six of Shawwal `10-2-7`)
///  * `hdays:13,14,15` — those days of every Hijri month (Ayyam al-Bid)
///  * `hfast:id` — a Hebrew fast day (HebrewCalendar.fastIds)
///  * `hebrew:roshchodesh` | `hebrew:omer` | `hebrew:chanukah`
///  * `season:lent` (Ash Wednesday – Holy Saturday, Sundays excluded) |
///    `season:holyweek` | `season:advent` | `season:eastertide` |
///    `season:greatlent` (Orthodox, from Clean Monday)
///  * `fixed:M-D..M-D` — a civil date range, wrapping the year end
///  * `tithi:11,26` / `tithi:13,28@18` — tithis at sunrise (06:00) or at
///    the hour after `@`
///  * `moon:0,1,2,3` — the days of new / first quarter / full / last quarter
/// ============================================================
library;

import 'package:flutter/foundation.dart';

@immutable
class CalendarRule {
  const CalendarRule(this.key, {this.shift = 0});

  /// The rule's text key (see the library header).
  final String key;

  /// The local correction in days, −1 … +1 (later = +1).
  final int shift;

  /// The part before the colon.
  String get kind {
    final i = key.indexOf(':');
    return i < 0 ? key : key.substring(0, i);
  }

  /// The part after the colon.
  String get arg {
    final i = key.indexOf(':');
    return i < 0 ? '' : key.substring(i + 1);
  }

  /// Hijri, lunar or moon-day rules depend on sighting or an almanac: the UI
  /// says "approximate — confirm locally" and offers the ±1 day nudge.
  /// (Hebrew and Easter-based rules are exact arithmetic.)
  bool get approximate => switch (kind) {
    'hspan' || 'hdays' || 'tithi' || 'moon' => true,
    'fixed' => false,
    _ => false,
  };

  /// The nudge is meaningful (every rule but the exact ones).
  bool get canNudge => approximate;

  CalendarRule withShift(int s) =>
      CalendarRule(key, shift: s.clamp(-1, 1).toInt());

  /// "key" or "key|shift" — the stored text.
  String get serialized => shift == 0 ? key : '$key|$shift';

  /// Parses the stored text; null for blank or malformed text.
  static CalendarRule? parse(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    final parts = t.split('|');
    final key = parts.first.trim();
    if (!key.contains(':') && !_bare.contains(key)) return null;
    final shift = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return CalendarRule(key, shift: shift.clamp(-1, 1).toInt());
  }

  static const Set<String> _bare = {};

  @override
  bool operator ==(Object other) =>
      other is CalendarRule && other.key == key && other.shift == shift;

  @override
  int get hashCode => Object.hash(key, shift);

  @override
  String toString() => 'CalendarRule($serialized)';
}
