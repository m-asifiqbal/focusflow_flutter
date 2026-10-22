/// ============================================================
/// VAULT SETTINGS CARDS — hero, AUTOFILL, RECOVERY, set-up CTA (33)
/// ============================================================
///
/// * [VaultEncryptionHero] — dark emerald "Zero-knowledge encryption"
///   card (AES-256-GCM · Argon2id) with the shield tile.
/// * [VaultAutofillSection] — "Use FocusFlow for autofill" (the Android
///   Autofill Service / iOS AutoFill extension ship in v1.1; "Set up"
///   explains that for now).
/// * [VaultRecoverySection] — Recovery kit (PDF) → re-auth → new code →
///   PDF → share sheet; Export vault (encrypted) → re-auth → Import &
///   export (the backup lane's encrypted export); the "by design" footnote.
/// * [VaultSetUpCard] — shown instead of the options before a vault exists.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_security_settings_controller.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/settings/vault_settings_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_reauth_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

class VaultEncryptionHero extends StatelessWidget {
  const VaultEncryptionHero({super.key});

  /// Shield tile (measured from the mockup: 56 pt, radius 16).
  static const double _tile = 56;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: ff.vaultCanvas,
          borderRadius: BorderRadius.circular(AppRadii.sheet),
        ),
        child: Row(
          children: [
            Container(
              width: _tile,
              height: _tile,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ff.vaultAccent,
                borderRadius: BorderRadius.circular(_tile * 0.3),
              ),
              child: Icon(
                FontAwesomeIcons.shieldHalved,
                size: VaultSizes.iconXxl,
                color: ff.vaultOnAccentInk,
              ),
            ),
            const SizedBox(width: AppSpacing.lg + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Zero-knowledge encryption'),
                    style: context.text.title.copyWith(
                      fontSize: VaultType.valueLg,
                      fontWeight: FontWeight.w600,
                      color: ff.vaultInk,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    tr(
                      'AES-256-GCM · key derived with Argon2id. We can never see your passwords.',
                    ),
                    style: context.text.meta.copyWith(
                      fontSize: VaultType.secondary,
                      height: 1.4,
                      color: ff.vaultInk.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VaultAutofillSection extends StatelessWidget {
  const VaultAutofillSection({super.key});

  @override
  Widget build(BuildContext context) => FFGroupedList(
    label: tr('AUTOFILL'),
    children: [
      FFListRow(
        leading: const VaultSettingsTile(
          FontAwesomeIcons.solidKeyboard,
          VaultSettingsTints.blue,
        ),
        title: tr('Use {name} for autofill', {'name': AppInfo.name}),
        subtitle: tr('Android Autofill Service · iOS Password AutoFill'),
        value: tr('Set up'),
        onTap: () => showFFToast(
          context,
          tr(
            'Autofill arrives in version 1.1 · copy from the vault until then',
          ),
        ),
      ),
    ],
  );
}

class VaultRecoverySection extends ConsumerWidget {
  const VaultRecoverySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => FFGroupedList(
    label: tr('RECOVERY'),
    footer: tr(
      'If you forget your master PIN and lose your recovery kit, vault data cannot be recovered — by design.',
    ),
    children: [
      FFListRow(
        leading: const VaultSettingsTile(
          FontAwesomeIcons.fileShield,
          VaultSettingsTints.emerald,
        ),
        title: tr('Recovery kit (PDF)'),
        value: tr('Download'),
        onTap: () => unawaited(_recoveryKit(context, ref)),
      ),
      FFListRow(
        leading: const VaultSettingsTile(
          FontAwesomeIcons.fileExport,
          VaultSettingsTints.amber,
        ),
        title: tr('Export vault (encrypted)'),
        onTap: () => runWithVaultReauth(
          context,
          ref,
          tr('Confirm to export your vault'),
          () async {
            if (context.mounted) {
              unawaited(context.push(AppRoutes.settingsImportExport));
            }
          },
        ),
      ),
    ],
  );

  Future<void> _recoveryKit(BuildContext context, WidgetRef ref) async {
    final ok = await showFFConfirm(
      context,
      title: tr('Create a new recovery kit?'),
      message: tr(
        'You will save a new recovery code. Once you confirm it is saved, any kit you saved before stops working.',
      ),
      confirmLabel: tr('Create kit'),
    );
    if (!ok || !context.mounted) return;
    await withVaultReauth(
      context,
      ref,
      tr('Confirm to create a recovery kit'),
      () async {
        final c = ref.read(vaultSecuritySettingsControllerProvider);
        try {
          // Phase 1: new code → PDF → share sheet. The old code still works.
          if (!await c.shareRecoveryKit()) {
            c.discardRecoveryKit();
            if (context.mounted) {
              showFFToast(
                context,
                tr('Not saved · your old recovery kit still works'),
              );
            }
            return;
          }
          if (!context.mounted) {
            c.discardRecoveryKit();
            return;
          }
          // Phase 2: only now does the new code replace the old one.
          final saved = await showFFConfirm(
            context,
            title: tr('Did you save the new kit?'),
            message: tr(
              'Confirm only after the PDF is stored or printed. Your old recovery code stops working when you confirm.',
            ),
            confirmLabel: tr('Yes, it is saved'),
            cancelLabel: tr('Not yet'),
          );
          if (saved) {
            await c.commitRecoveryKit();
            if (context.mounted) {
              showFFToast(context, tr('New recovery kit active'));
            }
          } else {
            c.discardRecoveryKit();
            if (context.mounted) {
              showFFToast(context, tr('Your old recovery kit still works'));
            }
          }
        } on Object {
          c.discardRecoveryKit();
          if (context.mounted) {
            showFFToast(context, tr("Couldn't create the recovery kit"));
          }
        }
      },
      needsKey: true,
    );
  }
}

class VaultSetUpCard extends StatelessWidget {
  const VaultSetUpCard({super.key});

  @override
  Widget build(BuildContext context) => FFEmptyState.compact(
    colors: ModuleStyle.vault.colors,
    icon: FontAwesomeIcons.shieldHalved,
    title: tr('Set up your vault'),
    body: tr(
      'Choose a master PIN to start storing passwords. These options appear once the vault exists.',
    ),
    ctaLabel: tr('Set up vault'),
    ctaIcon: FontAwesomeIcons.lock,
    onCta: () => unawaited(context.push(AppRoutes.vault)),
  );
}

/// Key bundle damaged / missing: point at the vault's recovery screen.
class VaultUnreadableCard extends StatelessWidget {
  const VaultUnreadableCard({super.key});

  @override
  Widget build(BuildContext context) => FFEmptyState.compact(
    colors: ModuleStyle.vault.colors,
    icon: FontAwesomeIcons.triangleExclamation,
    title: tr('Your vault key can\'t be read'),
    body: tr(
      'Open the vault to unlock it with your recovery code, or restore a backup.',
    ),
    ctaLabel: tr('Open vault'),
    ctaIcon: FontAwesomeIcons.key,
    onCta: () => unawaited(context.push(AppRoutes.vault)),
  );
}
