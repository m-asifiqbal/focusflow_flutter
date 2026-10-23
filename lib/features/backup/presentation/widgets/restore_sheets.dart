/// ============================================================
/// RESTORE SHEETS — preview → Merge / Replace → PIN → restore
/// ============================================================
///
/// What: [runRestoreFlow] drives the whole restore of an opened backup:
/// preview sheet (device, date, counts per module), the Merge / Replace
/// choice (Replace asks once more), the backup PIN when encrypted (retry
/// on a wrong PIN), a blocking progress dialog, and a summary toast that
/// says what was *not* restored too (vault kept, missing attachments) and,
/// on failure, exactly what changed.
/// [showBackupPinSheet] is also used to turn on "Encrypt backups".
/// Why: Backup & Sync, the restore picker and the Import tab restore the
/// same way; nothing is written before the PIN has been verified.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/crypto/argon2_runner.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_format.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/backup/presentation/backup_style.dart';
import 'package:focusflow/features/backup/presentation/notifiers/backup_actions.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

/// Asks for a backup PIN (4–12 digits). [confirm] asks twice (setting a
/// new PIN). Null when cancelled.
Future<String?> showBackupPinSheet(
  BuildContext context, {
  required String title,
  required String message,
  bool confirm = false,
  String? error,
}) => showFFBottomSheet<String>(
  context,
  builder: (_) =>
      _PinSheet(title: title, message: message, confirm: confirm, error: error),
);

class _PinSheet extends StatefulWidget {
  const _PinSheet({
    required this.title,
    required this.message,
    required this.confirm,
    this.error,
  });

  final String title;
  final String message;
  final bool confirm;
  final String? error;

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  final _pin = TextEditingController();
  final _again = TextEditingController();
  late String? _error = widget.error;

  @override
  void dispose() {
    _pin.dispose();
    _again.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pin.text;
    if (pin.length < 4) {
      setState(() => _error = tr('Use at least 4 digits'));
      return;
    }
    if (widget.confirm && pin != _again.text) {
      setState(() => _error = tr("The PINs don't match"));
      return;
    }
    Navigator.of(context).pop(pin);
  }

  InputDecoration _field(String hint) => InputDecoration(hintText: hint);

  @override
  Widget build(BuildContext context) {
    final digits = [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(12),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: context.text.title),
        const SizedBox(height: AppSpacing.sm),
        Text(widget.message, style: context.text.bodySmall),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _pin,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: digits,
          decoration: _field(tr('Backup PIN')),
          onSubmitted: (_) => widget.confirm ? null : _submit(),
        ),
        if (widget.confirm) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _again,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            decoration: _field(tr('Repeat PIN')),
            onSubmitted: (_) => _submit(),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            style: context.text.meta.copyWith(color: context.ff.danger),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FFPrimaryButton(label: tr('Continue'), onPressed: _submit),
      ],
    );
  }
}

/// Preview of [m] with the Merge / Replace choice. Null = cancelled.
Future<RestoreMode?> showRestorePreviewSheet(
  BuildContext context,
  BackupManifest m, {
  required DateTime now,
}) => showFFBottomSheet<RestoreMode>(
  context,
  builder: (ctx) => _PreviewSheet(manifest: m, now: now),
);

class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet({required this.manifest, required this.now});

  final BackupManifest manifest;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final m = manifest;
    final rows = [
      (ModuleStyle.notes, tr('Notes'), m.counts['notes'] ?? 0),
      (ModuleStyle.tasks, tr('Tasks'), m.counts['tasks'] ?? 0),
      (ModuleStyle.reminders, tr('Reminders'), m.counts['reminders'] ?? 0),
      (ModuleStyle.habits, tr('Habits'), m.counts['habits'] ?? 0),
      if ((m.counts['medicines'] ?? 0) > 0)
        (ModuleStyle.medicines, tr('Medicines'), m.counts['medicines']!),
      (ModuleStyle.vault, tr('Vault'), m.counts['vault_items'] ?? 0),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tr('Restore this backup?'), style: text.title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          [
            BackupLabels.when(m.createdAt.toLocal(), now),
            if (m.deviceName.isNotEmpty) m.deviceName,
            if (m.isEncrypted) tr('Encrypted'),
          ].join(' · '),
          style: text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        FFGroupedList(
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
            if (m.hasSettings)
              FFListRow(
                leading: FFIconTile(
                  icon: FontAwesomeIcons.sliders,
                  colors: BackupTints.settings,
                  size: AppSizes.iconTileSm,
                ),
                title: tr('App settings'),
                value: tr('Included'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        FFPrimaryButton(
          label: tr('Merge with this phone'),
          icon: FontAwesomeIcons.codeMerge,
          onPressed: () => Navigator.of(context).pop(RestoreMode.merge),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          m.hasSettings
              ? tr(
                  'Adds what is missing; the newest edit of each item wins. Settings you changed on this phone stay.',
                )
              : tr('Adds what is missing; the newest edit of each item wins.'),
          textAlign: TextAlign.center,
          style: text.meta.copyWith(fontWeight: FontWeight.w400),
        ),
        const SizedBox(height: AppSpacing.md),
        FFSoftDangerButton(
          label: tr('Replace everything'),
          icon: FontAwesomeIcons.rotateLeft,
          onPressed: () => Navigator.of(context).pop(RestoreMode.replace),
        ),
      ],
    );
  }
}

/// A restore (open + flow) is running somewhere in the app.
bool _restoreRunning = false;

/// Opens a backup with [open] (Drive download / file read) and runs
/// [runRestoreFlow] on it, toasting the outcome. One restore at a time,
/// app-wide: a second tap while a backup downloads is ignored — two flows
/// used to stack their sheets and dialogs. With [showProgress] a
/// "Downloading the backup…" dialog covers the download, so the screen
/// never looks dead (off for the file picker, which has its own UI).
Future<void> restoreFromSource(
  BuildContext context,
  WidgetRef ref,
  Future<BackupArchive?> Function() open, {
  bool showProgress = true,
}) async {
  if (_restoreRunning) return;
  _restoreRunning = true;
  try {
    final BackupArchive? archive;
    final progress = showProgress
        ? showFFProgressDialog(context, tr('Downloading the backup…'))
        : null;
    try {
      archive = await open();
    } finally {
      progress?.close();
    }
    if (archive == null || !context.mounted) return;
    final msg = await runRestoreFlow(context, ref, archive);
    if (msg != null && context.mounted) showFFToast(context, msg);
  } on DriveFailure catch (f) {
    if (context.mounted) showFFToast(context, f.message);
  } on FormatException catch (e) {
    if (context.mounted) showFFToast(context, e.message);
  } on Object {
    if (context.mounted) {
      showFFToast(context, tr("Restore failed. Your data wasn't changed."));
    }
  } finally {
    _restoreRunning = false;
  }
}

/// Runs preview → mode → PIN → restore for [archive]. Returns the summary
/// shown to the user, or null when cancelled.
Future<String?> runRestoreFlow(
  BuildContext context,
  WidgetRef ref,
  BackupArchive archive,
) async {
  final now = ref.read(clockProvider).now();
  final mode = await showRestorePreviewSheet(
    context,
    archive.manifest,
    now: now,
  );
  if (mode == null || !context.mounted) return null;
  if (mode == RestoreMode.replace) {
    final ok = await showFFConfirm(
      context,
      title: tr('Replace all data?'),
      // Two whole sentences (not a sentence + a tacked-on fragment).
      message: archive.manifest.hasSettings
          ? tr(
              'Everything on this phone is replaced by the backup. Items that aren\'t in the backup are removed. Settings are restored too.',
            )
          : tr(
              'Everything on this phone is replaced by the backup. Items that aren\'t in the backup are removed.',
            ),
      confirmLabel: tr('Replace'),
      destructive: true,
      icon: FontAwesomeIcons.triangleExclamation,
    );
    if (!ok || !context.mounted) return null;
  }
  final actions = ref.read(backupActionsProvider);
  String? error;
  while (true) {
    if (!context.mounted) return null;
    String? pin;
    if (archive.manifest.isEncrypted) {
      pin = await showBackupPinSheet(
        context,
        title: tr('Enter backup PIN'),
        message: tr(
          'This backup is encrypted. Enter the PIN it was made with.',
        ),
        error: error,
      );
      if (pin == null || !context.mounted) return null;
    }
    // Closed through its handle: a blind pop could close something else
    // pushed above it and leave this un-dismissable dialog up for good.
    final progress = showFFProgressDialog(context, tr('Restoring…'));
    try {
      final r = await actions.restore(archive, mode: mode, pin: pin);
      progress.close();
      return restoreSummary(r);
    } on WrongBackupPin {
      progress.close();
      error = tr('Wrong PIN. Try again.');
    } on Argon2Failure {
      // The PIN could not even be checked: this phone ran out of memory or
      // was too slow for the backup's key settings. Nothing was changed.
      progress.close();
      error = tr(
        "This phone couldn't check the PIN (low memory). Close other apps "
        'and try again.',
      );
    } on FormatException catch (e) {
      // Damaged / newer-version backups fail before anything changes.
      progress.close();
      return e.message;
    } on RestoreFailed catch (e) {
      progress.close();
      return restoreFailedMessage(e);
    } on Object {
      // Everything else fails before writing (PIN / file checks).
      progress.close();
      return tr("Restore failed. Your data wasn't changed.");
    }
  }
}

/// The toast after a restore: what came back, and what didn't (vault
/// rows kept because this phone's vault uses another key, files missing,
/// settings that could not be read).
@visibleForTesting
String restoreSummary(RestoreResult r) {
  final rep = r.report;
  final parts = <String>[
    if (r.mode == RestoreMode.replace)
      tr('Restored {count, plural, one {# item} other {# items}}', {
        'count': rep.added,
      })
    else
      tr('Restore done · {added} added · {updated} updated', {
        'added': rep.added,
        'updated': rep.updated,
      }),
    if (r.settingsRestored) tr('Settings restored'),
    if (!r.vaultRestored)
      tr(
        "Vault items weren't restored — this phone's vault uses a different "
        'PIN',
      ),
    if (r.filesMissing > 0)
      tr(
        '{count, plural, one {# attachment is} other {# attachments are}} '
        'missing',
        {'count': r.filesMissing},
      ),
    if (r.settingsFailed) tr("Settings couldn't be restored"),
  ];
  return parts.join(' · ');
}

/// Exactly what a failed restore left behind (see RestoreFailed).
@visibleForTesting
String restoreFailedMessage(RestoreFailed e) => e.vaultKeyChanged
    ? tr(
        "Restore failed — your items weren't changed, but your vault now "
        "opens with the backup's PIN.",
      )
    : tr("Restore failed. Your data wasn't changed.");
