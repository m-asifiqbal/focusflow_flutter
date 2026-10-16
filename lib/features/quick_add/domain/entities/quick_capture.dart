/// ============================================================
/// QUICK CAPTURE — the result of parsing one quick-capture phrase
/// ============================================================
///
/// What: "Pay rent tomorrow 9am #home !high" → a Reminder titled "Pay rent"
/// for tomorrow 09:00, tag `home`, priority high. Produced by
/// [QuickCaptureParser]; consumed by the Quick Add sheet (preview chips) and
/// by the navigation that opens the matching editor prefilled.
///
/// Why a separate value type: the parser is pure Dart and unit-tested; the
/// sheet only renders / routes this object.
/// ============================================================
library;

import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:focusflow/core/utils/date_utils.dart';

/// Which editor a capture opens. A time makes it a reminder, a date (or a
/// priority / repeat) without a time makes it a task, anything else a note.
enum QuickCaptureKind {
  note('Note'),
  task('Task'),
  reminder('Reminder');

  const QuickCaptureKind(this.label);

  final String label;
}

@immutable
class QuickCapture {
  const QuickCapture({
    required this.title,
    required this.kind,
    this.day,
    this.timeMinutes,
    this.priority,
    this.tags = const [],
    this.repeatRule,
  });

  /// The phrase with every recognised token removed ("Pay rent"); may be
  /// empty ("tomorrow 9am").
  final String title;
  final QuickCaptureKind kind;

  /// Local calendar day (midnight), when the phrase has a date.
  final DateTime? day;

  /// Minutes after midnight, when the phrase has a time.
  final int? timeMinutes;

  /// Task priority index (1 low · 2 medium · 3 high), null = none.
  final int? priority;

  /// Tags without the leading `#`, in the order typed (deduplicated).
  final List<String> tags;

  /// RRULE text (`FREQ=WEEKLY;BYDAY=MO`) for "every …" phrases.
  final String? repeatRule;

  /// The tag the opened editor receives. The note / task editor routes take
  /// a single `tag` query parameter (`AppRoutes.newNoteWith` / `newTask`),
  /// so only the first typed tag is saved — and only that one is previewed.
  String? get savedTag => tags.firstOrNull;

  /// Day + time as a local DateTime (reminders); null without both.
  DateTime? get at => day == null || timeMinutes == null
      ? null
      : DateUtilsX.atMinutes(day!, timeMinutes!);

  /// `yyyy-MM-dd` of [day] (task due date query parameter).
  String? get dayKey => day == null ? null : DateUtilsX.dayKey(day!);

  @override
  bool operator ==(Object other) =>
      other is QuickCapture &&
      other.title == title &&
      other.kind == kind &&
      other.day == day &&
      other.timeMinutes == timeMinutes &&
      other.priority == priority &&
      listEquals(other.tags, tags) &&
      other.repeatRule == repeatRule;

  @override
  int get hashCode => Object.hash(
    title,
    kind,
    day,
    timeMinutes,
    priority,
    Object.hashAll(tags),
    repeatRule,
  );

  @override
  String toString() =>
      'QuickCapture($kind, "$title", day: $day, time: $timeMinutes, '
      'priority: $priority, tags: $tags, rrule: $repeatRule)';
}
