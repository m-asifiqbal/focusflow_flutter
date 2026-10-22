/// ============================================================
/// BACKUP PROMPTS — backup PIN choice + Backup & Sync banners
/// ============================================================
///
/// What:
/// * [syncNowWithPrompt] — every manual "Sync now", behind the PIN choice;
/// * [resolveBackupEncryption] — "Encrypt backups" is on but no backup PIN
///   exists: Set a backup PIN, or explicitly "Back up without encryption"
///   (turns the setting off). Asked at Drive connect, before the first
///   backup and from the banner — backups never fall back to plaintext
///   silently.
/// * [BackupEncryptionBanner] — persistent until that is resolved (or
///   when the stored key can't be read).
/// * [MergeDecisionBanner] — sign-in found Drive backups and the user has
///   not chosen Restore / Start fresh yet: merging waits for that choice.
/// Why: these choices protect data; they are the user's, made once, in
/// plain words.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/sync/backup_key_policy.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/backup/presentation/notifiers/backup_actions.dart';
import 'package:focusflow/features/backup/presentation/providers/backup_providers.dart';
import 'package:focusflow/features/backup/presentation/widgets/restore_sheets.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

/// Message of the "Set a backup PIN" sheet (a getter: it follows the language).
String get kBackupPinMessage => tr(
  'Backups are encrypted with this backup PIN — it is separate from your '
  'vault PIN. Use the same PIN on your other devices; without it a '
  'backup cannot be opened.',
);

/// "Sync now" (Backup & Sync card, Settings account card): with "Encrypt
/// backups" on and no backup PIN, asks first (Set a backup PIN / Back up
/// without encryption) — never uploads plaintext silently. Returns the
/// outcome; null when cancelled, failed (see syncStatusProvider) or a sync
/// was already running.
Future<SyncOutcome?> syncNowWithPrompt(
  BuildContext context,
  WidgetRef ref,
) async {
  if (await backupEncryptionUnresolved(ref)) {
    if (!context.mounted || !await resolveBackupEncryption(context, ref)) {
      return null;
    }
  }
  return ref.read(syncStatusProvider.notifier).syncNow();
}

/// Whether "Encrypt backups" is on without a usable backup key (the next
/// backup would stop and ask).
Future<bool> backupEncryptionUnresolved(WidgetRef ref) async {
  if (!ref.read(settingsProvider).encryptBackups) return false;
  try {
    return await ref.read(backupKeyStateProvider.future) !=
        BackupKeyState.present;
  } on Object {
    return true;
  }
}

enum _EncryptionChoice { pin, plain }

/// Asks how backups should be protected. True when resolved (a backup PIN
/// was set, or encryption was turned off on purpose).
Future<bool> resolveBackupEncryption(
  BuildContext context,
  WidgetRef ref,
) async {
  final choice = await showFFBottomSheet<_EncryptionChoice>(
    context,
    builder: (_) => const _EncryptionChoiceSheet(),
  );
  if (choice == null || !context.mounted) return false;
  final actions = ref.read(backupActionsProvider);
  try {
    switch (choice) {
      case _EncryptionChoice.pin:
        final pin = await showBackupPinSheet(
          context,
          title: tr('Set a backup PIN'),
          message: kBackupPinMessage,
          confirm: true,
        );
        if (pin == null) return false;
        await actions.enableEncryption(pin);
      case _EncryptionChoice.plain:
        await actions.backUpWithoutEncryption();
    }
    return true;
  } on Object {
    if (context.mounted) {
      showFFToast(
        context,
        tr("Couldn't save the backup PIN on this device. Try again."),
        icon: FontAwesomeIcons.triangleExclamation,
      );
    }
    return false;
  }
}

class _EncryptionChoiceSheet extends StatelessWidget {
  const _EncryptionChoiceSheet();

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FFIconTile.soft(
            icon: FontAwesomeIcons.lock,
            colors: ModuleStyle.vault.colors,
            size: AppSizes.iconTileLg,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(tr('Protect your backups'), style: text.title),
        const SizedBox(height: AppSpacing.sm),
        Text(
          tr(
            '"Encrypt backups" is on, but no backup PIN is set on this device yet. Set one to encrypt your backups, or back up without encryption.',
          ),
          style: text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xl),
        FFPrimaryButton(
          label: tr('Set a backup PIN'),
          icon: FontAwesomeIcons.lock,
          onPressed: () => Navigator.of(context).pop(_EncryptionChoice.pin),
        ),
        const SizedBox(height: AppSpacing.sm),
        FFSecondaryButton(
          label: tr('Back up without encryption'),
          onPressed: () => Navigator.of(context).pop(_EncryptionChoice.plain),
        ),
      ],
    );
  }
}

/// Shown on Backup & Sync while "Encrypt backups" is on without a usable
/// backup key.
class BackupEncryptionBanner extends ConsumerWidget {
  const BackupEncryptionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(settingsProvider.select((s) => s.encryptBackups));
    final exists = ref.watch(backupKeyExistsProvider).valueOrNull;
    if (!on || exists != false) return const SizedBox.shrink();
    final unreadable =
        ref.watch(backupKeyStateProvider).valueOrNull ==
        BackupKeyState.unreadable;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
      child: FFInfoBanner.danger(
        icon: FontAwesomeIcons.lock,
        text: unreadable
            ? tr(
                'Your backup PIN couldn\'t be read on this device, so backups are paused. Set it again to keep backing up.',
              )
            : tr(
                'Backups are paused: "Encrypt backups" is on but no backup PIN is set.',
              ),
        actionLabel: tr('Fix'),
        onAction: () => resolveBackupEncryption(context, ref),
      ),
    );
  }
}

enum _MergeChoice { restore, merge, fresh }

/// Shown on Backup & Sync while the sign-in "Restore / Start fresh"
/// choice is outstanding (other devices' backups are not merged).
class MergeDecisionBanner extends ConsumerWidget {
  const MergeDecisionBanner({super.key});

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final choice = await showFFBottomSheet<_MergeChoice>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tr('Backups from other devices'), style: ctx.text.title),
          const SizedBox(height: AppSpacing.sm),
          Text(
            tr(
              'Your Drive has backups made before this device was set up (after a reinstall, your own old ones too). Restore one, merge them automatically, or start fresh and keep them only for a manual restore.',
            ),
            style: ctx.text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          FFPrimaryButton(
            label: tr('Restore…'),
            icon: FontAwesomeIcons.clockRotateLeft,
            onPressed: () => Navigator.of(ctx).pop(_MergeChoice.restore),
          ),
          const SizedBox(height: AppSpacing.sm),
          FFSecondaryButton(
            label: tr('Merge automatically'),
            onPressed: () => Navigator.of(ctx).pop(_MergeChoice.merge),
          ),
          const SizedBox(height: AppSpacing.sm),
          FFSecondaryButton(
            label: tr('Start fresh'),
            onPressed: () => Navigator.of(ctx).pop(_MergeChoice.fresh),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    final actions = ref.read(backupActionsProvider);
    try {
      switch (choice) {
        case _MergeChoice.restore:
          await context.push(AppRoutes.settingsBackupRestore);
        case _MergeChoice.merge:
          await actions.resumeMerging();
        case _MergeChoice.fresh:
          await actions.startFresh();
      }
    } on Object {
      if (context.mounted) {
        showFFToast(
          context,
          tr("Couldn't reach Google Drive. Try again when online."),
          icon: FontAwesomeIcons.triangleExclamation,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(mergeDecisionPendingProvider)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
      child: FFInfoBanner(
        icon: FontAwesomeIcons.cloudArrowDown,
        text: tr(
          'Backups from your other devices aren\'t merged until you choose what to do with them.',
        ),
        actionLabel: tr('Choose'),
        onAction: () => _choose(context, ref),
      ),
    );
  }
}
