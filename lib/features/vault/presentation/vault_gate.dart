/// ============================================================
/// VAULT GATE — cross-feature contract (implemented by the vault feature)
/// ============================================================
///
/// Anything outside the vault that needs the vault key — Quick Add ›
/// Password, opening a vault search result, locking/unlocking a note with
/// the Vault PIN, restoring a vault item from Archive — calls
/// [ensureVaultUnlocked] first. It returns true when the vault session is
/// (or becomes) unlocked, false if the user cancels or no vault exists yet.
///
/// [vaultStatusProvider] is live: it flips when the vault locks (timer,
/// background, manual) or unlocks.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/state/vault_session_state.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_unlock_sheet.dart';
import 'package:go_router/go_router.dart';

export 'package:focusflow/features/vault/presentation/state/vault_session_state.dart'
    show VaultStatus;

/// Vault session status shown outside the vault (Library tile "Locked" /
/// "Unlocked", Search "unlock to view", Home).
final vaultStatusProvider = Provider<VaultStatus>(
  (ref) => ref.watch(vaultSessionProvider.select((s) => s.status)),
);

/// Makes sure the vault is unlocked: already open → true; biometrics
/// enabled → system prompt; otherwise the unlock sheet (PIN pad). Returns
/// false when the user cancels, or — with no vault yet — after pointing
/// them at the vault's first-run set-up.
Future<bool> ensureVaultUnlocked(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final session = container.read(vaultSessionProvider.notifier);
  await session.ready;
  final state = container.read(vaultSessionProvider);
  if (state.isUnlocked) {
    session.touch();
    return true;
  }
  if (state.phase != VaultPhase.notSetUp && state.biometricsReady) {
    final result = await session.unlockWithBiometrics();
    if (result == UnlockResult.success) return true;
  }
  if (!context.mounted) return false;
  final notSetUp = state.phase == VaultPhase.notSetUp;
  if (!notSetUp) return showVaultUnlockSheet(context);
  showUndoSnackbar(
    context,
    message: tr('Set up your vault first'),
    icon: FontAwesomeIcons.shieldHalved,
    undoLabel: tr('OPEN VAULT'),
    onUndo: () {
      if (context.mounted) unawaited(context.push(AppRoutes.vault));
    },
  );
  return false;
}
