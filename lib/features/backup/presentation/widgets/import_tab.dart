/// ============================================================
/// IMPORT TAB — Import & Export › Import (screen 35)
/// ============================================================
///
/// What: pick a file → detected source + preview (counts per kind, rows
/// that will be skipped) → Import (dedupe by title + date) with progress →
/// summary with the partial-failure report. A .ffbackup goes through the
/// restore flow (Merge / Replace, PIN). Password CSVs ask to unlock the
/// vault before they are even parsed, and are encrypted on write.
/// Why: one linear flow driven by [importControllerProvider]; the widget
/// only renders its phases.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/backup/domain/entities/import_bundle.dart';
import 'package:focusflow/features/backup/presentation/notifiers/import_export_controllers.dart';
import 'package:focusflow/features/backup/presentation/widgets/restore_sheets.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';

/// Supported sources shown before a file is picked.
const List<(String, String)> kImportFormats = [
  ('FocusFlow backup', '.ffbackup — restore with Merge or Replace'),
  ('FocusFlow JSON / CSV', 'Your own exports, or any CSV with a title column'),
  ('Google Keep', 'Google Takeout zip or note .json files'),
  ('Todoist', 'Project CSV export'),
  ('Bitwarden / 1Password', 'CSV export — encrypted into your vault'),
  ('Loop Habit Tracker', 'Export zip (habits + checkmarks)'),
  ('Evernote', '.enex notebook export'),
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
      ImportPhase.reading => const Padding(
        padding: EdgeInsetsDirectional.only(top: AppSpacing.xxxl),
        child: FFLoadingView(message: 'Reading file…'),
      ),
      ImportPhase.preview => _Preview(
        state: s,
        onImport: () => _confirm(context, ref),
        onCancel: c.reset,
      ),
      ImportPhase.importing => _Progress(state: s),
      ImportPhase.done => _Summary(state: s, onDone: c.reset),
      ImportPhase.error => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FFErrorBanner(
            message: s.error ?? 'This file could not be read.',
            retryLabel: 'Choose another',
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
            Text('Import a file', style: context.text.cardTitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'FocusFlow detects the format, shows what it found and skips '
              'items you already have (same title and date).',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            FFPrimaryButton(
              label: 'Choose file…',
              icon: FontAwesomeIcons.fileImport,
              onPressed: onPick,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.section),
      FFGroupedList(
        label: 'Supported',
        children: [
          for (final (title, sub) in kImportFormats)
            FFListRow(title: title, subtitle: sub),
        ],
      ),
    ],
  );
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.state,
    required this.onImport,
    required this.onCancel,
  });

  final ImportState state;
  final VoidCallback onImport;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final b = state.bundle;
    final m = state.archive?.manifest;
    final rows = <(ModuleStyle, String, int)>[
      if (b != null) ...[
        (ModuleStyle.notes, 'Notes', b.notes.length),
        (ModuleStyle.tasks, 'Tasks', b.tasks.length),
        (ModuleStyle.reminders, 'Reminders', b.reminders.length),
        (ModuleStyle.habits, 'Habits', b.habits.length),
        (ModuleStyle.vault, 'Passwords', b.logins.length),
      ] else if (m != null) ...[
        (ModuleStyle.notes, 'Notes', m.counts['notes'] ?? 0),
        (ModuleStyle.tasks, 'Tasks', m.counts['tasks'] ?? 0),
        (ModuleStyle.reminders, 'Reminders', m.counts['reminders'] ?? 0),
        (ModuleStyle.habits, 'Habits', m.counts['habits'] ?? 0),
        (ModuleStyle.vault, 'Vault', m.counts['vault_items'] ?? 0),
      ],
    ]..removeWhere((r) => r.$3 == 0);
    final total = b?.itemCount ?? m?.itemCount ?? 0;
    final source = b?.source.label ?? ImportSource.ffbackup.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFGroupedList(
          label: 'Detected · $source',
          footer: state.fileName,
          children: [
            for (final (style, label, n) in rows)
              FFListRow(
                leading: FFIconTile(
                  icon: style.icon,
                  colors: style.colors,
                  size: AppSizes.iconTileSm,
                ),
                title: label,
                value: '$n',
              ),
          ],
        ),
        if (b != null && b.problems.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          FFInfoBanner(
            icon: FontAwesomeIcons.circleInfo,
            colors: ModuleStyle.vault.colors,
            text: b.problems.take(4).map((p) => p.message).join('\n'),
          ),
        ],
        if (b != null && b.logins.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const FFInfoBanner(
            icon: FontAwesomeIcons.lock,
            text:
                'Passwords are encrypted into your vault as they are '
                'imported. Delete the CSV file afterwards.',
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        FFPrimaryButton(
          label: m != null
              ? 'Restore $total items…'
              : 'Import $total ${total == 1 ? 'item' : 'items'}',
          icon: FontAwesomeIcons.fileImport,
          onPressed: total == 0 ? null : onImport,
        ),
        const SizedBox(height: AppSpacing.sm),
        FFTextButton(label: 'Cancel', onPressed: onCancel),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state});

  final ImportState state;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final total = state.total;
    final done = (state.progress * total).round();
    return FFCard(
      padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Importing $done of $total…', style: context.text.cardTitle),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 8,
                color: ff.primary,
                backgroundColor: ff.divider,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.state, required this.onDone});

  final ImportState state;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final r = state.result;
    final failed = r != null && r.failed > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFCard(
          padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
          child: Column(
            children: [
              FFIconTile(
                icon: failed
                    ? FontAwesomeIcons.triangleExclamation
                    : FontAwesomeIcons.check,
                colors: failed
                    ? ModuleStyle.vault.colors
                    : ModuleStyle.notes.colors,
                size: AppSizes.iconTileLg,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                r == null
                    ? 'Restore complete'
                    : failed
                    ? 'Imported with some problems'
                    : 'Import complete',
                style: context.text.sectionTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                r == null
                    ? (state.summary ?? '')
                    : [
                        '${r.imported} imported',
                        if (r.duplicates > 0)
                          '${r.duplicates} duplicates skipped',
                        if (r.failed > 0) '${r.failed} failed',
                      ].join(' · '),
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
        if (state.notice case final notice?) ...[
          const SizedBox(height: AppSpacing.lg),
          FFInfoBanner(icon: FontAwesomeIcons.circleInfo, text: notice),
        ],
        if (failed) ...[
          const SizedBox(height: AppSpacing.section),
          FFGroupedList(
            label: "Couldn't import",
            children: [
              for (final f in r.failures.take(20))
                FFListRow(
                  title: f,
                  leading: FFIconTile.soft(
                    icon: FontAwesomeIcons.xmark,
                    colors: ModuleStyle.vault.colors,
                    size: AppSizes.iconTileSm,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        FFSecondaryButton(label: 'Done', onPressed: onDone),
      ],
    );
  }
}
