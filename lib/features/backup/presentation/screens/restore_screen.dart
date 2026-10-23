/// ============================================================
/// RESTORE SCREEN — Settings › Backup & Sync › Restore
/// ============================================================
///
/// What: pick a backup — GOOGLE DRIVE (every device's backups) and ON THIS
/// DEVICE, or "Choose a backup file…" — then the shared restore flow
/// (preview counts → Merge / Replace → PIN if encrypted).
/// Why: the restore entry for Backup & Sync and for "Sign in → Backup
/// found" (`/sign-in?intent=restore` lands here right after Google).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_format.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/backup/domain/services/importers/import_detector.dart';
import 'package:focusflow/features/backup/presentation/backup_style.dart';
import 'package:focusflow/features/backup/presentation/notifiers/backup_actions.dart';
import 'package:focusflow/features/backup/presentation/providers/backup_providers.dart';
import 'package:focusflow/features/backup/presentation/widgets/restore_sheets.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

class RestoreScreen extends ConsumerWidget {
  const RestoreScreen({super.key});

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    Future<BackupArchive?> Function() open, {
    bool showProgress = true,
  }) => restoreFromSource(context, ref, open, showProgress: showProgress);

  Future<BackupArchive?> _pickFile(WidgetRef ref) async {
    final f = await ref.read(importFileSourceProvider).pick();
    if (f == null) return null;
    try {
      if (!ImportDetector.isFfBackup(f.name, f.bytes)) {
        throw FormatException(tr('Choose a FocusFlow .ffbackup file'));
      }
      return await ref.read(backupEngineProvider).inspectAsync(f.bytes);
    } finally {
      await f.discard();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(restoreCandidatesProvider);
    final now = ref.watch(clockProvider).now();
    final actions = ref.read(backupActionsProvider);

    Widget row(RestoreCandidate c) {
      final drive = c.kind == RestoreSourceKind.drive;
      return FFListRow(
        leading: FFIconTile.soft(
          icon: drive
              ? FontAwesomeIcons.cloud
              : FontAwesomeIcons.mobileScreenButton,
          colors: drive ? BackupTints.drive : BackupTints.local,
          size: AppSizes.iconTile - 2,
        ),
        title: BackupLabels.when(c.createdAt, now),
        subtitle: [
          if (c.deviceName.isNotEmpty) c.deviceName,
          tr('{count} items', {'count': c.itemCount}),
          BackupLabels.size(c.sizeBytes),
          if (c.isEncrypted) tr('encrypted'),
        ].join(' · '),
        onTap: () => _restore(context, ref, () => actions.open(c)),
      );
    }

    return FFScaffold(
      body: Column(
        children: [
          FFNavHeader(
            leading: FFBackButton(label: tr('Backup')),
            title: tr('Restore'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.grouped,
                AppSpacing.sm,
                AppSpacing.grouped,
                AppSpacing.xxl,
              ),
              children: [
                ...candidates.when(
                  loading: () => const [
                    FFSkeletonCard(lines: 3, showTag: false),
                    SizedBox(height: AppSpacing.cardGap),
                    FFSkeletonCard(lines: 3, showTag: false),
                  ],
                  error: (e, _) => [
                    FFErrorBanner(
                      message: tr('Couldn\'t list your backups'),
                      onRetry: () => ref.invalidate(restoreCandidatesProvider),
                    ),
                  ],
                  data: (list) {
                    final drive = list.items
                        .where((c) => c.kind == RestoreSourceKind.drive)
                        .toList();
                    final local = list.items
                        .where((c) => c.kind == RestoreSourceKind.local)
                        .toList();
                    return [
                      if (list.driveError case final e?) ...[
                        FFErrorBanner(
                          message: e.message,
                          onRetry: () =>
                              ref.invalidate(restoreCandidatesProvider),
                        ),
                        const SizedBox(height: AppSpacing.section),
                      ],
                      if (list.items.isEmpty)
                        FFEmptyState(
                          compact: true,
                          colors: ModuleStyle.notes.colors,
                          icon: FontAwesomeIcons.clockRotateLeft,
                          title: tr('No backups found'),
                          body: tr(
                            'Back up from Backup & Sync, or choose a .ffbackup file below.',
                          ),
                        ),
                      if (drive.isNotEmpty) ...[
                        FFGroupedList(
                          label: tr('Google Drive'),
                          children: [for (final c in drive) row(c)],
                        ),
                        const SizedBox(height: AppSpacing.section),
                      ],
                      if (local.isNotEmpty) ...[
                        FFGroupedList(
                          label: tr('On this device'),
                          children: [for (final c in local) row(c)],
                        ),
                        const SizedBox(height: AppSpacing.section),
                      ],
                    ];
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                FFGroupedList(
                  children: [
                    FFListRow(
                      leading: FFIconTile(
                        icon: FontAwesomeIcons.solidFolderOpen,
                        colors: BackupTints.location,
                        size: AppSizes.iconTileSm,
                      ),
                      title: tr('Choose a backup file…'),
                      onTap: () => _restore(
                        context,
                        ref,
                        () => _pickFile(ref),
                        showProgress: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
