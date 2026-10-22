/// ============================================================
/// IMPORT DETECTOR — picks the right parser for a file
/// ============================================================
///
/// What: looks at the file name and content (zip entries, JSON shape, CSV
/// header, XML root) and runs the matching importer. A `.ffbackup` is not
/// parsed here: the caller previews it with BackupEngine.inspect.
/// Why: "pick file → detect format → preview" — people rarely know which
/// export flavour they have, so the screen never asks.
/// ============================================================
library;

import 'dart:convert';

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/backup/domain/entities/import_bundle.dart';
import 'package:focusflow/features/backup/domain/services/csv_codec.dart';
import 'package:focusflow/features/backup/domain/services/importers/focusflow_importer.dart';
import 'package:focusflow/features/backup/domain/services/importers/import_parsing.dart';
import 'package:focusflow/features/backup/domain/services/importers/notes_app_importers.dart';
import 'package:focusflow/features/backup/domain/services/importers/password_importers.dart';
import 'package:focusflow/features/backup/domain/services/importers/tasks_habits_importers.dart';

abstract final class ImportDetector {
  /// Whether [bytes] is a FocusFlow backup (zip with manifest.json).
  static bool isFfBackup(String fileName, List<int> bytes) {
    if (fileName.toLowerCase().endsWith('.ffbackup')) return true;
    final zip = ImportParsing.zip(bytes);
    return zip?.findFile('manifest.json') != null &&
        zip?.findFile('db.json') != null;
  }

  /// Whether [bytes] is a password-manager CSV export (Bitwarden /
  /// 1Password), judged from the header line(s) only — so the import flow
  /// can ask to unlock the vault *before* any login is parsed into memory.
  static bool isPasswordExport(String fileName, List<int> bytes) {
    try {
      final zip = ImportParsing.zip(bytes);
      if (zip != null) {
        return zip.files.any(
          (f) =>
              f.isFile &&
              f.name.toLowerCase().endsWith('.csv') &&
              _passwordHeader(ImportParsing.text(f.content)),
        );
      }
      return _passwordHeader(ImportParsing.text(bytes));
    } on Object {
      return false;
    }
  }

  static bool _passwordHeader(String text) {
    final firstLine = text.split(RegExp(r'\r?\n')).first;
    final rows = CsvCodec.decode(firstLine);
    if (rows.isEmpty) return false;
    final h = {for (final c in rows.first) c.trim().toLowerCase()};
    return PasswordImporters.isBitwarden(h) ||
        PasswordImporters.isOnePassword(h);
  }

  /// Parses [bytes] (anything but a .ffbackup). Throws
  /// [ImportFormatException] with a readable message.
  static ImportBundle parse(String fileName, List<int> bytes) {
    final name = fileName.toLowerCase();
    final zip = ImportParsing.zip(bytes);
    if (zip != null) {
      final files = {
        for (final f in zip.files)
          if (f.isFile) f.name.toLowerCase(): f,
      };
      final habits = files.entries
          .where((e) => e.key.endsWith('habits.csv'))
          .firstOrNull;
      if (habits != null) {
        final checks =
            files.entries
                .where((e) => e.key.split('/').last == 'checkmarks.csv')
                .toList()
              ..sort((a, b) => a.key.length.compareTo(b.key.length));
        return LoopImporter.parse(
          ImportParsing.text(habits.value.content),
          checkmarksCsv: checks.isEmpty
              ? null
              : ImportParsing.text(checks.first.value.content),
        );
      }
      if (files.keys.any((k) => k.contains('keep/') && k.endsWith('.json'))) {
        return KeepImporter.parse(bytes);
      }
      final csvs = files.entries.where((e) => e.key.endsWith('.csv'));
      if (csvs.isNotEmpty) {
        return _merge([
          for (final c in csvs) _csv(ImportParsing.text(c.value.content)),
        ]);
      }
      throw ImportFormatException(
        tr("This zip doesn't contain anything FocusFlow can import."),
      );
    }
    final text = ImportParsing.text(bytes);
    if (name.endsWith('.enex') || EnexImporter.looksLikeEnex(text)) {
      return EnexImporter.parse(text);
    }
    final trimmed = text.trimLeft();
    if (name.endsWith('.json') || trimmed.startsWith('{')) {
      Object? json;
      try {
        json = jsonDecode(text);
      } on FormatException {
        throw ImportFormatException(tr('This JSON file is damaged.'));
      }
      if (KeepImporter.isKeepNote(json)) return KeepImporter.parse(bytes);
      return FocusFlowImporter.fromJson(text);
    }
    if (name.endsWith('.csv') || name.endsWith('.txt') || text.contains(',')) {
      return _csv(text);
    }
    if (name.endsWith('.1pux')) {
      throw ImportFormatException(
        tr(
          '1Password .1pux files are not supported yet. Export a CSV from '
          '1Password instead.',
        ),
      );
    }
    throw ImportFormatException(tr('FocusFlow can’t read this file type.'));
  }

  static ImportBundle _csv(String text) {
    final rows = CsvCodec.decode(text);
    if (rows.isEmpty) {
      throw ImportFormatException(tr('This CSV file is empty.'));
    }
    final h = {for (final c in rows.first) c.trim().toLowerCase()};
    if (PasswordImporters.isBitwarden(h)) {
      return PasswordImporters.bitwarden(text);
    }
    if (PasswordImporters.isOnePassword(h)) {
      return PasswordImporters.onePassword(text);
    }
    if (TodoistImporter.isTodoistCsv(h)) return TodoistImporter.parse(text);
    if (LoopImporter.isHabitsCsv(h)) return LoopImporter.parse(text);
    return FocusFlowImporter.fromCsv(text);
  }

  static ImportBundle _merge(List<ImportBundle> parts) => ImportBundle(
    source: parts.first.source,
    notes: [for (final p in parts) ...p.notes],
    tasks: [for (final p in parts) ...p.tasks],
    reminders: [for (final p in parts) ...p.reminders],
    habits: [for (final p in parts) ...p.habits],
    logins: [for (final p in parts) ...p.logins],
    problems: [for (final p in parts) ...p.problems],
  );
}
