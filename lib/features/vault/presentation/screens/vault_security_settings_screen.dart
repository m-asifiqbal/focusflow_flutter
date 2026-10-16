/// ============================================================
/// VAULT SECURITY SETTINGS — Settings › Vault security (screen 33)
/// ============================================================
///
/// What: "‹ Settings | Vault Security" nav bar over the zero-knowledge
/// hero and the UNLOCK · PROTECTION · AUTOFILL · RECOVERY cards (+ the
/// "by design" footnote). Before a vault exists only the hero and a
/// "Set up vault" call to action are shown.
/// Why: these options weaken or strengthen the vault, so every change is
/// confirmed with the PIN / biometrics first (see the sections); the
/// values are plain settings that the vault session, clipboard and
/// screen guard watch live.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/state/vault_session_state.dart';
import 'package:focusflow/features/vault/presentation/widgets/settings/vault_settings_cards.dart';
import 'package:focusflow/features/vault/presentation/widgets/settings/vault_settings_sections.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

class VaultSecuritySettingsScreen extends ConsumerWidget {
  const VaultSecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(vaultSessionProvider.select((s) => s.phase));
    final List<Widget> body = switch (phase) {
      VaultPhase.loading => const [
        SizedBox(height: AppSpacing.section),
        FFSkeleton(height: VaultSizes.skeletonCard, radius: AppRadii.card),
        SizedBox(height: AppSpacing.section),
        FFSkeleton(height: VaultSizes.skeletonCardLg, radius: AppRadii.card),
      ],
      VaultPhase.notSetUp => const [
        SizedBox(height: AppSpacing.section),
        VaultSetUpCard(),
      ],
      // Damaged key: no settings to change — the vault screen offers the
      // recovery code / erase.
      VaultPhase.unreadable => const [
        SizedBox(height: AppSpacing.section),
        VaultUnreadableCard(),
      ],
      _ => const [
        SizedBox(height: AppSpacing.section),
        VaultUnlockSection(),
        SizedBox(height: AppSpacing.section),
        VaultProtectionSection(),
        SizedBox(height: AppSpacing.section),
        VaultAutofillSection(),
        SizedBox(height: AppSpacing.section),
        VaultRecoverySection(),
      ],
    };
    // Activity here counts for the vault's idle auto-lock, as in the vault.
    return Listener(
      onPointerDown: (_) => ref.read(vaultSessionProvider.notifier).touch(),
      child: FFScaffold(
        body: Column(
          children: [
            const FFNavHeader(
              leading: FFBackButton(label: 'Settings'),
              title: 'Vault Security',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.grouped,
                  AppSpacing.xs,
                  AppSpacing.grouped,
                  AppSpacing.xxl,
                ),
                children: [const VaultEncryptionHero(), ...body],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
