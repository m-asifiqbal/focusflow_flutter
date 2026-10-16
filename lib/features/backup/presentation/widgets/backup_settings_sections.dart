/// ============================================================
/// BACKUP SETTINGS SECTIONS — AUTOMATIC BACKUP + LOCAL BACKUP (34)
/// ============================================================
///
/// What: Auto backup to Drive, Frequency (Daily · 9:00 PM), Wi-Fi only,
/// Encrypt backups (sets the backup PIN the first time), Keep last N;
/// Back up to device now, Backup location, Auto local backup.
/// Why: every row writes [settingsProvider]; BackgroundTasks reschedules
/// itself on settings changes, so nothing else needs to be told.
/// Drive-only rows are hidden while no Google account is connected.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/sync/local_backups.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/backup/presentation/backup_style.dart';
import 'package:focusflow/features/backup/presentation/notifiers/backup_actions.dart';
import 'package:focusflow/features/backup/presentation/providers/backup_providers.dart';
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
      title: 'Backup frequency',
      selected: s.backupFrequency,
      options: [
        option(BackupFrequency.daily, 'Daily'),
        option(BackupFrequency.weekly, 'Weekly'),
      ],
    );
    if (f == null || !context.mounted) return;
    final t = await showNotificationTimeSheet(
      context,
      title: 'Backup time',
      subtitle: 'Runs when your phone is idle around this time',
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
      title: 'Keep last',
      subtitle: 'Older backups are deleted automatically',
      selected: s.keepBackups,
      options: [
        for (final n in const [3, 5, 10, 20, 30]) option(n, '$n backups'),
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
      title: 'Set a backup PIN',
      message:
          'Backups are encrypted with this PIN. Use the same PIN on your '
          'other devices — without it a backup cannot be opened.',
      confirm: true,
    );
    if (pin == null) return;
    await actions.enableEncryption(pin);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final hasKey = ref.watch(backupKeyExistsProvider).valueOrNull ?? false;
    final edit = ref.read(settingsProvider.notifier);
    final encrypted = s.encryptBackups && hasKey;
    return FFGroupedList(
      label: 'Automatic backup',
      children: [
        if (connected) ...[
          FFListRow.toggle(
            leading: _tile(FontAwesomeIcons.cloudArrowUp, BackupTints.drive),
            title: 'Auto backup to Drive',
            value: s.autoBackupDrive,
            onChanged: (v) =>
                edit.update((s) => s.copyWith(autoBackupDrive: v)),
          ),
          FFListRow(
            leading: _tile(
              FontAwesomeIcons.solidCalendar,
              BackupTints.frequency,
            ),
            title: 'Frequency',
            value: BackupLabels.frequency(s),
            enabled: s.autoBackupDrive,
            onTap: () => _frequency(context, ref),
          ),
          FFListRow.toggle(
            leading: _tile(FontAwesomeIcons.wifi, BackupTints.wifi),
            title: 'Wi-Fi only',
            value: s.backupWifiOnly,
            onChanged: (v) => edit.update((s) => s.copyWith(backupWifiOnly: v)),
          ),
        ],
        FFListRow.toggle(
          leading: _tile(FontAwesomeIcons.lock, BackupTints.encrypt),
          title: 'Encrypt backups',
          subtitle: encrypted
              ? 'Protected with your master PIN'
              : 'Backups can be opened without a PIN',
          value: encrypted,
          onChanged: (v) => _encrypt(context, ref, v),
        ),
        FFListRow(
          leading: _tile(FontAwesomeIcons.layerGroup, BackupTints.keep),
          title: 'Keep last',
          value: '${s.keepBackups} backups',
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
    setState(() => _busy = true);
    try {
      final r = await ref.read(backupActionsProvider).backUpToDevice();
      if (mounted) {
        showFFToast(
          context,
          'Backed up ${r.itemCount} items · ${BackupLabels.size(r.sizeBytes)}',
          icon: FontAwesomeIcons.check,
        );
      }
    } on Object {
      if (mounted) {
        showFFToast(
          context,
          "Couldn't write the backup. Check free space.",
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
      title: 'Auto local backup',
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
      label: 'Local backup',
      children: [
        FFListRow(
          leading: _tile(FontAwesomeIcons.hardDrive, BackupTints.deviceNow),
          title: 'Back up to device now',
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
          title: 'Backup location',
          value: 'Documents/${LocalBackups.folder}',
          onTap: () => showFFConfirm(
            context,
            title: 'Backup location',
            message:
                'Local backups are kept in Documents/${LocalBackups.folder} '
                "in FocusFlow's storage. Use Download on a backup below to "
                'save a copy anywhere else.',
            confirmLabel: 'OK',
            icon: FontAwesomeIcons.solidFolderOpen,
          ),
        ),
        FFListRow(
          leading: _tile(
            FontAwesomeIcons.mobileScreenButton,
            BackupTints.autoLocal,
          ),
          title: 'Auto local backup',
          value: BackupLabels.localFrequency(s.localBackupFrequency),
          onTap: _frequency,
        ),
      ],
    );
  }
}
