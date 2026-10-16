/// ============================================================
/// CSV CODEC — RFC 4180 reader / writer
/// ============================================================
///
/// What: parses CSV text (quoted fields, escaped quotes, CRLF/LF, embedded
/// newlines, a UTF-8 BOM) into rows, and writes rows back.
/// Why: exports and every CSV importer (Todoist, Bitwarden, 1Password,
/// Loop, FocusFlow) share it; no CSV package is bundled.
/// ============================================================
library;

abstract final class CsvCodec {
  /// Rows of [input]; blank lines are skipped.
  static List<List<String>> decode(String input) {
    var s = input;
    if (s.startsWith('﻿')) s = s.substring(1);
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var quoted = false;
    var i = 0;
    void endField() {
      row.add(field.toString());
      field.clear();
    }

    void endRow() {
      endField();
      if (!(row.length == 1 && row.first.isEmpty)) rows.add(row);
      row = <String>[];
    }

    while (i < s.length) {
      final c = s[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < s.length && s[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          field.write(c);
        }
      } else if (c == '"') {
        quoted = true;
      } else if (c == ',') {
        endField();
      } else if (c == '\n' || c == '\r') {
        if (c == '\r' && i + 1 < s.length && s[i + 1] == '\n') i++;
        endRow();
      } else {
        field.write(c);
      }
      i++;
    }
    if (field.isNotEmpty || row.isNotEmpty) endRow();
    return rows;
  }

  /// Rows as maps keyed by the (lower-cased, trimmed) header row.
  static List<Map<String, String>> decodeMaps(String input) {
    final rows = decode(input);
    if (rows.isEmpty) return const [];
    final header = [for (final h in rows.first) h.trim().toLowerCase()];
    return [
      for (final r in rows.skip(1))
        {
          for (var c = 0; c < header.length; c++)
            header[c]: c < r.length ? r[c] : '',
        },
    ];
  }

  /// CSV text for [rows] (CRLF line ends, quotes only when needed).
  static String encode(List<List<Object?>> rows) {
    final out = StringBuffer();
    for (final r in rows) {
      out
        ..write(r.map(_field).join(','))
        ..write('\r\n');
    }
    return out.toString();
  }

  static String _field(Object? v) {
    final s = v?.toString() ?? '';
    final needs =
        s.contains(',') ||
        s.contains('"') ||
        s.contains('\n') ||
        s.contains('\r');
    return needs ? '"${s.replaceAll('"', '""')}"' : s;
  }
}
