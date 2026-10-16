/// ============================================================
/// VAULT RECOVERY DIALOGS — "Forgot PIN?" and the first-run follow-up
/// ============================================================
///
/// * [showVaultRecoveryDialog] — unlock with the Recovery Kit code, then
///   FORCE a new PIN and offer a new recovery code (vault_new_pin_panel).
/// * [showVaultSetupDoneSheet] — after the master PIN is created (17,
///   first run): turn on Face ID / fingerprint and create the recovery code
///   (shown once as non-selectable text — "Copy code" uses the secure,
///   auto-clearing clipboard; "download recovery kit" lives in Vault
///   security, screen 33).
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/crypto/biometric_auth.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/features/vault/presentation/state/vault_session_state.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_new_pin_panel.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

/// Recovery-code unlock. Returns true when the vault was opened.
Future<bool> showVaultRecoveryDialog(BuildContext context) async {
  // The caller (lock card in the unlock sheet) may close as soon as the
  // vault unlocks: keep the root navigator for the follow-up sheet.
  final root = Navigator.of(context, rootNavigator: true);
  final ok = await showFFDialog<bool>(
    context,
    builder: (_) => const _RecoveryDialog(),
  );
  if (ok != true || !root.mounted) return false;
  await showVaultNewPinSheet(root.context);
  return true;
}

class _RecoveryDialog extends ConsumerStatefulWidget {
  const _RecoveryDialog();

  @override
  ConsumerState<_RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends ConsumerState<_RecoveryDialog> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _code.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(vaultSessionProvider.notifier)
        .unlockWithRecoveryCode(_code.text.trim());
    if (!mounted) return;
    if (result == UnlockResult.success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = "That code doesn't match this vault";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return FFDialog(
      icon: FontAwesomeIcons.key,
      title: 'Forgot your PIN?',
      message:
          'Enter the recovery code from your Recovery Kit. Without it, '
          'a forgotten PIN cannot be reset.',
      content: TextField(
        controller: _code,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        keyboardType: TextInputType.visiblePassword,
        textCapitalization: TextCapitalization.characters,
        onSubmitted: (_) => _submit(),
        style: context.text.mono.copyWith(color: ff.ink),
        decoration: InputDecoration(
          hintText: 'XXXX-XXXX-XXXX-XXXX',
          errorText: _error,
        ),
      ),
      actions: [
        FFPrimaryButton(label: 'Unlock', loading: _busy, onPressed: _submit),
        FFTextButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}

/// First-run follow-up sheet (biometrics + recovery code).
Future<void> showVaultSetupDoneSheet(BuildContext context) =>
    showFFBottomSheet<void>(
      context,
      vault: true,
      builder: (_) => const _SetupDoneSheet(),
    );

class _SetupDoneSheet extends ConsumerStatefulWidget {
  const _SetupDoneSheet();

  @override
  ConsumerState<_SetupDoneSheet> createState() => _SetupDoneSheetState();
}

class _SetupDoneSheetState extends ConsumerState<_SetupDoneSheet> {
  String? _code;
  bool _busy = false;

  Future<void> _createCode() async {
    setState(() => _busy = true);
    try {
      final code = await ref
          .read(vaultSessionProvider.notifier)
          .createRecoveryCode();
      if (mounted) setState(() => _code = code);
    } on Object {
      if (mounted) showFFToast(context, "Couldn't create a recovery code");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final session = ref.watch(vaultSessionProvider);
    final bioOn = ref.watch(settingsProvider.select((s) => s.vaultBiometrics));
    final kind = session.biometricKind;
    final bioName = kind == BiometricKind.face ? 'Face ID' : 'fingerprint';
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        AppSpacing.sm,
        AppSpacing.screen,
        AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your vault is ready',
            style: context.text.title.copyWith(color: ff.vaultInk),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Everything you save here is encrypted with your master PIN.',
            style: context.text.bodySmall.copyWith(color: ff.vaultInkMuted),
          ),
          if (kind != BiometricKind.none) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Unlock with $bioName',
                    style: context.text.rowTitle.copyWith(color: ff.vaultInk),
                  ),
                ),
                FFSwitch(
                  value: bioOn,
                  vault: true,
                  semanticLabel: 'Unlock with $bioName',
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .update((s) => s.copyWith(vaultBiometrics: v)),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (_code == null)
            FFSecondaryButton(
              label: 'Create recovery code',
              icon: FontAwesomeIcons.key,
              onPressed: _busy ? null : _createCode,
            )
          else ...[
            Text(
              'Write this code down and keep it somewhere safe. It is the '
              'only way back in if you forget your PIN.',
              style: context.text.bodySmall.copyWith(color: ff.vaultInkMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            // Not selectable: a system copy would skip the auto-clear.
            Text(
              _code!,
              textAlign: TextAlign.center,
              style: context.text.mono.copyWith(
                fontSize: VaultType.nav,
                color: ff.vaultAccent,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FFSecondaryButton(
              label: 'Copy code',
              icon: FontAwesomeIcons.solidCopy,
              onPressed: () async {
                await ref
                    .read(secureClipboardProvider)
                    .copy(_code!, clearAfter: const Duration(seconds: 60));
                if (context.mounted) {
                  showFFToast(context, 'Recovery code copied · clears in 60s');
                }
              },
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          FFPrimaryButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
