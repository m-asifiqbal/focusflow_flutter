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
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_stats.dart';

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

  // The hero's sun arc (PrayerSunArc).
  static const double sunArcWidth = 100;
  static const double sunArcHeight = 54;
  static const double sunArcStroke = 3.5;
  static const double sunDot = 6;
  static const double sunArcLabel = 10;
  static const double sunArcMoon = 14;

  /// The "1h 29m left" countdown under the part's name.
  static const double sunLeftFont = 8.5;

  /// The sun on the arc (a warm token, readable on the accent gradient).
  static const Color sun = AppPalette.amber300;

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
    final label = s.prayer.tradition == PrayerTradition.islam
        ? tr('Jamaat {time}', {'time': time})
        : tr('Congregation {time}', {'time': time});
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

  /// "Every day", "Mon, Thu", "Fri".
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
    return [
      for (var i = 0; i < 7; i++)
        if (mask & (1 << i) != 0) names[i],
    ].join(', ');
  }
}
