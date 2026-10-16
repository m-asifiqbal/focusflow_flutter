/// ============================================================
/// VAULT UNREADABLE — the key bundle is damaged / missing (screen 17 error)
/// ============================================================
///
/// Shown instead of the PIN pad when VaultSessionController reports
/// [VaultPhase.unreadable]: a key bundle is stored but cannot be parsed,
/// or vault items exist without any key. Offering "Create master PIN"
/// here would silently orphan every encrypted item, so the only ways on
/// are:
///  * "Unlock with recovery code" — opens the data key from the Recovery
///    Kit; the forced new PIN then writes a fresh, readable key bundle;
///  * restoring a backup (Settings › Backup & sync);
///  * "Erase vault" — only after typing ERASE; deletes every vault item and
///    key on this device (not the backups).
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_recovery_dialogs.dart';

/// The word to type before the vault is erased.
const String vaultEraseWord = 'ERASE';

class VaultUnreadableView extends ConsumerWidget {
  const VaultUnreadableView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    return ListView(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        MediaQuery.paddingOf(context).top + AppSpacing.xxl,
        AppSpacing.screen,
        MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
      ),
      children: [
        Icon(
          FontAwesomeIcons.triangleExclamation,
          size: VaultSizes.lockGlyph,
          color: ff.vaultAccent,
        ),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          header: true,
          child: Text(
            "Your vault key can't be read",
            textAlign: TextAlign.center,
            style: context.text.title.copyWith(color: ff.vaultInk),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Your encrypted items are still here, but the key that opens them '
          'is damaged or missing on this device. Unlock with your Recovery '
          'Kit code to repair it, or restore a backup from Settings › '
          'Backup & sync. Contact support if you need help.',
          textAlign: TextAlign.center,
          style: context.text.body.copyWith(color: ff.vaultInkMuted),
        ),
        const SizedBox(height: AppSpacing.xxl),
        FFPrimaryButton(
          label: 'Unlock with recovery code',
          icon: FontAwesomeIcons.key,
          onPressed: () => unawaited(showVaultRecoveryDialog(context)),
        ),
        const SizedBox(height: AppSpacing.md),
        FFTextButton(
          label: 'Erase vault and start over',
          color: ff.vaultInkMuted,
          onPressed: () => unawaited(_erase(context, ref)),
        ),
      ],
    );
  }

  Future<void> _erase(BuildContext context, WidgetRef ref) async {
    final ok = await showFFDialog<bool>(
      context,
      builder: (_) => const VaultEraseDialog(),
    );
    if (ok != true) return;
    await ref.read(vaultSessionProvider.notifier).wipe();
    if (context.mounted) showFFToast(context, 'Vault erased on this device');
  }
}

/// "Type ERASE to confirm". Pops `true` only for the exact word.
class VaultEraseDialog extends StatefulWidget {
  const VaultEraseDialog({super.key});

  @override
  State<VaultEraseDialog> createState() => _VaultEraseDialogState();
}

class _VaultEraseDialogState extends State<VaultEraseDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _matches => _c.text.trim() == vaultEraseWord;

  @override
  Widget build(BuildContext context) => FFDialog(
    icon: FontAwesomeIcons.trashCan,
    title: 'Erase the vault?',
    message:
        'Every vault item and its key are deleted from this device. This '
        'cannot be undone. Backups are not touched. Type $vaultEraseWord to '
        'confirm.',
    content: TextField(
      controller: _c,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      textCapitalization: TextCapitalization.characters,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(hintText: vaultEraseWord),
    ),
    actions: [
      FFPrimaryButton(
        label: 'Erase vault',
        onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
      ),
      FFTextButton(
        label: 'Cancel',
        onPressed: () => Navigator.of(context).pop(false),
      ),
    ],
  );
}
