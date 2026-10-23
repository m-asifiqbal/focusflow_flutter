/// ============================================================
/// IMPORT TAB — Import & Export › Import (screen 35)
/// ============================================================
///
/// What: pick a file → detected source + preview (a colour-coded
/// composition bar and counts per kind, rows that will be skipped —
/// import_review_widgets.dart) → Import (dedupe by title + date) with progress →
/// summary with the partial-failure report. A .ffbackup goes through the
/// restore flow (Merge / Replace, PIN). Password CSVs ask to unlock the
/// vault before they are even parsed, and are encrypted on write.
/// Why: one linear flow driven by [importControllerProvider]; the widget
/// only renders its phases.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/backup/domain/entities/import_bundle.dart';
import 'package:focusflow/features/backup/presentation/notifiers/import_export_controllers.dart';
import 'package:focusflow/features/backup/presentation/widgets/import_review_widgets.dart';
import 'package:focusflow/features/backup/presentation/widgets/restore_sheets.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';

/// Supported sources shown before a file is picked (a getter: the
/// descriptions follow the language; product / format names stay as they are).
List<(String, String)> get kImportFormats => [
  (tr('FocusFlow backup'), tr('.ffbackup — restore with Merge or Replace')),
  (
    'FocusFlow JSON / CSV',
    tr('Your own exports (medicines too), or any CSV with a title column'),
  ),
  ('Google Keep', tr('Google Takeout zip or note .json files')),
  ('Todoist', tr('Project CSV export')),
  ('Bitwarden / 1Password', tr('CSV export — encrypted into your vault')),
  ('Loop Habit Tracker', tr('Export zip (habits + checkmarks)')),
  ('Evernote', tr('.enex notebook export')),
];

class ImportTab extends ConsumerWidget {
  const ImportTab({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref) => ref
      .read(importControllerProvider.notifier)
      .pick(
        // Password CSVs: unlock first, parse after.
        unlockVault: () async =>
            context.mounted && await ensureVaultUnlocked(context),
      );

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final c = ref.read(importControllerProvider.notifier);
    final s = ref.read(importControllerProvider);
    if (s.archive case final archive?) {
      final msg = await runRestoreFlow(context, ref, archive);
      if (msg != null) c.restored(msg);
      return;
    }
    if ((s.bundle?.logins.isNotEmpty ?? false) &&
        !await ensureVaultUnlocked(context)) {
      return;
    }
    await c.confirm();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(importControllerProvider);
    final c = ref.read(importControllerProvider.notifier);
    return switch (s.phase) {
      ImportPhase.idle => _Intro(onPick: () => _pick(context, ref)),
      ImportPhase.reading => Padding(
        padding: EdgeInsetsDirectional.only(top: AppSpacing.xxxl),
        child: FFLoadingView(message: tr('Reading file…')),
      ),
      ImportPhase.preview => ImportPreviewView(
        source: s.bundle?.source.label ?? ImportSource.ffbackup.label,
        fileName: s.fileName,
        parts: _parts(s),
        total: s.bundle?.itemCount ?? s.archive?.manifest.itemCount ?? 0,
        problems: [for (final p in s.bundle?.problems ?? const []) p.message],
        hasLogins: s.bundle?.logins.isNotEmpty ?? false,
        isBackup: s.bundle == null,
        onImport: () => _confirm(context, ref),
        onCancel: c.reset,
      ),
      ImportPhase.importing => ImportProgressView(
        progress: s.progress,
        total: s.total,
      ),
      ImportPhase.done => ImportSummaryView(
        imported: s.result?.imported,
        duplicates: s.result?.duplicates ?? 0,
        failed: s.result?.failed ?? 0,
        failures: s.result?.failures ?? const [],
        title: s.result == null
            ? tr('Restore complete')
            : (s.result!.failed > 0
                  ? tr('Imported with some problems')
                  : tr('Import complete')),
        message: s.result == null ? s.summary : null,
        notice: s.notice,
        onDone: c.reset,
      ),
      ImportPhase.error => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FFErrorBanner(
            message: s.error ?? tr('This file could not be read.'),
            retryLabel: tr('Choose another'),
            onRetry: () => _pick(context, ref),
          ),
          const SizedBox(height: AppSpacing.section),
          _Intro(onPick: () => _pick(context, ref)),
        ],
      ),
    };
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FFCard(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Import a file'), style: context.text.cardTitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tr(
                'FocusFlow detects the format, shows what it found and skips items you already have (same title and date).',
              ),
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            FFPrimaryButton(
              label: tr('Choose file…'),
              icon: FontAwesomeIcons.fileImport,
              onPressed: onPick,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.section),
      FFGroupedList(
        label: tr('Supported'),
        children: [
          for (final (title, sub) in kImportFormats)
            FFListRow(title: title, subtitle: sub),
        ],
      ),
    ],
  );
}

/// The kinds of items in the file (or backup), in module order.
List<ImportPart> _parts(ImportState state) {
  final b = state.bundle;
  final m = state.archive?.manifest;
  if (b != null) {
    return [
      (ModuleStyle.notes, tr('Notes'), b.notes.length),
      (ModuleStyle.tasks, tr('Tasks'), b.tasks.length),
      (ModuleStyle.reminders, tr('Reminders'), b.reminders.length),
      (ModuleStyle.habits, tr('Habits'), b.habits.length),
      (ModuleStyle.medicines, tr('Medicines'), b.medicines.length),
      (ModuleStyle.vault, tr('Passwords'), b.logins.length),
    ];
  }
  if (m == null) return const [];
  return [
    (ModuleStyle.notes, tr('Notes'), m.counts['notes'] ?? 0),
    (ModuleStyle.tasks, tr('Tasks'), m.counts['tasks'] ?? 0),
    (ModuleStyle.reminders, tr('Reminders'), m.counts['reminders'] ?? 0),
    (ModuleStyle.habits, tr('Habits'), m.counts['habits'] ?? 0),
    (ModuleStyle.medicines, tr('Medicines'), m.counts['medicines'] ?? 0),
    (ModuleStyle.vault, tr('Vault'), m.counts['vault_items'] ?? 0),
  ];
}
