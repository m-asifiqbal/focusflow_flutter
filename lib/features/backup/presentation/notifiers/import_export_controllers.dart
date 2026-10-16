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
///   BackupActions (Merge / Replace, PIN when encrypted).
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
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/features/backup/data/export_service.dart';
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
      return 'Exported $n ${n == 1 ? 'item' : 'items'} $where'.trim();
    } on VaultExportNeedsKey {
      return 'Turn on "Encrypt backups" in Backup & Sync to export the vault.';
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
    this.result,
    this.error,
    this.summary,
  });

  final ImportPhase phase;
  final String? fileName;

  /// Parsed items (anything but a .ffbackup).
  final ImportBundle? bundle;

  /// A picked .ffbackup (restored via BackupActions).
  final BackupArchive? archive;
  final double progress;
  final ImportResult? result;
  final String? error;

  /// One-line outcome of a .ffbackup restore.
  final String? summary;
}

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

  /// Picks a file and detects its format. False when cancelled.
  Future<bool> pick() async {
    final picked = await ref.read(importFileSourceProvider).pick();
    if (picked == null) return false;
    state = ImportState(phase: ImportPhase.reading, fileName: picked.name);
    try {
      if (ImportDetector.isFfBackup(picked.name, picked.bytes)) {
        final archive = ref.read(backupEngineProvider).inspect(picked.bytes);
        state = ImportState(
          phase: ImportPhase.preview,
          fileName: picked.name,
          archive: archive,
        );
      } else {
        final bundle = ImportDetector.parse(picked.name, picked.bytes);
        state = bundle.isEmpty
            ? ImportState(
                phase: ImportPhase.error,
                fileName: picked.name,
                error: 'Nothing to import in this file.',
              )
            : ImportState(
                phase: ImportPhase.preview,
                fileName: picked.name,
                bundle: bundle,
              );
      }
    } on ImportFormatException catch (e) {
      state = ImportState(
        phase: ImportPhase.error,
        fileName: picked.name,
        error: e.message,
      );
    } on FormatException catch (e) {
      state = ImportState(
        phase: ImportPhase.error,
        fileName: picked.name,
        error: e.message,
      );
    } finally {
      // Parsed into memory: the plaintext temporary copy goes now.
      await picked.discard();
    }
    return true;
  }

  /// Writes the previewed bundle (the caller has unlocked the vault when
  /// it contains logins).
  Future<void> confirm() async {
    final bundle = state.bundle;
    if (bundle == null || state.phase != ImportPhase.preview) return;
    final name = state.fileName;
    state = ImportState(
      phase: ImportPhase.importing,
      fileName: name,
      bundle: bundle,
    );
    try {
      final result = await ref
          .read(importWriterProvider)
          .write(
            bundle,
            onProgress: (done, total) {
              if (!_alive) return;
              state = ImportState(
                phase: ImportPhase.importing,
                fileName: name,
                bundle: bundle,
                progress: total == 0 ? 1 : done / total,
              );
            },
          );
      if (!_alive) return;
      state = ImportState(
        phase: ImportPhase.done,
        fileName: name,
        bundle: bundle,
        progress: 1,
        result: result,
      );
      if (bundle.reminders.isNotEmpty || bundle.habits.isNotEmpty) {
        await ref.read(notificationEngineProvider).onResume();
      }
    } catch (e) {
      AppLogger.w('Import failed (${e.runtimeType})');
      if (!_alive) return;
      state = ImportState(
        phase: ImportPhase.error,
        fileName: name,
        error: 'Import failed. Nothing more was changed.',
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
