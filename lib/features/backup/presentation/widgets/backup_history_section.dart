/// ============================================================
/// BACKUP HISTORY SECTION — HISTORY rows of Backup & Sync (34)
/// ============================================================
///
/// What: this device's backups (Drive + local), newest first: tile, date
/// ("Today, 9:39 AM"), "Google Drive · 2.4 MB · auto" / "Local ·
/// /FocusFlow · 2.3 MB", and a ⋯ menu with Restore, Download, Delete.
/// Why: live from backup_records, so Sync now / Back up now / pruning
/// show up at once. Deleting a backup file asks first (it can't be undone).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/sync/local_backups.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/backup/domain/entities/backup_record.dart';
import 'package:focusflow/features/backup/presentation/backup_style.dart';
import 'package:focusflow/features/backup/presentation/notifiers/backup_actions.dart';
import 'package:focusflow/features/backup/presentation/providers/backup_providers.dart';
import 'package:focusflow/features/backup/presentation/widgets/restore_sheets.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class BackupHistorySection extends ConsumerWidget {
  const BackupHistorySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(backupHistoryProvider);
    return history.when(
      loading: () => const FFGroupedList(
        label: 'History',
        children: [
          Padding(
            padding: EdgeInsetsDirectional.all(AppSpacing.lg),
            child: FFSkeleton(height: 40),
          ),
        ],
      ),
      error: (e, _) => FFErrorBanner(
        message: "Couldn't load backup history",
        onRetry: () => ref.invalidate(backupHistoryProvider),
      ),
      data: (rows) => rows.isEmpty
          ? FFGroupedList(
              label: 'History',
              children: [
                FFEmptyState(
                  compact: true,
                  colors: ModuleStyle.notes.colors,
                  icon: FontAwesomeIcons.clockRotateLeft,
                  title: 'No backups yet',
                  body: 'Your backups will be listed here.',
                ),
              ],
            )
          : FFGroupedList(
              label: 'History',
              children: [for (final r in rows) _HistoryRow(record: r)],
            ),
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.record});

  final BackupRecord record;

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(backupActionsProvider);
    try {
      final archive = await actions.open(
        RestoreCandidate(
          kind: record.location == BackupLocation.drive
              ? RestoreSourceKind.drive
              : RestoreSourceKind.local,
          createdAt: record.createdAt,
          sizeBytes: record.sizeBytes,
          itemCount: record.itemCount,
          isEncrypted: record.isEncrypted,
          driveFileId: record.driveFileId,
          record: record,
        ),
      );
      if (!context.mounted) return;
      final msg = await runRestoreFlow(context, ref, archive);
      if (msg != null && context.mounted) showFFToast(context, msg);
    } on DriveFailure catch (f) {
      if (context.mounted) showFFToast(context, f.message);
    } on FormatException catch (e) {
      if (context.mounted) showFFToast(context, e.message);
    }
  }

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    try {
      final ok = await ref.read(backupActionsProvider).download(record);
      if (ok && context.mounted) showFFToast(context, 'Backup saved');
    } on Object {
      if (context.mounted) showFFToast(context, "Couldn't download the backup");
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showFFConfirm(
      context,
      title: 'Delete this backup?',
      message: 'The backup file is deleted for good.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: FontAwesomeIcons.trashCan,
    );
    if (!ok) return;
    try {
      await ref.read(backupActionsProvider).delete(record);
    } on Object {
      if (context.mounted) showFFToast(context, "Couldn't delete the backup");
    }
  }

  void _menu(BuildContext context, WidgetRef ref, String title) {
    final tint = record.location == BackupLocation.drive
        ? BackupTints.drive
        : BackupTints.local;
    showFFActionSheet(
      context,
      FFActionSheetData(
        header: FFActionSheetHeader(
          title: title,
          icon: FontAwesomeIcons.clockRotateLeft,
          colors: tint,
        ),
        actions: [
          FFActionItem(
            icon: FontAwesomeIcons.clockRotateLeft,
            label: 'Restore',
            colors: ModuleStyle.notes.colors,
            onTap: () => _restore(context, ref),
          ),
          FFActionItem(
            icon: FontAwesomeIcons.download,
            label: 'Download',
            colors: BackupTints.drive,
            onTap: () => _download(context, ref),
          ),
          FFActionItem(
            icon: FontAwesomeIcons.trashCan,
            label: 'Delete',
            colors: BackupTints.keep,
            destructive: true,
            onTap: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final now = ref.watch(clockProvider).now();
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final drive = record.location == BackupLocation.drive;
    final title = BackupLabels.when(record.createdAt, now, use24h: use24h);
    final subtitle = [
      drive ? 'Google Drive' : 'Local · /${LocalBackups.folder}',
      BackupLabels.size(record.sizeBytes),
      if (record.isAuto) 'auto',
    ].join(' · ');
    return FFListRow(
      leading: FFIconTile.soft(
        icon: drive
            ? FontAwesomeIcons.cloud
            : FontAwesomeIcons.mobileScreenButton,
        colors: drive ? BackupTints.drive : BackupTints.local,
        size: AppSizes.iconTile - 2,
      ),
      title: title,
      subtitle: subtitle,
      onLongPress: () => _menu(context, ref, title),
      trailing: IconButton(
        tooltip: 'Backup options',
        onPressed: () => _menu(context, ref, title),
        constraints: const BoxConstraints.tightFor(
          width: AppSizes.minTap,
          height: AppSizes.minTap,
        ),
        padding: EdgeInsets.zero,
        icon: Icon(FontAwesomeIcons.ellipsis, size: 16, color: ff.inkFaint),
      ),
    );
  }
}
