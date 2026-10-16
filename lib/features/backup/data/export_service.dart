/// ============================================================
/// EXPORT SERVICE — builds and saves Import & Export files
/// ============================================================
///
/// What: turns [ExportOptions] into one file (.ffbackup through
/// BackupEngine with the module filter; JSON / CSV / PDF+MD through
/// ExportWriters) and saves it to Google Drive (only .ffbackup — the app
/// can only see its own hidden Drive folder), the device (system save
/// dialog) or the share sheet.
/// Why: one place that enforces "vault only inside an encrypted
/// .ffbackup": vault rows are dropped from every other format, and a
/// .ffbackup with vault items refuses to build without a backup key.
/// A .ffbackup is sealed whenever a backup key exists; with "Encrypt
/// backups" on and no key it refuses ([BackupPinRequired]) instead of
/// silently writing plaintext, and a keychain error fails the export
/// ([BackupKeyUnavailable]). [ExportFile.isEncrypted] tells the truth.
/// ============================================================
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_key_policy.dart';
import 'package:focusflow/core/sync/drive_sync.dart';
import 'package:focusflow/core/sync/local_backups.dart';
import 'package:focusflow/core/sync/snapshot.dart';
import 'package:focusflow/core/utils/clock.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/backup/data/notes_pdf_export.dart';
import 'package:focusflow/features/backup/domain/entities/export_options.dart';
import 'package:focusflow/features/backup/domain/services/export_filter.dart';
import 'package:focusflow/features/backup/domain/services/export_records.dart';
import 'package:focusflow/features/backup/domain/services/export_writers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// A built export, ready to save.
class ExportFile {
  const ExportFile({
    required this.name,
    required this.bytes,
    required this.mimeType,
    required this.itemCount,
    this.backup,
    this.isEncrypted = false,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;
  final int itemCount;

  /// Set for .ffbackup (Drive upload needs the manifest).
  final BuiltBackup? backup;

  /// Sealed with the backup key (only ever true for a .ffbackup).
  final bool isEncrypted;
}

/// Vault items were chosen but no backup key exists to encrypt them.
class VaultExportNeedsKey implements Exception {
  const VaultExportNeedsKey();
}

typedef ShareExport = Future<bool> Function(ExportFile file);

class ExportService {
  ExportService({
    required this.engine,
    required this.keys,
    required this.encryptBackups,
    required this.drive,
    required this.local,
    required this.clock,
    this.pdf = const NotesPdfExport(),
    ShareExport? share,
  }) : _share = share ?? _platformShare;

  final BackupEngine engine;
  final BackupKeyPolicy keys;
  final bool Function() encryptBackups;
  final DriveSync drive;
  final LocalBackups local;
  final Clock clock;
  final NotesPdfExport pdf;
  final ShareExport _share;

  DbSnapshot Function(DbSnapshot) _filter(ExportOptions o) =>
      (s) => ExportFilter.apply(
        s,
        modules: o.effectiveModules,
        includeArchived: o.includeArchived,
      );

  Future<ExportFile> build(ExportOptions o) async {
    final now = clock.now();
    final filter = _filter(o);
    switch (o.format) {
      case ExportFormat.ffbackup:
        final key = await keys.storedKey();
        if (key == null) {
          if (o.effectiveModules.contains(ExportModule.vault)) {
            throw const VaultExportNeedsKey();
          }
          if (encryptBackups()) throw const BackupPinRequired();
        }
        final built = await engine.build(
          key: key,
          filter: filter,
          includeFiles: o.includeAttachments,
        );
        return ExportFile(
          name: 'FocusFlow-${DateUtilsX.dayKey(now)}.ffbackup',
          bytes: built.bytes,
          mimeType: 'application/octet-stream',
          itemCount: built.manifest.itemCount,
          backup: built,
          isEncrypted: built.manifest.isEncrypted,
        );
      case ExportFormat.json:
        final s = filter(await engine.snapshot());
        return ExportFile(
          name: ExportWriters.fileName(now, 'json'),
          bytes: ExportWriters.json(s, o.effectiveModules, now: now),
          mimeType: 'application/json',
          itemCount: ExportFilter.itemCount(s),
        );
      case ExportFormat.csv:
        final s = filter(await engine.snapshot());
        final out = ExportWriters.csv(s, o.effectiveModules);
        return ExportFile(
          name: ExportWriters.fileName(now, out.extension),
          bytes: out.bytes,
          mimeType: out.extension == 'csv' ? 'text/csv' : 'application/zip',
          itemCount: ExportFilter.itemCount(s),
        );
      case ExportFormat.pdfMd:
        final s = filter(await engine.snapshot());
        final notes = ExportRecords(s).notes();
        final pdfBytes = await pdf.build([
          for (final n in notes)
            (
              title: '${n['title']}'.trim().isEmpty
                  ? 'Untitled'
                  : '${n['title']}',
              subtitle: _subtitle(n),
              text: '${n['text']}',
            ),
        ]);
        return ExportFile(
          name: ExportWriters.fileName(now, 'zip'),
          bytes: ExportWriters.notesZip(s, pdf: pdfBytes),
          mimeType: 'application/zip',
          itemCount: notes.length,
        );
    }
  }

  static String _subtitle(Map<String, Object?> n) {
    final created = DateTime.tryParse('${n['created']}');
    final tags = (n['tags'] as List).map((t) => '#$t').join(' ');
    return [
      if (created != null) 'Created ${DateUtilsX.dayKey(created)}',
      if (tags.isNotEmpty) tags,
    ].join(' · ');
  }

  /// Saves [f] to [target]; false when the user cancelled.
  Future<bool> save(ExportFile f, ExportTarget target) async {
    switch (target) {
      case ExportTarget.drive:
        final built = f.backup;
        if (built == null) {
          throw UnsupportedError('Only .ffbackup files can go to Drive');
        }
        await drive.uploadBuilt(built);
        return true;
      case ExportTarget.device:
        return local.saveBytes(f.name, f.bytes);
      case ExportTarget.share:
        return _share(f);
    }
  }

  static Future<bool> _platformShare(ExportFile f) async {
    final dir = Directory(
      p.join((await getTemporaryDirectory()).path, 'exports'),
    );
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, f.name));
    try {
      await file.writeAsBytes(f.bytes, flush: true);
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: f.mimeType)],
          subject: 'FocusFlow export',
        ),
      );
      return result.status != ShareResultStatus.dismissed;
    } finally {
      try {
        if (file.existsSync()) await file.delete();
      } on FileSystemException {
        // Best effort: the OS clears the temporary directory eventually.
      }
    }
  }
}
