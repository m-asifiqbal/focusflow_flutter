/// ============================================================
/// QUICK CAPTURE PREVIEW — the chip row under the capture field
/// ============================================================
///
/// What: turns a [QuickCapture] into the short parts shown before saving
/// ("Task", "Tomorrow 09:00 AM", "Weekly · Mon", "High", "#home").
/// Reminders show no priority / tags (the reminder editor has neither).
/// Why: pure formatting, unit-tested apart from the sheet.
/// ============================================================
library;

import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/utils/recurrence.dart';
import 'package:focusflow/features/quick_add/domain/entities/quick_capture.dart';

/// One preview chip; [kind] picks its styling.
enum QuickCapturePartKind { kind, when, repeat, priority, tag }

typedef QuickCapturePart = ({QuickCapturePartKind kind, String label});

abstract final class QuickCapturePreview {
  static const _priorities = ['', 'Low', 'Medium', 'High'];

  /// Preview parts for [c] relative to [now].
  static List<QuickCapturePart> parts(
    QuickCapture c,
    DateTime now, {
    bool use24h = false,
  }) {
    final day = c.day;
    final time = c.timeMinutes;
    return [
      (kind: QuickCapturePartKind.kind, label: c.kind.label),
      if (day != null)
        (
          kind: QuickCapturePartKind.when,
          label: [
            DateUtilsX.relativeDay(day, now),
            if (time != null) DateUtilsX.minutesToTime(time, use24h: use24h),
          ].join(' '),
        ),
      if (c.repeatRule != null)
        (
          kind: QuickCapturePartKind.repeat,
          label: Recurrence.label(c.repeatRule, start: day),
        ),
      // Reminders have no priority or tags, so those aren't promised.
      if (c.kind != QuickCaptureKind.reminder) ...[
        if (c.priority case final p? when p > 0 && p < _priorities.length)
          (kind: QuickCapturePartKind.priority, label: _priorities[p]),
        // Only what the editor will save (see QuickCapture.savedTag).
        if (c.savedTag case final t?)
          (kind: QuickCapturePartKind.tag, label: '#$t'),
      ],
    ];
  }

  /// "Task · Tomorrow 09:00 AM · #home" (semantics label / tests).
  static String summary(QuickCapture c, DateTime now, {bool use24h = false}) =>
      parts(c, now, use24h: use24h).map((p) => p.label).join(' · ');
}
