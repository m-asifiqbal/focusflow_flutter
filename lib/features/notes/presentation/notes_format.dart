/// ============================================================
/// NOTES FORMAT — the short date / count labels of screens 07 and 08
/// ============================================================
///
/// * card footer      "TODAY · IDEAS", "JUN 10 · WORK"
/// * header subtitle  "48 notes · 3 pinned"
/// * editor meta      "Edited today, 9:12 AM · 214 words · Reminder Fri"
/// Pure formatting (intl), shared by the list, the editor and tests.
/// ============================================================
library;

import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';

abstract final class NotesFormat {
  /// "Today", "Yesterday", "Jun 10" (or "Jun 10, 2025" in another year).
  static String day(DateTime d, DateTime now) {
    final diff = DateUtilsX.daysBetween(now, d);
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    return d.year == now.year
        ? DateFormats.of('MMM d').format(d)
        : DateFormats.of('MMM d, y').format(d);
  }

  /// "9:12 AM" / "09:12".
  static String time(DateTime t, {bool use24h = false}) =>
      DateFormats.of(use24h ? 'HH:mm' : 'h:mm a').format(t);

  /// Card footer label: last edit day + folder (or first tag).
  static String cardFooter(Note note, DateTime now) {
    final label = note.folderName?.trim().isNotEmpty == true
        ? note.folderName!.trim()
        : (note.tags.isEmpty ? null : note.tags.first.name);
    return [day(note.updatedAt, now), ?label].join(' · ');
  }

  /// Card / row preview: the body without its checklist lines (those get
  /// their own checkbox preview), whitespace collapsed. Empty when locked.
  static String cardPreview(Note note) {
    if (note.isLocked) return '';
    final checks = {for (final c in note.checklist) c.text.trim()};
    final lines = note.plainText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !checks.contains(l));
    final title = note.title.trim();
    final body = lines.join(' ').replaceAll(RegExp(r'\s+'), ' ');
    // Untitled notes show their first line as the title — don't repeat it.
    final text = title.isEmpty && body.startsWith(note.displayTitle)
        ? body.substring(note.displayTitle.length).trim()
        : body;
    return text.length <= 280 ? text : '${text.substring(0, 280).trimRight()}…';
  }

  /// "48 notes · 3 pinned" (pinned part only when > 0).
  static String headerSubtitle(int total, int pinned) {
    final notes = '$total ${total == 1 ? 'note' : 'notes'}';
    return pinned > 0 ? '$notes · $pinned pinned' : notes;
  }

  /// "Edited today, 9:12 AM".
  static String edited(DateTime t, DateTime now, {bool use24h = false}) {
    final d = day(t, now);
    final dayLabel = d == 'Today' || d == 'Yesterday' ? d.toLowerCase() : d;
    return 'Edited $dayLabel, ${time(t, use24h: use24h)}';
  }

  /// "214 words".
  static String words(int count) => '$count ${count == 1 ? 'word' : 'words'}';

  /// "Reminder Fri" (this week), "Reminder 3:00 PM" (today), "Reminder
  /// tomorrow", "Reminder Jun 20".
  static String reminder(DateTime at, DateTime now, {bool use24h = false}) {
    final diff = DateUtilsX.daysBetween(now, at);
    if (diff == 0) return 'Reminder ${time(at, use24h: use24h)}';
    if (diff == 1) return 'Reminder tomorrow';
    if (diff > 1 && diff < 7) {
      return 'Reminder ${DateFormats.of('EEE').format(at)}';
    }
    return 'Reminder ${day(at, now)}';
  }
}
