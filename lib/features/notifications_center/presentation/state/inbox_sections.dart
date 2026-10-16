/// ============================================================
/// INBOX SECTIONS — Today / Earlier grouping + compact time labels
/// ============================================================
///
/// What: pure helpers for screen 27 — splits the (newest-first) inbox into
/// TODAY and EARLIER by the local calendar day, and formats the small time
/// label at the end of a row ("now", "12m", "8:00", "Yesterday", "Mon").
/// Why: kept out of the widgets (CLAUDE.md rule 5) so it is unit-testable.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';
import 'package:intl/intl.dart';

/// The inbox split into the two groups the screen shows.
@immutable
class InboxSections {
  const InboxSections({required this.today, required this.earlier});

  /// Groups [entries] (newest first) relative to [now].
  factory InboxSections.of(List<InboxEntry> entries, DateTime now) {
    final today = <InboxEntry>[];
    final earlier = <InboxEntry>[];
    for (final e in entries) {
      (DateUtilsX.isSameDay(e.createdAt.toLocal(), now) ? today : earlier).add(
        e,
      );
    }
    return InboxSections(today: today, earlier: earlier);
  }

  final List<InboxEntry> today;
  final List<InboxEntry> earlier;

  bool get isEmpty => today.isEmpty && earlier.isEmpty;

  /// Unread entries across both groups ("Read all" is enabled when > 0).
  int get unread =>
      today.where((e) => !e.isRead).length +
      earlier.where((e) => !e.isRead).length;
}

/// Compact time labels of the inbox rows.
abstract final class InboxTimeLabel {
  /// "now" (< 1 min), "12m" (< 1 h), "8:00" (today), "Yesterday",
  /// "Mon" (this past week), else "Jun 12".
  static String of(DateTime at, DateTime now, {bool use24h = false}) {
    final t = at.toLocal();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (DateUtilsX.isSameDay(t, now)) {
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      return DateFormat(use24h ? 'H:mm' : 'h:mm').format(t);
    }
    final days = DateUtilsX.daysBetween(t, now);
    if (days == 1) return 'Yesterday';
    if (days > 1 && days < 7) return DateFormat('EEE').format(t);
    return DateFormat('MMM d').format(t);
  }

  /// Spoken form for screen readers ("8:00 AM", "Yesterday 6:30 PM").
  static String semantic(DateTime at, DateTime now, {bool use24h = false}) {
    final t = at.toLocal();
    final time = DateUtilsX.time(t, use24h: use24h);
    if (DateUtilsX.isSameDay(t, now)) return time;
    return '${of(at, now, use24h: use24h)} $time';
  }
}
