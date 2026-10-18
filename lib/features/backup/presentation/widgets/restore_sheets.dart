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
import 'package:focusflow/core/sync/backup_crypto.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_format.dart';
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
      setState(() => _error = 'Use at least 4 digits');
      return;
    }
    if (widget.confirm && pin != _again.text) {
      setState(() => _error = "The PINs don't match");
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
          decoration: _field('Backup PIN'),
          onSubmitted: (_) => widget.confirm ? null : _submit(),
        ),
        if (widget.confirm) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _again,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            decoration: _field('Repeat PIN'),
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
        FFPrimaryButton(label: 'Continue', onPressed: _submit),
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
      (ModuleStyle.notes, 'Notes', m.counts['notes'] ?? 0),
      (ModuleStyle.tasks, 'Tasks', m.counts['tasks'] ?? 0),
      (ModuleStyle.reminders, 'Reminders', m.counts['reminders'] ?? 0),
      (ModuleStyle.habits, 'Habits', m.counts['habits'] ?? 0),
      (ModuleStyle.vault, 'Vault', m.counts['vault_items'] ?? 0),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Restore this backup?', style: text.title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          [
            BackupLabels.when(m.createdAt.toLocal(), now),
            if (m.deviceName.isNotEmpty) m.deviceName,
            if (m.isEncrypted) 'Encrypted',
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
                title: 'App settings',
                value: 'Included',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        FFPrimaryButton(
          label: 'Merge with this phone',
          icon: FontAwesomeIcons.codeMerge,
          onPressed: () => Navigator.of(context).pop(RestoreMode.merge),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          m.hasSettings
              ? 'Adds what is missing; the newest edit of each item wins. '
                    'Settings you changed on this phone stay.'
              : 'Adds what is missing; the newest edit of each item wins.',
          textAlign: TextAlign.center,
          style: text.meta.copyWith(fontWeight: FontWeight.w400),
        ),
        const SizedBox(height: AppSpacing.md),
        FFSoftDangerButton(
          label: 'Replace everything',
          icon: FontAwesomeIcons.rotateLeft,
          onPressed: () => Navigator.of(context).pop(RestoreMode.replace),
        ),
      ],
    );
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
    final withSettings = archive.manifest.hasSettings
        ? ' Settings are restored too.'
        : '';
    final ok = await showFFConfirm(
      context,
      title: 'Replace all data?',
      message:
          "Everything on this phone is replaced by the backup. Items that "
          "aren't in the backup are removed.$withSettings",
      confirmLabel: 'Replace',
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
        title: 'Enter backup PIN',
        message: 'This backup is encrypted. Enter the PIN it was made with.',
        error: error,
      );
      if (pin == null || !context.mounted) return null;
    }
    final nav = Navigator.of(context, rootNavigator: true);
    showFFDialog<void>(
      context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: FFDialog(content: FFLoadingView(message: 'Restoring…')),
      ),
    );
    try {
      final r = await actions.restore(archive, mode: mode, pin: pin);
      nav.pop();
      return restoreSummary(r);
    } on WrongBackupPin {
      nav.pop();
      error = 'Wrong PIN. Try again.';
    } on FormatException catch (e) {
      // Damaged / newer-version backups fail before anything changes.
      nav.pop();
      return e.message;
    } on RestoreFailed catch (e) {
      nav.pop();
      return restoreFailedMessage(e);
    } on Object {
      // Everything else fails before writing (PIN / file checks).
      nav.pop();
      return "Restore failed. Your data wasn't changed.";
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
      'Restored ${rep.added} ${rep.added == 1 ? 'item' : 'items'}'
    else
      'Restore done · ${rep.added} added · ${rep.updated} updated',
    if (r.settingsRestored) 'Settings restored',
    if (!r.vaultRestored)
      "Vault items weren't restored — this phone's vault uses a different "
          'PIN',
    if (r.filesMissing > 0)
      '${r.filesMissing} ${r.filesMissing == 1 ? 'attachment is' : 'attachments are'} '
          'missing',
    if (r.settingsFailed) "Settings couldn't be restored",
  ];
  return parts.join(' · ');
}

/// Exactly what a failed restore left behind (see RestoreFailed).
@visibleForTesting
String restoreFailedMessage(RestoreFailed e) => e.vaultKeyChanged
    ? "Restore failed — your items weren't changed, but your vault now "
          "opens with the backup's PIN."
    : "Restore failed. Your data wasn't changed.";
