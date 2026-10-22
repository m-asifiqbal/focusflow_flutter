/// ============================================================
/// NOTE EXPORT — plain text and Markdown renderings of a note
/// ============================================================
///
/// "Share / export (PDF, TXT, MD)" (screen 09, editor More menu). The text
/// formats are produced here in pure Dart from the Delta lines (see
/// [NoteContent]); the PDF is laid out by the data layer from the same
/// lines. Locked notes are only exported after the vault is unlocked —
/// enforced by the caller.
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/domain/services/note_content.dart';

/// Export formats offered by the share sheet.
enum NoteExportFormat {
  pdf('pdf', 'application/pdf'),
  text('txt', 'text/plain'),
  markdown('md', 'text/markdown');

  const NoteExportFormat(this.extension, this.mimeType);

  /// Share-sheet text in the active language ("PDF" is the same everywhere).
  String get label => switch (this) {
    NoteExportFormat.pdf => 'PDF',
    NoteExportFormat.text => tr('Plain text'),
    NoteExportFormat.markdown => tr('Markdown'),
  };

  final String extension;
  final String mimeType;
}

abstract final class NoteExport {
  /// Safe file name stem from the note title ("Mobile App Design Trends").
  static String fileStem(Note note) {
    final cleaned = note.displayTitle
        .replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'Note';
    return cleaned.length > 60 ? cleaned.substring(0, 60).trim() : cleaned;
  }

  /// Title, blank line, body; checklists as `[x]` / `[ ]`, bullets as `•`.
  static String toText(Note note) {
    final content = NoteContent.fromDeltaJson(note.contentDelta);
    final out = StringBuffer()..writeln(note.displayTitle);
    if (content.lines.isNotEmpty) out.writeln();
    var ordered = 0;
    for (final line in content.lines) {
      ordered = line.list == 'ordered' ? ordered + 1 : 0;
      final text = line.text;
      out.writeln(switch (line.list) {
        'checked' => '[x] $text',
        'unchecked' => '[ ] $text',
        'bullet' => '• $text',
        'ordered' => '$ordered. $text',
        _ => line.quote ? '“$text”' : text,
      });
    }
    return out.toString().trimRight();
  }

  /// CommonMark-ish Markdown (headings, emphasis, lists, task lists,
  /// quotes, images as relative links).
  static String toMarkdown(Note note) {
    final content = NoteContent.fromDeltaJson(note.contentDelta);
    final out = StringBuffer()..writeln('# ${_escape(note.displayTitle)}');
    if (content.lines.isNotEmpty) out.writeln();
    var ordered = 0;
    for (final line in content.lines) {
      ordered = line.list == 'ordered' ? ordered + 1 : 0;
      final text = line.segments.map(_inline).join();
      final body = switch (line.list) {
        'checked' => '- [x] $text',
        'unchecked' => '- [ ] $text',
        'bullet' => '- $text',
        'ordered' => '$ordered. $text',
        _ when line.header != null =>
          '${'#' * (line.header!.clamp(1, 5) + 1)} $text',
        _ when line.quote => '> $text',
        _ => text,
      };
      for (final image in line.images) {
        out.writeln('![]($image)');
      }
      out.writeln(body);
    }
    return out.toString().trimRight();
  }

  static String _inline(DeltaSegment s) {
    final t = _escape(s.text);
    if (t.trim().isEmpty) return t;
    if (s.bold && s.italic) return '***$t***';
    if (s.bold) return '**$t**';
    if (s.italic) return '_${t}_';
    return t;
  }

  static String _escape(String s) =>
      s.replaceAllMapped(RegExp(r'([\\`*_\[\]])'), (m) => '\\${m[1]}');
}
