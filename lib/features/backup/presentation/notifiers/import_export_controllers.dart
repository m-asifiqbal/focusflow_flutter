/// ============================================================
/// IMPORT / EXPORT CONTROLLERS — state of screen 35's two tabs
/// ============================================================
///
/// What:
/// * [ExportController] holds the chosen [ExportOptions] and runs
///   build → save, reporting busy / done / error.
/// * [ImportController] runs pick → detect → preview → import with
///   progress, then a summary (with the partial-failure list). A
///   `.ffbackup` previews as a backup and is restored through
///   BackupActions (Merge / Replace, PIN when encrypted). Password CSVs
///   ask to unlock the vault before they are parsed; any read error
///   (even a TypeError from an odd JSON shape) ends in a clear error
///   state, never a stuck "Reading file…".
/// Why: no business logic in widgets; the tab widgets render these states.
/// The picked file's temporary copy is discarded as soon as it is parsed
/// (password CSVs are plaintext).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/notifications/notification_engine.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_format.dart';
import 'package:focusflow/core/sync/backup_key_policy.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/sync/vault_bridge.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/features/backup/data/export_service.dart';
import 'package:focusflow/features/backup/data/import_file_source.dart';
import 'package:focusflow/features/backup/domain/entities/export_options.dart';
import 'package:focusflow/features/backup/domain/entities/import_bundle.dart';
import 'package:focusflow/features/backup/domain/services/importers/import_detector.dart';
import 'package:focusflow/features/backup/presentation/providers/backup_providers.dart';

// ───────────────────────────── Export ─────────────────────────────

@immutable
class ExportState {
  const ExportState({this.options = const ExportOptions(), this.busy = false});

  final ExportOptions options;
  final bool busy;

  ExportState copyWith({ExportOptions? options, bool? busy}) =>
      ExportState(options: options ?? this.options, busy: busy ?? this.busy);
}

final exportControllerProvider =
    NotifierProvider.autoDispose<ExportController, ExportState>(
      ExportController.new,
    );

class ExportController extends AutoDisposeNotifier<ExportState> {
  bool _alive = true;

  @override
  ExportState build() {
    ref.onDispose(() => _alive = false);
    return const ExportState();
  }

  void _set(ExportOptions o) => state = state.copyWith(options: o);

  void setFormat(ExportFormat f) {
    final o = state.options;
    // Drive only takes .ffbackup (the app sees only its own folder).
    final target = f != ExportFormat.ffbackup && o.target == ExportTarget.drive
        ? ExportTarget.device
        : o.target;
    _set(o.copyWith(format: f, target: target));
  }

  void toggleModule(ExportModule m) {
    final next = {...state.options.modules};
    if (!next.remove(m)) next.add(m);
    _set(state.options.copyWith(modules: next));
  }

  void setArchived(bool v) => _set(state.options.copyWith(includeArchived: v));

  void setAttachments(bool v) =>
      _set(state.options.copyWith(includeAttachments: v));

  void setSettings(bool v) => _set(state.options.copyWith(includeSettings: v));

  void setTarget(ExportTarget t) => _set(state.options.copyWith(target: t));

  /// Builds and saves the export. Returns the message for the snackbar,
  /// or null when the user cancelled the save dialog / share sheet.
  Future<String?> export() async {
    if (state.busy) return null;
    state = state.copyWith(busy: true);
    try {
      final service = ref.read(exportServiceProvider);
      final file = await service.build(state.options);
      final saved = await service.save(file, state.options.target);
      if (!saved) return null;
      final n = file.itemCount;
      final where = switch (state.options.target) {
        ExportTarget.drive => 'to Google Drive',
        ExportTarget.device => 'to this device',
        ExportTarget.share => '',
      };
      final sealed = file.backup == null
          ? ''
          : file.isEncrypted
          ? ' · encrypted'
          : ' · not encrypted';
      return 'Exported $n ${n == 1 ? 'item' : 'items'} $where'.trim() + sealed;
    } on VaultExportNeedsKey {
      return 'Set a backup PIN in Backup & Sync to export the vault.';
    } on BackupPinRequired {
      return '"Encrypt backups" is on: set a backup PIN in Backup & Sync, '
          'or turn encryption off to export unencrypted.';
    } on BackupKeyUnavailable catch (e) {
      return e.message;
    } on DriveFailure catch (f) {
      return f.message;
    } catch (e) {
      AppLogger.w('Export failed (${e.runtimeType})');
      return 'Export failed. Please try again.';
    } finally {
      if (_alive) state = state.copyWith(busy: false);
    }
  }
}

// ───────────────────────────── Import ─────────────────────────────

enum ImportPhase { idle, reading, preview, importing, done, error }

@immutable
class ImportState {
  const ImportState({
    this.phase = ImportPhase.idle,
    this.fileName,
    this.bundle,
    this.archive,
    this.progress = 0,
    this.total = 0,
    this.result,
    this.error,
    this.summary,
    this.notice,
  });

  final ImportPhase phase;
  final String? fileName;

  /// Parsed items (anything but a .ffbackup). Holds plaintext logins, so
  /// it is dropped as soon as the import ends (done / error).
  final ImportBundle? bundle;

  /// A picked .ffbackup (restored via BackupActions).
  final BackupArchive? archive;
  final double progress;

  /// Items being imported (kept after [bundle] is dropped).
  final int total;
  final ImportResult? result;
  final String? error;

  /// One-line outcome of a .ffbackup restore.
  final String? summary;

  /// Secondary note after a successful import (e.g. alerts not refreshed).
  final String? notice;
}

/// Shown when a file could not be read for an unexpected reason.
const String kImportUnreadable =
    "This file couldn't be read. It may be damaged or in a format "
    'FocusFlow doesn’t support.';

final importControllerProvider =
    NotifierProvider.autoDispose<ImportController, ImportState>(
      ImportController.new,
    );

class ImportController extends AutoDisposeNotifier<ImportState> {
  bool _alive = true;

  @override
  ImportState build() {
    ref.onDispose(() => _alive = false);
    return const ImportState();
  }

  void _set(ImportState s) {
    if (_alive) state = s;
  }

  /// Picks a file and detects its format. False when cancelled.
  /// [unlockVault] is asked *before* a password-manager CSV is parsed
  /// (false → nothing is parsed and the file copy is discarded).
  /// Never throws: any failure ends in [ImportPhase.error].
  Future<bool> pick({Future<bool> Function()? unlockVault}) async {
    final PickedImportFile? picked;
    try {
      picked = await ref.read(importFileSourceProvider).pick();
    } on Object catch (e) {
      AppLogger.w('Import pick failed (${e.runtimeType})');
      _set(
        const ImportState(
          phase: ImportPhase.error,
          error: "Couldn't open the file picker. Please try again.",
        ),
      );
      return true;
    }
    if (picked == null) return false;
    final name = picked.name;
    _set(ImportState(phase: ImportPhase.reading, fileName: name));
    ImportState error(String message) =>
        ImportState(phase: ImportPhase.error, fileName: name, error: message);
    try {
      if (ImportDetector.isFfBackup(name, picked.bytes)) {
        final archive = ref.read(backupEngineProvider).inspect(picked.bytes);
        _set(
          ImportState(
            phase: ImportPhase.preview,
            fileName: name,
            archive: archive,
          ),
        );
        return true;
      }
      if (ImportDetector.isPasswordExport(name, picked.bytes) &&
          !(await unlockVault?.call() ?? false)) {
        _set(error('Unlock the vault to import passwords.'));
        return true;
      }
      final bundle = ImportDetector.parse(name, picked.bytes);
      _set(
        bundle.isEmpty
            ? error('Nothing to import in this file.')
            : ImportState(
                phase: ImportPhase.preview,
                fileName: name,
                bundle: bundle,
                total: bundle.itemCount,
              ),
      );
    } on ImportFormatException catch (e) {
      _set(error(e.message));
    } on FormatException catch (e) {
      _set(error(e.message));
    } on Object catch (e) {
      // TypeError from an unexpected JSON shape, a corrupt zip entry, …
      AppLogger.w('Import read failed (${e.runtimeType})');
      _set(error(kImportUnreadable));
    } finally {
      // Parsed into memory: the plaintext temporary copy goes now.
      try {
        await picked.discard();
      } on Object {
        // Best effort: the OS clears the cache folder eventually.
      }
    }
    return true;
  }

  /// Writes the previewed bundle (the caller has unlocked the vault when
  /// it contains logins). The import's own outcome is reported first; a
  /// failing notification re-plan afterwards only adds a [notice].
  Future<void> confirm() async {
    final bundle = state.bundle;
    if (bundle == null || state.phase != ImportPhase.preview) return;
    final name = state.fileName;
    final total = bundle.itemCount;
    _set(
      ImportState(
        phase: ImportPhase.importing,
        fileName: name,
        bundle: bundle,
        total: total,
      ),
    );
    final ImportResult result;
    try {
      result = await ref
          .read(importWriterProvider)
          .write(
            bundle,
            onProgress: (done, total) => _set(
              ImportState(
                phase: ImportPhase.importing,
                fileName: name,
                bundle: bundle,
                total: total,
                progress: total == 0 ? 1 : done / total,
              ),
            ),
          );
    } on VaultUnavailable catch (e) {
      // The writer throws only before anything was written.
      _set(
        ImportState(phase: ImportPhase.error, fileName: name, error: e.message),
      );
      return;
    } on Object catch (e) {
      AppLogger.w('Import failed (${e.runtimeType})');
      _set(
        ImportState(
          phase: ImportPhase.error,
          fileName: name,
          error: 'Import failed. Nothing was changed.',
        ),
      );
      return;
    }
    // Done: the parsed plaintext (logins) is dropped from state now.
    _set(
      ImportState(
        phase: ImportPhase.done,
        fileName: name,
        total: total,
        progress: 1,
        result: result,
      ),
    );
    if (bundle.reminders.isEmpty && bundle.habits.isEmpty) return;
    try {
      await ref.read(notificationEngineProvider).onResume();
    } on Object catch (e) {
      AppLogger.w('Re-plan after import failed (${e.runtimeType})');
      _set(
        ImportState(
          phase: ImportPhase.done,
          fileName: name,
          total: total,
          progress: 1,
          result: result,
          notice:
              "Imported reminders and habits will get their alerts the next "
              'time FocusFlow opens.',
        ),
      );
    }
  }

  /// Marks a .ffbackup restore as finished with [summary].
  void restored(String summary) => state = ImportState(
    phase: ImportPhase.done,
    fileName: state.fileName,
    summary: summary,
  );

  void reset() => state = const ImportState();
}
