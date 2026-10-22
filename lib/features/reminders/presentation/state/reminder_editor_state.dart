/// ============================================================
/// REMINDER EDITOR STATE — the form behind screen 13 (new / edit reminder)
/// ============================================================
///
/// What:
///   * [ReminderEditorArgs] — which reminder to open (`/reminders/:id`) or
///     the prefill of a new one
///     (`/reminders/new?title&at&rrule&linkType&linkId`).
///   * [ReminderEditorState] — the reminder as loaded ([original]) plus the
///     edited [draft]; [toReminder] is what Save writes, [isDirty] drives
///     the discard confirmation.
///   * [WhenChoice] / [RepeatPreset] — the chip rows, derived from the
///     draft (pure, unit-tested).
/// Why: every edit stays in memory until Save so Cancel can throw it away;
/// plain immutable classes keep the rules testable without widgets.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/utils/recurrence.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';

/// Route arguments of the reminder editor. [id] null = new reminder; the
/// other fields are the parsed query parameters of `/reminders/new`.
@immutable
class ReminderEditorArgs {
  const ReminderEditorArgs({
    this.id,
    this.title,
    this.at,
    this.repeatRule,
    this.link,
  });

  /// Reads `/reminders/:id` (+ query) — `new` opens an empty editor.
  factory ReminderEditorArgs.fromRoute(String id, Map<String, String> query) {
    if (id != 'new') return ReminderEditorArgs(id: id);
    String? text(String key) {
      final v = query[key]?.trim();
      return v == null || v.isEmpty ? null : v;
    }

    final at = DateTime.tryParse(text('at') ?? '');
    final type = ItemType.fromKey(text('linkType'));
    final linkId = text('linkId');
    return ReminderEditorArgs(
      title: text('title'),
      at: at?.toLocal(),
      repeatRule: text('rrule'),
      link: type == null || linkId == null ? null : ItemRef(type, linkId),
    );
  }

  /// Existing reminder id; null for a new reminder.
  final String? id;
  final String? title;

  /// First fire time (local).
  final DateTime? at;
  final String? repeatRule;

  /// Task / note the new reminder belongs to.
  final ItemRef? link;

  bool get isNew => id == null;

  @override
  bool operator ==(Object other) =>
      other is ReminderEditorArgs &&
      other.id == id &&
      other.title == title &&
      other.at == at &&
      other.repeatRule == repeatRule &&
      other.link == link;

  @override
  int get hashCode => Object.hash(id, title, at, repeatRule, link);
}

/// The WHEN chips: Today · Tomorrow · Next week · Pick date (any other day).
enum WhenChoice {
  today,
  tomorrow,
  nextWeek,
  other;

  /// The chip that is selected for a reminder on [day].
  static WhenChoice of(DateTime day, DateTime today, int weekStartsOn) {
    final d = DateUtilsX.dateOnly(day);
    final t = DateUtilsX.dateOnly(today);
    if (DateUtilsX.isSameDay(d, t)) return WhenChoice.today;
    if (DateUtilsX.isSameDay(d, DateUtilsX.addDays(t, 1))) {
      return WhenChoice.tomorrow;
    }
    if (DateUtilsX.isSameDay(d, nextWeekStart(t, weekStartsOn))) {
      return WhenChoice.nextWeek;
    }
    return WhenChoice.other;
  }

  /// First day of next week (per Settings › week start).
  static DateTime nextWeekStart(DateTime today, int weekStartsOn) =>
      DateUtilsX.addDays(DateUtilsX.startOfWeek(today, weekStartsOn), 7);

  /// The day this chip schedules (null for [other] — it opens a calendar).
  DateTime? dayFor(DateTime today, int weekStartsOn) {
    final t = DateUtilsX.dateOnly(today);
    return switch (this) {
      WhenChoice.today => t,
      WhenChoice.tomorrow => DateUtilsX.addDays(t, 1),
      WhenChoice.nextWeek => nextWeekStart(t, weekStartsOn),
      WhenChoice.other => null,
    };
  }
}

/// The REPEAT chips. [custom] covers every rule the quick chips can't
/// express (yearly, intervals, end dates, several weekdays …).
enum RepeatPreset {
  once,
  daily,
  weekdays,
  weekly,
  monthly,
  custom;

  /// Chip text in the active language.
  String get label => switch (this) {
    RepeatPreset.once => tr('Once'),
    RepeatPreset.daily => tr('Daily'),
    RepeatPreset.weekdays => tr('Weekdays'),
    RepeatPreset.weekly => tr('Weekly'),
    RepeatPreset.monthly => tr('Monthly'),
    RepeatPreset.custom => tr('Custom'),
  };

  /// The chip that matches [rrule] for a reminder starting on [start].
  static RepeatPreset of(String? rrule, DateTime start) {
    final rule = RecurrenceRule.tryParse(rrule);
    if (rule == null) return RepeatPreset.once;
    for (final p in const [daily, weekdays, weekly, monthly]) {
      if (p.rule(start) == rule.toRRule()) return p;
    }
    return RepeatPreset.custom;
  }

  /// Canonical RRULE of a quick chip anchored on [start] (Weekly repeats on
  /// [start]'s weekday). Null for [once]; [custom] is chosen in the sheet.
  String? rule(DateTime start) => switch (this) {
    RepeatPreset.once || RepeatPreset.custom => null,
    RepeatPreset.daily => RecurrenceRule.daily().toRRule(),
    RepeatPreset.weekdays => RecurrenceRule.weekdays().toRRule(),
    RepeatPreset.weekly => RecurrenceRule.weekly([start.weekday]).toRRule(),
    RepeatPreset.monthly => RecurrenceRule.monthly().toRRule(),
  };
}

@immutable
class ReminderEditorState {
  const ReminderEditorState({
    required this.original,
    required this.draft,
    this.saving = false,
  });

  /// The reminder as opened (the prefilled draft for a new reminder).
  final Reminder original;

  /// The edited reminder.
  final Reminder draft;

  /// A save is in flight (Save shows as disabled).
  final bool saving;

  bool get isNew => original.isNew;

  /// Title required (validation).
  bool get canSave => draft.title.trim().isNotEmpty && !saving;

  /// Minutes after midnight of the draft's time.
  int get minutes => draft.triggerAt.hour * 60 + draft.triggerAt.minute;

  /// For a one-time reminder whose chosen time has already passed at
  /// [now] (a new reminder, or an edited one whose time changed): when Save
  /// will set it instead — the same time today if still ahead, else the
  /// next day — so it never lands straight under MISSED. Null when the
  /// time is fine (future, repeating, or an untouched existing reminder).
  DateTime? pastTimeRollsTo(DateTime now) {
    final r = draft;
    if (r.isRecurring || r.triggerAt.isAfter(now)) return null;
    if (!isNew && r.triggerAt == original.triggerAt) return null;
    final today = DateUtilsX.dateOnly(now);
    final at = DateUtilsX.atMinutes(today, minutes);
    return at.isAfter(now)
        ? at
        : DateUtilsX.atMinutes(DateUtilsX.addDays(today, 1), minutes);
  }

  /// What Save writes: trimmed text; a changed time clears a stale snooze
  /// and re-arms a done / disabled one-time reminder. With [now], a
  /// one-time time that has passed moves forward ([pastTimeRollsTo]).
  Reminder toReminder({DateTime? now}) {
    var r = draft.copyWith(title: draft.title.trim(), note: draft.note.trim());
    final rolled = now == null ? null : pastTimeRollsTo(now);
    if (rolled != null) r = r.copyWith(triggerAt: rolled);
    final moved =
        r.triggerAt != original.triggerAt ||
        r.repeatRule != original.repeatRule;
    if (moved && !r.isNew) {
      r = r.copyWith(
        clearSnoozedUntil: true,
        clearCompletedAt: true,
        isEnabled: true,
      );
    }
    return r;
  }

  /// True when Save would change something (Cancel asks to discard).
  bool get isDirty =>
      draft.copyWith(title: draft.title.trim(), note: draft.note.trim()) !=
      original.copyWith(
        title: original.title.trim(),
        note: original.note.trim(),
      );

  ReminderEditorState copyWith({Reminder? draft, bool? saving}) =>
      ReminderEditorState(
        original: original,
        draft: draft ?? this.draft,
        saving: saving ?? this.saving,
      );

  @override
  bool operator ==(Object other) =>
      other is ReminderEditorState &&
      other.original == original &&
      other.draft == draft &&
      other.saving == saving;

  @override
  int get hashCode => Object.hash(original, draft, saving);
}
