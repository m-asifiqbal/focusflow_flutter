/// ============================================================
/// EXPORT WRITERS — JSON / CSV / Markdown bytes from a snapshot
/// ============================================================
///
/// What: the file contents of the JSON, CSV and PDF/MD export formats
/// (the .ffbackup comes from BackupEngine; the PDF page layout lives in
/// data/notes_pdf_export.dart because it loads bundled fonts).
/// Why: pure functions over [ExportRecords] keep every format testable
/// and guarantee the FocusFlow importer can read its own exports back.
/// ============================================================
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:focusflow/core/sync/snapshot.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/backup/domain/entities/export_options.dart';
import 'package:focusflow/features/backup/domain/services/csv_codec.dart';
import 'package:focusflow/features/backup/domain/services/export_records.dart';

/// CSV column order per module (also what the FocusFlow CSV importer
/// expects).
const Map<ExportModule, List<String>> kCsvColumns = {
  ExportModule.notes: [
    'type', 'title', 'text', 'tags', 'folder', 'pinned', 'created', //
    'updated', 'archived',
  ],
  ExportModule.tasks: [
    'type', 'title', 'notes', 'due', 'dueTime', 'priority', 'repeat', //
    'completed', 'subtasks', 'tags', 'folder', 'created', 'archived',
  ],
  ExportModule.reminders: [
    'type', 'title', 'note', 'at', 'repeat', 'enabled', 'completed', //
    'created', 'archived',
  ],
  ExportModule.habits: [
    'type', 'name', 'kind', 'target', 'unit', 'frequencyType', //
    'weekdaysMask', 'timesPerWeek', 'everyNDays', 'startDate', 'paused', //
    'doneDays', 'created', 'archived',
  ],
};

abstract final class ExportWriters {
  /// `focusflow-export-2026-06-14.json` style names.
  static String fileName(DateTime now, String extension) =>
      'focusflow-export-${DateUtilsX.dayKey(now)}.$extension';

  /// Pretty JSON of every included module.
  static Uint8List json(
    DbSnapshot s,
    Set<ExportModule> modules, {
    required DateTime now,
    String appVersion = '',
  }) {
    final r = ExportRecords(s);
    final doc = <String, Object?>{
      'format': kFocusFlowExportFormat,
      'version': 1,
      'exportedAt': now.toIso8601String(),
      if (appVersion.isNotEmpty) 'appVersion': appVersion,
      if (modules.contains(ExportModule.notes)) 'notes': r.notes(),
      if (modules.contains(ExportModule.tasks)) 'tasks': r.tasks(),
      if (modules.contains(ExportModule.reminders)) 'reminders': r.reminders(),
      if (modules.contains(ExportModule.habits)) 'habits': r.habits(),
    };
    return Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(doc)),
    );
  }

  /// CSV text per module (vault never).
  static Map<ExportModule, String> csvFiles(
    DbSnapshot s,
    Set<ExportModule> modules,
  ) {
    final r = ExportRecords(s);
    final out = <ExportModule, String>{};
    for (final m in kCsvColumns.keys) {
      if (!modules.contains(m)) continue;
      final records = switch (m) {
        ExportModule.notes => r.notes(),
        ExportModule.tasks => r.tasks(),
        ExportModule.reminders => r.reminders(),
        ExportModule.habits => r.habits(),
        ExportModule.vault => const <Map<String, Object?>>[],
      };
      final cols = kCsvColumns[m]!;
      out[m] = CsvCodec.encode([
        cols,
        for (final rec in records) [for (final c in cols) _cell(m, c, rec)],
      ]);
    }
    return out;
  }

  static Object? _cell(ExportModule m, String col, Map<String, Object?> r) {
    return switch (col) {
      'type' => m.itemType,
      'tags' => (r['tags'] as List?)?.join('; ') ?? '',
      'subtasks' => [
        for (final st in (r['subtasks'] as List? ?? const []))
          '${(st as Map)['done'] == true ? '[x]' : '[ ]'} ${st['title']}',
      ].join('\n'),
      'doneDays' => [
        for (final l in (r['logs'] as List? ?? const []))
          if ((l as Map)['skipped'] != true && ((l['count'] as int?) ?? 0) > 0)
            l['count'] == 1 ? l['date'] : '${l['date']}=${l['count']}',
      ].join(' '),
      _ => r[col],
    };
  }

  /// One CSV as bytes, or a zip of several.
  static ({Uint8List bytes, String extension}) csv(
    DbSnapshot s,
    Set<ExportModule> modules,
  ) {
    final files = csvFiles(s, modules);
    if (files.length == 1) {
      return (
        bytes: Uint8List.fromList(utf8.encode(files.values.single)),
        extension: 'csv',
      );
    }
    final zip = Archive();
    for (final e in files.entries) {
      zip.addFile(ArchiveFile.string('${e.key.table}.csv', e.value));
    }
    return (bytes: ZipEncoder().encodeBytes(zip), extension: 'zip');
  }

  /// Markdown file name + body per note (`notes/<title>.md`).
  static Map<String, String> markdownNotes(DbSnapshot s) {
    final used = <String>{};
    final out = <String, String>{};
    for (final n in ExportRecords(s).notes()) {
      final title = '${n['title']}'.trim();
      var base = _safeName(title.isEmpty ? 'Untitled' : title);
      var name = base;
      for (var i = 2; used.contains(name.toLowerCase()); i++) {
        name = '$base ($i)';
      }
      used.add(name.toLowerCase());
      final tags = (n['tags'] as List).map((t) => '#$t').join(' ');
      out['notes/$name.md'] = [
        '# ${title.isEmpty ? 'Untitled' : title}',
        '',
        if (tags.isNotEmpty) ...[tags, ''],
        '${n['text']}'.trimRight(),
        '',
      ].join('\n');
    }
    return out;
  }

  /// Zip of the Markdown notes plus [pdf] (all notes in one document).
  static Uint8List notesZip(DbSnapshot s, {Uint8List? pdf}) {
    final zip = Archive();
    for (final e in markdownNotes(s).entries) {
      zip.addFile(ArchiveFile.string(e.key, e.value));
    }
    if (pdf != null) zip.addFile(ArchiveFile.bytes('notes.pdf', pdf));
    return ZipEncoder().encodeBytes(zip);
  }

  static String _safeName(String s) {
    final cleaned = s
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.length > 60 ? cleaned.substring(0, 60).trim() : cleaned;
  }
}
