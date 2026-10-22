/// ============================================================
/// INBOX SECTIONS — per-day grouping + compact time labels
/// ============================================================
///
/// What: pure helpers for screen 27 — splits the (newest-first) inbox into
/// one group per local calendar day (TODAY, YESTERDAY, MONDAY, OCT 12 …)
/// and formats the small time label at the end of a row ("now", "12m",
/// "8:00", "Yesterday", "Mon").
/// Why: kept out of the widgets (CLAUDE.md rule 5) so it is unit-testable.
/// The screen pins each day's label to the top while its rows scroll, so
/// the label always tells which day you are looking at.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';

/// The entries of one local calendar day, newest first.
@immutable
class InboxDay {
  const InboxDay({required this.day, required this.entries});

  /// Local midnight of the day.
  final DateTime day;
  final List<InboxEntry> entries;
}

/// The inbox split into the day groups the screen shows.
@immutable
class InboxSections {
  const InboxSections({required this.days});

  /// Groups [entries] (newest first) by local day, newest day first.
  factory InboxSections.of(List<InboxEntry> entries) {
    final days = <InboxDay>[];
    DateTime? current;
    var bucket = <InboxEntry>[];
    for (final e in entries) {
      final d = DateUtilsX.dateOnly(e.createdAt.toLocal());
      if (current != null && d != current) {
        days.add(InboxDay(day: current, entries: bucket));
        bucket = <InboxEntry>[];
      }
      current = d;
      bucket.add(e);
    }
    if (current != null) days.add(InboxDay(day: current, entries: bucket));
    return InboxSections(days: days);
  }

  final List<InboxDay> days;

  bool get isEmpty => days.isEmpty;

  Iterable<InboxEntry> get all => days.expand((d) => d.entries);

  /// Unread entries across every day ("Read all" is enabled when > 0).
  int get unread => all.where((e) => !e.isRead).length;
}

/// The label of a day group.
abstract final class InboxDayLabel {
  /// "Today", "Yesterday", the weekday for the rest of the past week
  /// ("Monday"), else "Oct 12" (with the year when it is not this one).
  static String of(DateTime day, DateTime now) {
    final days = DateUtilsX.daysBetween(day, now);
    if (days <= 0) return tr('Today');
    if (days == 1) return tr('Yesterday');
    if (days < 7) return DateFormats.of('EEEE').format(day);
    return DateFormats.of(
      day.year == now.year ? 'MMM d' : 'MMM d, y',
    ).format(day);
  }
}

/// Compact time labels of the inbox rows.
abstract final class InboxTimeLabel {
  /// "now" (< 1 min), "12m" (< 1 h), "8:00" (today), "Yesterday",
  /// "Mon" (this past week), else "Jun 12".
  static String of(DateTime at, DateTime now, {bool use24h = false}) {
    final t = at.toLocal();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return tr('now');
    if (DateUtilsX.isSameDay(t, now)) {
      if (diff.inMinutes < 60) return tr('{m}m', {'m': diff.inMinutes});
      return DateFormats.of(use24h ? 'H:mm' : 'h:mm').format(t);
    }
    final days = DateUtilsX.daysBetween(t, now);
    if (days == 1) return tr('Yesterday');
    if (days > 1 && days < 7) return DateFormats.of('EEE').format(t);
    return DateFormats.of('MMM d').format(t);
  }

  /// Spoken form for screen readers ("8:00 AM", "Yesterday 6:30 PM").
  static String semantic(DateTime at, DateTime now, {bool use24h = false}) {
    final t = at.toLocal();
    final time = DateUtilsX.time(t, use24h: use24h);
    if (DateUtilsX.isSameDay(t, now)) return time;
    return '${of(at, now, use24h: use24h)} $time';
  }
}
