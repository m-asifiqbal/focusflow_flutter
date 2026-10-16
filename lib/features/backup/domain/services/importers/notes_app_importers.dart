/// ============================================================
/// NOTES-APP IMPORTERS — Google Keep Takeout, Evernote .enex
/// ============================================================
///
/// What: Google Keep (a Takeout zip, or single note .json files: title,
/// textContent / listContent, labels, isArchived / isTrashed / isPinned,
/// microsecond timestamps) and Evernote .enex (XML: title, ENML content in
/// CDATA, created, tag) → [ImportedNote]s. Checklists become
/// `- [ ] item` lines; trashed Keep notes are skipped.
/// Why: the two most common note apps people move from. No XML package is
/// bundled, so .enex is read with tolerant regular expressions (it is a
/// flat, well-known format).
/// ============================================================
library;

import 'dart:convert';

import 'package:focusflow/features/backup/domain/entities/import_bundle.dart';
import 'package:focusflow/features/backup/domain/services/importers/import_parsing.dart';

abstract final class KeepImporter {
  /// Whether [json] looks like one Keep note.
  static bool isKeepNote(Object? json) =>
      json is Map &&
      (json.containsKey('textContent') || json.containsKey('listContent')) &&
      json.containsKey('createdTimestampUsec');

  /// Notes from a Takeout zip or one .json note.
  static ImportBundle parse(List<int> bytes) {
    final notes = <ImportedNote>[];
    final problems = <ImportProblem>[];
    var trashed = 0;
    void add(String name, List<int> data) {
      Object? json;
      try {
        json = jsonDecode(ImportParsing.text(data));
      } on FormatException {
        problems.add(ImportProblem('$name: not valid JSON'));
        return;
      }
      if (!isKeepNote(json)) return;
      final m = json as Map;
      if (m['isTrashed'] == true) {
        trashed++;
        return;
      }
      try {
        notes.add(_note(m));
      } on Object {
        problems.add(ImportProblem('$name: unexpected note format'));
      }
    }

    final zip = ImportParsing.zip(bytes);
    if (zip == null) {
      add('note', bytes);
    } else {
      for (final f in zip.files) {
        if (f.isFile && f.name.toLowerCase().endsWith('.json')) {
          add(f.name.split('/').last, f.content);
        }
      }
    }
    if (notes.isEmpty && problems.isEmpty) {
      throw const ImportFormatException(
        'No Google Keep notes found. Export Keep from Google Takeout and '
        'pick the zip.',
      );
    }
    if (trashed > 0) {
      problems.add(ImportProblem('$trashed trashed notes left out'));
    }
    return ImportBundle(
      source: ImportSource.googleKeep,
      notes: notes,
      problems: problems,
    );
  }

  static ImportedNote _note(Map m) {
    final list = m['listContent'];
    final labels = m['labels'];
    final text = list is List
        ? [
            for (final i in list.whereType<Map>())
              '- [${i['isChecked'] == true ? 'x' : ' '}] ${i['text'] ?? ''}',
          ].join('\n')
        : '${m['textContent'] ?? ''}';
    return ImportedNote(
      title: '${m['title'] ?? ''}'.trim(),
      text: text,
      tags: [
        if (labels is List)
          for (final l in labels.whereType<Map>()) '${l['name'] ?? ''}'.trim(),
      ]..removeWhere((t) => t.isEmpty),
      createdAt: ImportParsing.dateTime(m['createdTimestampUsec']),
      archived: m['isArchived'] == true,
      pinned: m['isPinned'] == true,
    );
  }
}

abstract final class EnexImporter {
  static final _note = RegExp(r'<note>([\s\S]*?)</note>');
  static final _title = RegExp(r'<title>([\s\S]*?)</title>');
  static final _content = RegExp(
    r'<content>\s*(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?\s*</content>',
  );
  static final _created = RegExp(r'<created>([\s\S]*?)</created>');
  static final _tag = RegExp(r'<tag>([\s\S]*?)</tag>');

  static bool looksLikeEnex(String text) =>
      text.contains('<en-export') || text.contains('evernote-export');

  static ImportBundle parse(String xml) {
    if (!looksLikeEnex(xml)) {
      throw const ImportFormatException('This is not an Evernote .enex file.');
    }
    final notes = <ImportedNote>[];
    for (final m in _note.allMatches(xml)) {
      final body = m.group(1)!;
      notes.add(
        ImportedNote(
          title: _decode(_title.firstMatch(body)?.group(1) ?? '').trim(),
          text: enmlToText(_content.firstMatch(body)?.group(1) ?? ''),
          tags: [
            for (final t in _tag.allMatches(body)) _decode(t.group(1)!).trim(),
          ],
          createdAt: ImportParsing.dateTime(
            _created.firstMatch(body)?.group(1),
          ),
        ),
      );
    }
    if (notes.isEmpty) {
      throw const ImportFormatException('No notes found in this .enex file.');
    }
    return ImportBundle(source: ImportSource.evernote, notes: notes);
  }

  /// ENML (XHTML subset) → plain text with checklist markers.
  static String enmlToText(String enml) {
    var s = enml
        .replaceAll(RegExp(r'<\?xml[^>]*\?>'), '')
        .replaceAll(RegExp(r'<!DOCTYPE[^>]*>'), '')
        .replaceAll(RegExp(r'<en-todo[^>]*checked="true"[^>]*/?>'), '[x] ')
        .replaceAll(RegExp(r'<en-todo[^>]*/?>'), '[ ] ')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(div|p|li|h\d|tr)>', caseSensitive: false), '\n')
        .replaceAll(RegExp('<[^>]+>'), '');
    s = _decode(s);
    return s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  static String _decode(String s) => s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'")
      .replaceAllMapped(RegExp(r'&#(x?[0-9a-fA-F]+);'), (m) {
        final g = m.group(1)!;
        final code = g.startsWith('x')
            ? int.tryParse(g.substring(1), radix: 16)
            : int.tryParse(g);
        return code == null ? m.group(0)! : String.fromCharCode(code);
      })
      .replaceAll('&amp;', '&');
}
