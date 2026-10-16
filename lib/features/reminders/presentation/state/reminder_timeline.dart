/// ============================================================
/// REMINDER TIMELINE — sections of the reminders list (screen 12)
/// ============================================================
///
/// What: turns repository occurrences into the timeline sections:
///   • Today chip (a selected day): MISSED (red, only when the day is
///     today) · MORNING · AFTERNOON & EVENING · the next day ("TOMORROW",
///     without reminders already listed for the day);
///   • other chips: one section per day ("TODAY", "TOMORROW", "WED, OCT 14").
/// and finds the next-due occurrence (the card with SNOOZE 10m / MARK
/// DONE).
/// Why: pure and unit tested; the providers only feed it streams.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';

/// Visual tone of a section label.
enum ReminderSectionTone { normal, missed }

@immutable
class ReminderSection {
  const ReminderSection({
    required this.key,
    required this.label,
    required this.items,
    this.tone = ReminderSectionTone.normal,
  });

  /// Stable key ("missed", "morning", "evening", "2026-10-14").
  final String key;

  /// Upper-case label ("MORNING").
  final String label;
  final List<ReminderOccurrence> items;
  final ReminderSectionTone tone;

  bool get isMissed => tone == ReminderSectionTone.missed;
}

@immutable
class ReminderTimeline {
  const ReminderTimeline({required this.sections, this.next});

  static const ReminderTimeline empty = ReminderTimeline(sections: []);

  final List<ReminderSection> sections;

  /// The next-due occurrence shown with inline actions (null = none).
  final ReminderOccurrence? next;

  bool get isEmpty => sections.every((s) => s.items.isEmpty);

  /// Every row, top to bottom.
  Iterable<ReminderOccurrence> get all => sections.expand((s) => s.items);

  /// Whether [o] is the highlighted next-due row.
  bool isNext(ReminderOccurrence o) =>
      next != null && o.id == next!.id && o.at == next!.at && !o.isDone;

  /// Timeline of the Today chip for [day].
  static ReminderTimeline forDay({
    required DateTime day,
    required DateTime now,
    required List<ReminderOccurrence> dayItems,
    required List<ReminderOccurrence> nextDayItems,
    List<ReminderOccurrence> missed = const [],
  }) {
    final isToday = DateUtilsX.isSameDay(day, now);
    final shownMissed = isToday ? missed : const <ReminderOccurrence>[];
    final missedIds = {for (final m in shownMissed) m.id};
    bool notMissed(ReminderOccurrence o) => !missedIds.contains(o.id);
    final today = dayItems.where(notMissed).toList();
    // The next-day preview skips repeating reminders already listed for
    // [day] (daily vitamins would otherwise show twice).
    final listed = {for (final o in today) o.id};
    final nextDay = [
      for (final o in nextDayItems)
        if (notMissed(o) && !listed.contains(o.id)) o,
    ];
    final tomorrow = DateUtilsX.addDays(DateUtilsX.dateOnly(day), 1);
    final sections = [
      if (shownMissed.isNotEmpty)
        ReminderSection(
          key: 'missed',
          label: 'MISSED',
          items: shownMissed,
          tone: ReminderSectionTone.missed,
        ),
      ReminderSection(
        key: 'morning',
        label: 'MORNING',
        items: [
          for (final o in today)
            if (o.at.hour < 12) o,
        ],
      ),
      ReminderSection(
        key: 'evening',
        label: 'AFTERNOON & EVENING',
        items: [
          for (final o in today)
            if (o.at.hour >= 12) o,
        ],
      ),
      ReminderSection(
        key: DateUtilsX.dayKey(tomorrow),
        label: DateUtilsX.relativeDay(tomorrow, now).toUpperCase(),
        items: nextDay,
      ),
    ].where((s) => s.items.isNotEmpty).toList();
    // Only today's view highlights the next-due card: on another picked
    // day its first reminder is not what fires next, and its inline
    // SNOOZE / MARK DONE would act on the wrong occurrence.
    return ReminderTimeline(
      sections: sections,
      next: isToday ? _nextDue([...today, ...nextDay], now) : null,
    );
  }

  /// Timeline of the Upcoming / Recurring / Location / Snoozed chips:
  /// [items] (ascending) grouped by calendar day.
  static ReminderTimeline byDay(List<ReminderOccurrence> items, DateTime now) {
    final groups = <String, List<ReminderOccurrence>>{};
    final labels = <String, String>{};
    for (final o in items) {
      final key = DateUtilsX.dayKey(o.at);
      groups.putIfAbsent(key, () => []).add(o);
      labels[key] = DateUtilsX.relativeDay(o.at, now).toUpperCase();
    }
    return ReminderTimeline(
      sections: [
        for (final e in groups.entries)
          ReminderSection(key: e.key, label: labels[e.key]!, items: e.value),
      ],
      next: _nextDue(items, now),
    );
  }

  /// Earliest enabled, not-done occurrence at or after [now].
  static ReminderOccurrence? _nextDue(
    List<ReminderOccurrence> items,
    DateTime now,
  ) {
    ReminderOccurrence? best;
    for (final o in items) {
      if (o.isDone || !o.reminder.isEnabled || o.at.isBefore(now)) continue;
      if (best == null || o.at.isBefore(best.at)) best = o;
    }
    return best;
  }
}
