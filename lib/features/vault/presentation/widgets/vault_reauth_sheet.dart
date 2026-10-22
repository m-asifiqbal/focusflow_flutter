/// ============================================================
/// VAULT RE-AUTH SHEET — "Confirm it's you" / "Change master PIN"
/// ============================================================
///
/// Every change on Settings › Vault security asks for the current PIN or
/// biometrics first ([vaultReauthenticate]). The sheet is the dark PIN pad
/// ([VaultPinDots] / [VaultPadStatusLine] / [VaultKeypad]) driven by
/// [vaultPinPadProvider] in its re-auth steps: the PIN is checked without
/// unlocking (same back-off / optional wipe as the lock screen); for
/// "Change master PIN" it then collects and confirms the new PIN and
/// re-wraps the data key (items are not re-encrypted). Closes with `true`
/// on success. The digits never leave the controller; nothing is logged.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_pin_pad_controller.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/features/vault/presentation/state/vault_session_state.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_pin_pad.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_screen_guard.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Confirms the user before a Vault security change: biometrics when
/// they are enabled and enrolled, otherwise (or when cancelled) the PIN
/// sheet. With [needsKey] (enable biometrics, Recovery Kit, change PIN)
/// a locked vault is unlocked instead — entering the PIN is the re-auth.
/// False when there is no vault or the user cancels.
Future<bool> vaultReauthenticate(
  BuildContext context,
  WidgetRef ref, {
  required String reason,
  bool needsKey = false,
}) async {
  final session = ref.read(vaultSessionProvider.notifier);
  await session.ready;
  final s = ref.read(vaultSessionProvider);
  if (s.phase == VaultPhase.notSetUp || s.phase == VaultPhase.loading) {
    return false;
  }
  if (!context.mounted) return false;
  if (needsKey && !s.isUnlocked) return ensureVaultUnlocked(context);
  if (s.biometricsReady && ref.read(settingsProvider).vaultBiometrics) {
    try {
      if (await ref.read(biometricAuthProvider).authenticate(reason)) {
        return true;
      }
    } on Object {
      // Fall back to the PIN.
    }
  }
  if (!context.mounted) return false;
  return showVaultReauthSheet(context);
}

/// Gate before showing a secret when Settings › "Ask for PIN to reveal
/// passwords" is on: biometrics if enabled and enrolled, otherwise the PIN
/// sheet (never silently skipped). True when revealing may go ahead.
Future<bool> confirmVaultReveal(BuildContext context, WidgetRef ref) async {
  if (!ref.read(settingsProvider).vaultReauthToReveal) return true;
  final session = ref.read(vaultSessionProvider.notifier)..touch();
  return session.keepUnlockedDuring(
    () => vaultReauthenticate(context, ref, reason: tr('Reveal this secret')),
  );
}

/// The PIN sheet. [changePin]: verify → new PIN → confirm → re-wrap
/// (the vault must be unlocked).
Future<bool> showVaultReauthSheet(
  BuildContext context, {
  bool changePin = false,
}) async {
  final result = await showFFBottomSheet<bool>(
    context,
    vault: true,
    builder: (_) => VaultTheme(
      child: VaultScreenGuard(child: VaultReauthPad(changePin: changePin)),
    ),
  );
  return result ?? false;
}

/// Sheet body (public for tests).
class VaultReauthPad extends ConsumerStatefulWidget {
  const VaultReauthPad({required this.changePin, super.key});

  final bool changePin;

  @override
  ConsumerState<VaultReauthPad> createState() => _VaultReauthPadState();
}

class _VaultReauthPadState extends ConsumerState<VaultReauthPad> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Switching the shared pad's mode is a provider write: not while the
    // tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(vaultPinPadProvider.notifier)
          .startReauth(changePin: widget.changePin);
      setState(() => _ready = true);
    });
  }

  void _close(bool ok) {
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final pad = ref.watch(vaultPinPadProvider);
    ref.listen(vaultPinPadProvider.select((p) => p.done), (_, done) {
      if (done && _ready) _close(true);
    });
    ref.listen(vaultSessionProvider.select((s) => s.phase), (_, phase) {
      if (phase == VaultPhase.notSetUp) _close(false); // wiped
    });
    final step = _ready ? pad.step : VaultPadStep.verify;
    final (title, body) = switch (step) {
      VaultPadStep.changeNew => (
        tr('Choose a new PIN'),
        tr(
          'Your items stay encrypted; only the key that protects them is re-wrapped.',
        ),
      ),
      VaultPadStep.changeConfirm => (
        tr('Confirm new PIN'),
        tr('Enter the same 6 digits again.'),
      ),
      _ when widget.changePin => (
        tr('Change master PIN'),
        tr('Enter your current 6-digit PIN.'),
      ),
      _ => (
        tr("Confirm it's you"),
        tr('Enter your master PIN to change Vault security settings.'),
      ),
    };
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.sectionTitle.copyWith(color: ff.vaultInk),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: context.text.body.copyWith(color: ff.vaultSubtitle),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const VaultPinDots(),
          const SizedBox(height: AppSpacing.md),
          const VaultPadStatusLine(),
          const SizedBox(height: AppSpacing.lg),
          const VaultKeypad(),
          const SizedBox(height: AppSpacing.sm),
          if (step == VaultPadStep.changeConfirm)
            FFTextButton(
              label: tr('Start over'),
              onPressed: () =>
                  ref.read(vaultPinPadProvider.notifier).restartSetup(),
            )
          else
            FFTextButton(label: tr('Cancel'), onPressed: () => _close(false)),
        ],
      ),
    );
  }
}

/// Runs [vaultReauthenticate] and then [action]; a no-op when cancelled.
Future<void> withVaultReauth(
  BuildContext context,
  WidgetRef ref,
  String reason,
  Future<void> Function() action, {
  bool needsKey = false,
}) async {
  if (!await vaultReauthenticate(
    context,
    ref,
    reason: reason,
    needsKey: needsKey,
  )) {
    return;
  }
  await action();
  ref.read(vaultSessionProvider.notifier).touch();
}

/// Fire-and-forget form of [withVaultReauth] for `onChanged` callbacks.
void runWithVaultReauth(
  BuildContext context,
  WidgetRef ref,
  String reason,
  Future<void> Function() action, {
  bool needsKey = false,
}) => unawaited(
  withVaultReauth(context, ref, reason, action, needsKey: needsKey),
);
