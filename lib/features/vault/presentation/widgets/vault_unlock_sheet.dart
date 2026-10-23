/// ============================================================
/// VAULT UNLOCK SHEET — the PIN pad as a dark bottom sheet
/// ============================================================
///
/// Used by ensureVaultUnlocked() from anywhere outside the vault (Quick
/// Add › Password, a vault search result, locking a note, restoring a vault
/// item, enabling biometrics in Settings). Reuses the lock card's content
/// (biometrics button, dots, pad, "Forgot PIN?") and closes itself with
/// `true` as soon as the session unlocks; dismissing it returns false.
///
/// The PIN pad is shared: on open the sheet puts it back to "enter master
/// PIN" (a re-auth sheet still animating out could otherwise leave it
/// finished, ignoring every digit), and it closes only its own route, once.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_pin_pad_controller.dart';
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

class _UnlockSheet extends ConsumerStatefulWidget {
  const _UnlockSheet();

  @override
  ConsumerState<_UnlockSheet> createState() => _UnlockSheetState();
}

class _UnlockSheetState extends ConsumerState<_UnlockSheet> {
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    // A provider write: not while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(vaultPinPadProvider.notifier).startUnlock();
    });
  }

  void _close() {
    if (_closed || !mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    _closed = true;
    if (route.isCurrent) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).removeRoute(route, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(vaultSessionProvider.select((s) => s.isUnlocked), (_, open) {
      if (open) _close();
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
