/// ============================================================
/// VAULT SCREEN — `/library/vault`: lock gate (17) + inner tabs (18, 21, 22)
/// ============================================================
///
/// Always-dark secure mode (VaultTheme), screenshots blocked per setting,
/// and every pointer-down inside counts as activity for the auto-lock
/// timer. Locked / not set up → screen 17 (PIN pad); unlocked → the
/// selected inner tab. The first successful set-up opens the follow-up
/// sheet (biometrics + recovery code). An unreadable key → the recovery /
/// erase screen (never set-up); a recovery-code unlock whose new PIN was
/// not chosen yet → "Set a new PIN" before any item is shown.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/screens/vault_generator_view.dart';
import 'package:focusflow/features/vault/presentation/screens/vault_list_view.dart';
import 'package:focusflow/features/vault/presentation/screens/vault_locked_view.dart';
import 'package:focusflow/features/vault/presentation/screens/vault_security_view.dart';
import 'package:focusflow/features/vault/presentation/screens/vault_unreadable_view.dart';
import 'package:focusflow/features/vault/presentation/state/vault_session_state.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_new_pin_panel.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_recovery_dialogs.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_screen_guard.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_tab_bar.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const VaultTheme(child: VaultScreenGuard(child: _VaultShell()));
}

/// Below the vault theme, so sheets opened from here are dark too.
class _VaultShell extends ConsumerWidget {
  const _VaultShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(vaultSessionProvider.select((s) => s.phase));
    final pinReset = ref.watch(
      vaultSessionProvider.select((s) => s.pinResetRequired),
    );
    final tab = ref.watch(vaultTabProvider);
    ref.listen(vaultSessionProvider.select((s) => s.phase), (prev, next) {
      if (prev == VaultPhase.notSetUp && next == VaultPhase.unlocked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) unawaited(showVaultSetupDoneSheet(context));
        });
      }
    });

    final Widget body = switch (phase) {
      VaultPhase.unlocked when pinReset => const _FinishRecovery(),
      VaultPhase.unlocked => switch (tab) {
        VaultTab.vault => const VaultListView(),
        VaultTab.favourites => const VaultListView(favouritesTab: true),
        VaultTab.generator => const VaultGeneratorView(),
        VaultTab.security => const VaultSecurityView(),
      },
      VaultPhase.unreadable => const VaultUnreadableView(),
      _ => const VaultLockedView(),
    };

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => ref.read(vaultSessionProvider.notifier).touch(),
      child: FFScaffold(
        vault: true,
        body: KeyedSubtree(
          key: ValueKey(
            phase == VaultPhase.unlocked && !pinReset ? tab : phase,
          ),
          child: body,
        ),
        bottomBar: const VaultTabBar(),
      ),
    );
  }
}

/// Recovery-code unlock without a new PIN yet (the sheet was closed).
class _FinishRecovery extends StatelessWidget {
  const _FinishRecovery();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsetsDirectional.all(AppSpacing.screen),
      child: FFPrimaryButton(
        label: 'Set a new PIN',
        onPressed: () => unawaited(showVaultNewPinSheet(context)),
      ),
    ),
  );
}
