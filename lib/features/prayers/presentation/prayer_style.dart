/// ============================================================
/// PRAYER STYLE — colours, sizes and wording shared by the Prayer screens
/// ============================================================
///
/// What: a prayer's own colour (its `colorHex`, else the module teal),
/// status colours (on time / late / made up / missed / excused) read from
/// the theme tokens, and the formatters every Prayer widget uses: a time,
/// a window ("3:42 – 5:21 PM"), a duration ("1h 39m") and "in 1h 12m" /
/// "ends in 18 min".
/// Why: one place, so the tab, editor, sheets and Home card read alike and
/// dark mode / the accent work everywhere for free.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/calendar_rules.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_stats.dart';
import 'package:focusflow/features/prayers/domain/services/tradition_profile.dart';

abstract final class PrayerStyle {
  static ModuleColors get module => ModuleStyle.prayers.colors;

  /// Colours a prayer can be given in the editor (RRGGBB).
  static const List<String> palette = [
    '3B82F6',
    'F59E0B',
    '10B981',
    'F97316',
    '6366F1',
    '0EA5E9',
    '8B5CF6',
    'EC4899',
    '14B8A6',
    'D97706',
    'EF4444',
    '64748B',
  ];

  /// The prayer's own colour (module teal when unset / unreadable).
  static Color of(Prayer p) => hex(p.colorHex) ?? module.solid;

  static Color? hex(String? rrggbb) {
    if (rrggbb == null || rrggbb.length != 6) return null;
    final v = int.tryParse(rrggbb, radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }

  /// Fill of a week-grid cell.
  static Color cell(FFColors ff, PrayerCell c) => switch (c) {
    PrayerCell.onTime => ff.success,
    PrayerCell.late => ff.warning,
    PrayerCell.madeUp => Color.lerp(ff.success, ff.warning, 0.35)!,
    PrayerCell.missed => ff.danger,
    PrayerCell.excused => ff.inkFaint,
    PrayerCell.pending => ff.surfaceMuted,
    // Scale (not replace) the alpha: dark surfaceMuted is already a faint
    // white, and a flat 0.4 would read as "Excused" grey.
    PrayerCell.none => ff.surfaceMuted.withValues(
      alpha: ff.surfaceMuted.a * 0.4,
    ),
  };

  /// Colour of a slot's state chip.
  static Color state(FFColors ff, PrayerSlotState s) => switch (s) {
    PrayerSlotState.done => ff.success,
    PrayerSlotState.missed => ff.danger,
    PrayerSlotState.endingSoon => ff.warning,
    PrayerSlotState.open => ff.primary,
    PrayerSlotState.excused || PrayerSlotState.upcoming => ff.inkMuted,
  };

  static const double rowAccent = 4;

  // Day timeline (PrayerDayCard).
  static const double timeColumn = 54;
  static const double railDot = 16;
  static const double summaryRing = 52;

  /// "Mark prayed": a compact pill as wide as its label (user: smaller,
  /// smaller text); the tap area is padded out to 44 pt.
  static const double markButton = 34;
  static const double markButtonFont = 13;
  static const double heroRing = 58;

  // Insights › Prayer.
  static const double insightDonutMax = 150;
  static const double barMinWidth = 3;
  static const double barMaxWidth = 22;
  static const double progressBar = 8;

  /// The Prayer card's name, and how much its texts sit under the page's
  /// defaults (eyebrow, name, window, jamaat: −1.5 pt each).
  static const double heroName = 26;
  static const double heroShrink = 1.5;

  // The card's sky (PrayerSunArc): the four-part curve with the sun or moon
  // on it, over a living sky that melts into the text half. The card is at
  // least [heroMinHeight] tall and the horizon sits [skyHorizon] from its
  // top, so the scene looks the same whatever the text above it does.
  static const double heroMinHeight = 212;
  static const double skyHorizon = 152;
  static const double skyArcRadius = 74;
  static const double skyArcStroke = 6;

  /// Gap between the card's edge and the curve's far end.
  static const double skyEdge = 14;

  /// The text column's share of the card's width (the sky melts in beside
  /// it).
  static const double heroTextShare = .48;

  /// Air between the time-left bar and the curve's near foot.
  static const double heroBarGap = 8;

  /// Radius of the sun's disc and of the moon.
  static const double sunRadius = 10;
  static const double moonRadius = 10.5;
  static const double skyPartFont = 12;
  static const double skyEndFont = 10.5;

  /// The "1:29:05 left" countdown under the part's name.
  static const double sunLeftFont = 10;

  /// The body travelling from the curve's start to "now" when the card is
  /// first shown (once per visit to the page).
  static const Duration skyIntro = Duration(milliseconds: 1600);

  /// Sunrise ↔ sunset: the old curve and body fade out, the new ones in.
  static const Duration skySwap = Duration(milliseconds: 600);

  /// Soft shadow under the white texts that sit on the sky.
  static const Color skyTextShadow = Color(0x80001E3C);

  /// The sun (a warm token; its colour runs from orange at the horizon to
  /// pale yellow overhead).
  static const Color sun = AppPalette.amber300;

  /// The moon's tone high in the sky (a pale cool token); low it is warm.
  static const Color moon = AppPalette.indigo100;

  /// The icon of a kind of practice in [tradition]'s world: the Quran for
  /// Islamic reading, a Bible, a Torah scroll, a lamp for puja, a leaf for
  /// a sit.
  static IconData kindIcon(PrayerKind kind, PrayerTradition tradition) {
    if (kind.isFast) return FontAwesomeIcons.bowlFood;
    return switch (kind) {
      PrayerKind.dhikr => FontAwesomeIcons.ellipsis,
      PrayerKind.meditation => FontAwesomeIcons.spa,
      PrayerKind.recitation => switch (tradition) {
        PrayerTradition.islam => FontAwesomeIcons.bookQuran,
        PrayerTradition.christianity => FontAwesomeIcons.bookBible,
        PrayerTradition.judaism => FontAwesomeIcons.scroll,
        _ => FontAwesomeIcons.bookOpen,
      },
      PrayerKind.service => switch (tradition) {
        PrayerTradition.christianity => FontAwesomeIcons.church,
        PrayerTradition.judaism ||
        PrayerTradition.hinduism => FontAwesomeIcons.fire,
        PrayerTradition.buddhism => FontAwesomeIcons.vihara,
        _ => FontAwesomeIcons.placeOfWorship,
      },
      _ => switch (tradition) {
        PrayerTradition.islam => FontAwesomeIcons.personPraying,
        PrayerTradition.hinduism => FontAwesomeIcons.om,
        PrayerTradition.buddhism => FontAwesomeIcons.dharmachakra,
        _ => FontAwesomeIcons.handsPraying,
      },
    };
  }

  /// The icon of a place: Home, Work, a house of worship (by the words in
  /// the active language or English, so a typed "Masjid" or "office"
  /// works too), else a map pin.
  static IconData placeIcon(String place, PrayerTradition tradition) {
    final p = place.trim().toLowerCase();
    bool any(List<String> words) => words.any(
      (w) =>
          w.isNotEmpty && (p == w.toLowerCase() || p.contains(w.toLowerCase())),
    );
    if (any([tr('Home'), 'home', 'house'])) return FontAwesomeIcons.house;
    if (any([tr('Work'), 'work', 'office'])) return FontAwesomeIcons.briefcase;
    if (any([tr('Mosque'), 'mosque', 'masjid'])) {
      return FontAwesomeIcons.mosque;
    }
    if (any([tr('Church'), 'church', 'chapel', 'cathedral'])) {
      return FontAwesomeIcons.church;
    }
    if (any([tr('Synagogue'), 'synagogue', 'shul'])) {
      return FontAwesomeIcons.synagogue;
    }
    if (any([tr('Temple'), 'temple', 'mandir', 'gurdwara', 'pagoda'])) {
      return switch (tradition) {
        PrayerTradition.hinduism => FontAwesomeIcons.gopuram,
        PrayerTradition.buddhism => FontAwesomeIcons.vihara,
        _ => FontAwesomeIcons.placeOfWorship,
      };
    }
    return FontAwesomeIcons.locationDot;
  }
}

abstract final class PrayerFormat {
  static String time(DateTime t, {required bool use24h}) =>
      DateUtilsX.time(t, use24h: use24h);

  /// "3:42 – 5:21 PM" ("+1" when the end is on the next day).
  static String window(PrayerWindow w, {required bool use24h}) {
    final start = time(w.start, use24h: use24h);
    final end = w.end;
    if (end == null) return start;
    final nextDay = DateUtilsX.dateOnly(end) != DateUtilsX.dateOnly(w.start)
        ? ' +1'
        : '';
    return '$start – ${time(end, use24h: use24h)}$nextDay';
  }

  /// "1h 39m" / "45 min".
  static String duration(Duration d) {
    final minutes = d.inMinutes.abs();
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return tr('{m} min', {'m': m});
    if (m == 0) return tr('{h}h', {'h': h});
    return tr('{h}h {m}m', {'h': h, 'm': m});
  }

  /// "in 1h 12m".
  static String inTime(Duration d) => tr('in {time}', {'time': duration(d)});

  /// "Jamaat 4:15 PM" ("Congregation …" outside Islam), with "· in 25 min"
  /// while it is still ahead (within 3 hours) and the prayer is not marked;
  /// null when no jamaat is set.
  static String? jamaat(PrayerSlot s, DateTime now, {required bool use24h}) {
    final at = s.jamaat;
    if (at == null) return null;
    final clock = PrayerFormat.time(at, use24h: use24h);
    // An estimate is marked "~" (not the mosque's own time).
    final time = s.prayer.jamaat?.estimated ?? false ? '~$clock' : clock;
    final label = PrayerTraditionProfile.of(
      s.prayer.tradition,
    ).congregationLine(time);
    final ahead = at.difference(now);
    if (s.status != null || ahead.isNegative || ahead.inHours >= 3) {
      return label;
    }
    return '$label · ${inTime(ahead)}';
  }

  /// "Ends in 18 min".
  static String endsIn(Duration d) =>
      tr('Ends in {time}', {'time': duration(d)});

  /// Signed minutes: "+5 min" / "−10 min" / "" for 0.
  static String offset(int minutes) {
    if (minutes == 0) return '';
    final sign = minutes > 0 ? '+' : '−';
    return '$sign${tr('{m} min', {'m': minutes.abs()})}';
  }

  /// How [p] repeats when not every day: the calendar rule ("Ramadan") or
  /// the weekdays; null for every day.
  static String? repeat(Prayer p) {
    final rule = p.calendar;
    if (rule != null) return CalendarRules.describe(rule);
    return p.weekdaysMask & 0x7F == 0x7F ? null : weekdays(p.weekdaysMask);
  }

  /// "Every day", "Mon, Thu", "Fri", "Mon – Fri, Sun" (a run of three or
  /// more days is written as a range).
  static String weekdays(int mask) {
    if (mask & 0x7F == 0x7F) return tr('Every day');
    final names = [
      tr('Mon'),
      tr('Tue'),
      tr('Wed'),
      tr('Thu'),
      tr('Fri'),
      tr('Sat'),
      tr('Sun'),
    ];
    final parts = <String>[];
    var i = 0;
    while (i < 7) {
      if (mask & (1 << i) == 0) {
        i++;
        continue;
      }
      var j = i;
      while (j + 1 < 7 && mask & (1 << (j + 1)) != 0) {
        j++;
      }
      if (j - i >= 2) {
        parts.add('${names[i]} – ${names[j]}');
      } else {
        for (var k = i; k <= j; k++) {
          parts.add(names[k]);
        }
      }
      i = j + 1;
    }
    return parts.join(', ');
  }
}
