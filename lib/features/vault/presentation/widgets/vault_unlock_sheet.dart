/// ============================================================
/// VAULT UNLOCK SHEET — the PIN pad as a dark bottom sheet
/// ============================================================
///
/// Used by ensureVaultUnlocked() from anywhere outside the vault (Quick
/// Add › Password, a vault search result, locking a note, restoring a vault
/// item). Reuses the lock card's content (biometrics button, dots, pad,
/// "Forgot PIN?") and closes itself with `true` as soon as the session
/// unlocks; dismissing it returns false.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_lock_card.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_screen_guard.dart';

/// Shows the unlock sheet; true when the vault is unlocked afterwards.
Future<bool> showVaultUnlockSheet(BuildContext context) async {
  final result = await showFFBottomSheet<bool>(
    context,
    vault: true,
    builder: (_) =>
        const VaultTheme(child: VaultScreenGuard(child: _UnlockSheet())),
  );
  return result ?? false;
}

class _UnlockSheet extends ConsumerWidget {
  const _UnlockSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(vaultSessionProvider.select((s) => s.isUnlocked), (_, open) {
      if (open && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    });
    return const Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.lg,
      ),
      child: VaultLockCard(framed: false, autoPrompt: false),
    );
  }
}
