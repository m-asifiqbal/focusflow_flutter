/// ============================================================
/// BACKUP SETTINGS SECTIONS — AUTOMATIC BACKUP + LOCAL BACKUP (34)
/// ============================================================
///
/// What: Auto backup to Drive, Frequency (Daily · 9:00 PM), Sync when app
/// opens, Wi-Fi only (applies to both automatic kinds),
/// Encrypt backups (sets the backup PIN — separate from the vault PIN —
/// the first time), Keep last N;
/// Back up to device now, Backup location, Auto local backup.
/// Why: every row writes [settingsProvider]; BackgroundTasks reschedules
/// itself on settings changes, so nothing else needs to be told.
/// Drive-only rows are hidden while no Google account is connected.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/sync/backup_key_policy.dart';
import 'package:focusflow/core/sync/local_backups.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/backup/presentation/backup_style.dart';
import 'package:focusflow/features/backup/presentation/notifiers/backup_actions.dart';
import 'package:focusflow/features/backup/presentation/providers/backup_providers.dart';
import 'package:focusflow/features/backup/presentation/widgets/backup_prompts.dart';
import 'package:focusflow/features/backup/presentation/widgets/restore_sheets.dart';
import 'package:focusflow/features/settings/presentation/widgets/notifications/notification_pickers.dart';
import 'package:focusflow/features/settings/presentation/widgets/settings_option_sheet.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

Widget _tile(IconData icon, ModuleColors c) =>
    FFIconTile(icon: icon, colors: c, size: AppSizes.iconTileSm);

class AutomaticBackupSection extends ConsumerWidget {
  const AutomaticBackupSection({required this.connected, super.key});

  /// Google Drive connected (shows the Drive rows).
  final bool connected;

  Future<void> _frequency(BuildContext context, WidgetRef ref) async {
    final s = ref.read(settingsProvider);
    final f = await pickSetting<BackupFrequency>(
      context,
      title: tr('Backup frequency'),
      selected: s.backupFrequency,
      options: [
        option(BackupFrequency.daily, tr('Daily')),
        option(BackupFrequency.weekly, tr('Weekly')),
      ],
    );
    if (f == null || !context.mounted) return;
    final t = await showNotificationTimeSheet(
      context,
      title: tr('Backup time'),
      subtitle: tr('Runs when your phone is idle around this time'),
      minutes: s.backupMinutes,
      use24h: s.use24HourTime,
    );
    await ref
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            backupFrequency: f,
            backupMinutes: t?.value ?? s.backupMinutes,
          ),
        );
  }

  Future<void> _keep(BuildContext context, WidgetRef ref) async {
    final s = ref.read(settingsProvider);
    final n = await pickSetting<int>(
      context,
      title: tr('Keep last'),
      subtitle: tr('Older backups are deleted automatically'),
      selected: s.keepBackups,
      options: [
        for (final n in const [3, 5, 10, 20, 30])
          option(n, tr('{n} backups', {'n': n})),
      ],
    );
    if (n == null) return;
    await ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(keepBackups: n));
  }

  Future<void> _encrypt(BuildContext context, WidgetRef ref, bool on) async {
    final actions = ref.read(backupActionsProvider);
    if (!on) return actions.setEncrypt(false);
    if (await ref.read(backupKeyExistsProvider.future)) {
      return actions.setEncrypt(true);
    }
    if (!context.mounted) return;
    final pin = await showBackupPinSheet(
      context,
      title: tr('Set a backup PIN'),
      message: kBackupPinMessage,
      confirm: true,
    );
    if (pin == null) return;
    try {
      await actions.enableEncryption(pin);
    } on Object {
      if (context.mounted) {
        showFFToast(
          context,
          tr("Couldn't save the backup PIN on this device. Try again."),
          icon: FontAwesomeIcons.triangleExclamation,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final hasKey = ref.watch(backupKeyExistsProvider).valueOrNull ?? false;
    final edit = ref.read(settingsProvider.notifier);
    final encrypted = s.encryptBackups && hasKey;
    return FFGroupedList(
      label: tr('Automatic backup'),
      children: [
        if (connected) ...[
          FFListRow.toggle(
            leading: _tile(FontAwesomeIcons.cloudArrowUp, BackupTints.drive),
            title: tr('Auto backup to Drive'),
            value: s.autoBackupDrive,
            onChanged: (v) =>
                edit.update((s) => s.copyWith(autoBackupDrive: v)),
          ),
          FFListRow(
            leading: _tile(
              FontAwesomeIcons.solidCalendar,
              BackupTints.frequency,
            ),
            title: tr('Frequency'),
            value: BackupLabels.frequency(s),
            enabled: s.autoBackupDrive,
            onTap: () => _frequency(context, ref),
          ),
          FFListRow.toggle(
            leading: _tile(FontAwesomeIcons.arrowsRotate, BackupTints.openSync),
            title: tr('Sync when app opens'),
            subtitle: tr('Gets changes from your other devices'),
            value: s.syncOnOpen,
            onChanged: (v) => edit.update((s) => s.copyWith(syncOnOpen: v)),
          ),
          FFListRow.toggle(
            leading: _tile(FontAwesomeIcons.wifi, BackupTints.wifi),
            title: tr('Wi-Fi only'),
            value: s.backupWifiOnly,
            onChanged: (v) => edit.update((s) => s.copyWith(backupWifiOnly: v)),
          ),
        ],
        FFListRow.toggle(
          leading: _tile(FontAwesomeIcons.lock, BackupTints.encrypt),
          title: tr('Encrypt backups'),
          subtitle: encrypted
              ? tr('Protected with your backup PIN')
              : s.encryptBackups
              ? tr('Set a backup PIN to keep backing up')
              : tr('Backups can be opened without a PIN'),
          value: encrypted,
          onChanged: (v) => _encrypt(context, ref, v),
        ),
        FFListRow(
          leading: _tile(FontAwesomeIcons.layerGroup, BackupTints.keep),
          title: tr('Keep last'),
          value: tr('{n} backups', {'n': s.keepBackups}),
          onTap: () => _keep(context, ref),
        ),
      ],
    );
  }
}

class LocalBackupSection extends ConsumerStatefulWidget {
  const LocalBackupSection({super.key});

  @override
  ConsumerState<LocalBackupSection> createState() => _LocalBackupSectionState();
}

class _LocalBackupSectionState extends ConsumerState<LocalBackupSection> {
  bool _busy = false;

  Future<void> _backUpNow() async {
    if (_busy) return;
    // First backup with "Encrypt backups" on and no PIN: ask, never write
    // plaintext silently.
    if (await backupEncryptionUnresolved(ref)) {
      if (!mounted || !await resolveBackupEncryption(context, ref)) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final r = await ref.read(backupActionsProvider).backUpToDevice();
      if (mounted) {
        showFFToast(
          context,
          tr('Backed up {count} items · {size}', {
                'count': r.itemCount,
                'size': BackupLabels.size(r.sizeBytes),
              }) +
              (r.isEncrypted
                  ? ' · ${tr('encrypted')}'
                  : ' · ${tr('not encrypted')}'),
          icon: FontAwesomeIcons.check,
        );
      }
    } on BackupKeyUnavailable catch (e) {
      if (mounted) {
        showFFToast(
          context,
          e.message,
          icon: FontAwesomeIcons.triangleExclamation,
        );
      }
    } on BackupPinRequired catch (e) {
      if (mounted) {
        showFFToast(
          context,
          e.message,
          icon: FontAwesomeIcons.triangleExclamation,
        );
      }
    } on Object {
      if (mounted) {
        showFFToast(
          context,
          tr("Couldn't write the backup. Check free space."),
          icon: FontAwesomeIcons.triangleExclamation,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _frequency() async {
    final s = ref.read(settingsProvider);
    final f = await pickSetting<LocalBackupFrequency>(
      context,
      title: tr('Auto local backup'),
      selected: s.localBackupFrequency,
      options: [
        for (final f in LocalBackupFrequency.values)
          option(f, BackupLabels.localFrequency(f)),
      ],
    );
    if (f == null) return;
    await ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(localBackupFrequency: f));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    return FFGroupedList(
      label: tr('Local backup'),
      children: [
        FFListRow(
          leading: _tile(FontAwesomeIcons.hardDrive, BackupTints.deviceNow),
          title: tr('Back up to device now'),
          trailing: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          chevron: !_busy,
          onTap: _backUpNow,
        ),
        FFListRow(
          leading: _tile(
            FontAwesomeIcons.solidFolderOpen,
            BackupTints.location,
          ),
          title: tr('Backup location'),
          value: 'Documents/${LocalBackups.folder}',
          onTap: () => showFFConfirm(
            context,
            title: tr('Backup location'),
            message: tr(
              'Local backups are kept in Documents/{folder} in FocusFlow\'s storage. Use Download on a backup below to save a copy anywhere else.',
              {'folder': LocalBackups.folder},
            ),
            confirmLabel: tr('OK'),
            icon: FontAwesomeIcons.solidFolderOpen,
          ),
        ),
        FFListRow(
          leading: _tile(
            FontAwesomeIcons.mobileScreenButton,
            BackupTints.autoLocal,
          ),
          title: tr('Auto local backup'),
          value: BackupLabels.localFrequency(s.localBackupFrequency),
          onTap: _frequency,
        ),
      ],
    );
  }
}
