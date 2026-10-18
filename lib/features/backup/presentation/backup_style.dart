/// ============================================================
/// BACKUP STYLE — tile tints + labels for screens 34 / 35
/// ============================================================
///
/// What: the icon-tile colour of every row (from the module / tag
/// palettes), and formatters: byte sizes ("2.4 MB"), "2 min ago",
/// history dates ("Today, 9:39 AM", "Jun 11, 9:00 PM"), frequency labels.
/// Why: the mockup gives each row its own tile colour; naming them once
/// keeps raw colours out of widgets, and the labels are shared by widgets
/// and tests.
/// ============================================================
library;

import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';

abstract final class BackupTints {
  static const drive = TagPalette.work;
  static const frequency = TagPalette.design;
  static const wifi = TagPalette.travel;
  static final encrypt = ModuleStyle.notes.colors;
  static final keep = ModuleStyle.vault.colors;
  static final deviceNow = ModuleStyle.notes.colors;
  static const location = ActionTints.lock;
  static const autoLocal = ActionTints.share;
  static final local = ModuleStyle.notes.colors;
  static const archived = ActionTints.lock;
  static const attachments = TagPalette.travel;
  static const settings = TagPalette.personal;
}

abstract final class BackupLabels {
  /// "2.4 MB", "820 KB", "15 GB".
  static String size(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var v = bytes.toDouble();
    var u = 0;
    while (v >= 1024 && u < units.length - 1) {
      v /= 1024;
      u++;
    }
    final text = u == 0 || v >= 100 || v == v.roundToDouble()
        ? v.round().toString()
        : v.toStringAsFixed(1);
    return '$text ${units[u]}';
  }

  /// "just now", "2 min ago", "3 h ago", "Yesterday", "Jun 11".
  static String ago(DateTime t, DateTime now) {
    final d = now.difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    if (DateUtilsX.daysBetween(t, now) == 1) return 'yesterday';
    return DateFormats.of('MMM d').format(t);
  }

  /// "Today, 9:39 AM" / "Yesterday, 11:02 PM" / "Jun 11, 9:00 PM".
  static String when(DateTime t, DateTime now, {bool use24h = false}) {
    final time = DateFormats.of(use24h ? 'HH:mm' : 'h:mm a').format(t);
    final days = DateUtilsX.daysBetween(t, now);
    final day = switch (days) {
      0 => 'Today',
      1 => 'Yesterday',
      _ =>
        t.year == now.year
            ? DateFormats.of('MMM d').format(t)
            : DateFormats.of('MMM d, y').format(t),
    };
    return '$day, $time';
  }

  /// "9:00 PM" from minutes after midnight.
  static String minutes(int m, {bool use24h = false}) => DateFormats.of(
    use24h ? 'HH:mm' : 'h:mm a',
  ).format(DateTime(2000, 1, 1, m ~/ 60, m % 60));

  /// "Daily · 9:00 PM".
  static String frequency(AppSettings s) {
    final f = s.backupFrequency == BackupFrequency.daily ? 'Daily' : 'Weekly';
    return '$f · ${minutes(s.backupMinutes, use24h: s.use24HourTime)}';
  }

  static String localFrequency(LocalBackupFrequency f) => switch (f) {
    LocalBackupFrequency.off => 'Off',
    LocalBackupFrequency.daily => 'Daily',
    LocalBackupFrequency.weekly => 'Weekly',
  };
}
