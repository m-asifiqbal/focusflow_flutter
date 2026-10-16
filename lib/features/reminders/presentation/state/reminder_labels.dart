/// ============================================================
/// REMINDER LABELS — the copy of the reminders list (screen 12)
/// ============================================================
///
/// What: the header subtitle ("3 today · next in 25 min"), the meta line
/// under a reminder title ("Daily · Repeats every day", "Linked task ·
/// Design Home v2", "When I leave office · Location", "Today · in 25
/// min") and the time column ("07:00" + "AM").
/// Why: pure functions of (occurrence, now) so they are unit tested and
/// the widgets stay layout only.
/// ============================================================
library;

import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:intl/intl.dart';

abstract final class ReminderLabels {
  /// Header subtitle: "3 today · next in 25 min" / "Nothing scheduled".
  static String headerSubtitle({
    required int today,
    required DateTime? next,
    required DateTime now,
  }) {
    final parts = <String>[if (today > 0) '$today today'];
    if (next != null) {
      final soon = next.difference(now) < const Duration(hours: 24);
      parts.add(
        soon
            ? 'next ${DateUtilsX.until(next, now)}'
            : 'next ${DateUtilsX.relativeDay(next, now).toLowerCase()}',
      );
    }
    return parts.isEmpty ? 'Nothing scheduled' : parts.join(' · ');
  }

  /// "07:00" / "19:00" (24 h) for the time column.
  static String time(DateTime t, {bool use24h = false}) =>
      DateFormat(use24h ? 'HH:mm' : 'hh:mm').format(t);

  /// "AM" / "PM" under the time; null in 24 h mode.
  static String? meridiem(DateTime t, {bool use24h = false}) =>
      use24h ? null : DateFormat('a').format(t).toUpperCase();

  /// The meta line under the title.
  static String meta(ReminderOccurrence o, DateTime now) {
    final r = o.reminder;
    final parts = <String>[...primaryMeta(o, now)];
    for (final tag in r.tags.take(1)) {
      final name = tag.name.trim().replaceAll(RegExp('[-_]+'), ' ');
      // Tags are stored as lower-case slugs; the meta line is prose.
      if (name.isNotEmpty) {
        parts.add('${name[0].toUpperCase()}${name.substring(1)}');
      }
    }
    return parts.join(' · ');
  }

  /// Link / location / repeat / when — without tags.
  static List<String> primaryMeta(ReminderOccurrence o, DateTime now) {
    final r = o.reminder;
    final link = r.linkedRef;
    if (link != null) {
      final title = r.linkedTitle?.trim() ?? '';
      return [linkLabel(link.type), if (title.isNotEmpty) title];
    }
    final place = r.location;
    if (place != null) return [place.description, 'Location'];
    if (!o.isDone && r.isSnoozed(now) && o.at == r.snoozedUntil) {
      return ['Snoozed', DateUtilsX.until(o.at, now)];
    }
    if (r.isRecurring) return repeat(r);
    return _when(o, now);
  }

  /// "Daily · Repeats every day", "Weekdays · Mon–Fri", "Monthly · 14th".
  static List<String> repeat(Reminder r) {
    final label = r.repeatLabel;
    return switch (label) {
      'Daily' => const ['Daily', 'Repeats every day'],
      'Weekdays' => const ['Weekdays', 'Mon–Fri'],
      'Weekends' => const ['Weekends', 'Sat–Sun'],
      _ => [label],
    };
  }

  static List<String> _when(ReminderOccurrence o, DateTime now) {
    final day = DateUtilsX.relativeDay(o.at, now);
    if (o.isDone) return [day, 'Done'];
    if (o.at.isBefore(now)) return [day, 'Missed'];
    final soon = o.at.difference(now) < const Duration(hours: 12);
    return [day, if (soon) DateUtilsX.until(o.at, now) else 'Once'];
  }

  /// Screen-reader summary of a row.
  static String semantics(
    ReminderOccurrence o,
    DateTime now, {
    bool use24h = false,
  }) {
    final r = o.reminder;
    final title = r.title.trim().isEmpty ? 'Untitled reminder' : r.title;
    return [
      title,
      DateUtilsX.time(o.at, use24h: use24h),
      meta(o, now),
      if (o.isDone) 'done' else if (!r.isEnabled) 'off',
    ].join(', ');
  }

  /// "Linked task" etc. for a link type (used by the editor too).
  /// "tomorrow, 8:00 AM" — where a one-time reminder whose time has
  /// passed moves on Save ([at] is today or tomorrow relative to [now]).
  static String rolledTo(DateTime at, DateTime now, {bool use24h = false}) {
    final day = DateUtilsX.isSameDay(at, now) ? 'today' : 'tomorrow';
    return '$day, ${DateUtilsX.time(at, use24h: use24h)}';
  }

  static String linkLabel(ItemType type) =>
      'Linked ${type.label.toLowerCase()}';
}
