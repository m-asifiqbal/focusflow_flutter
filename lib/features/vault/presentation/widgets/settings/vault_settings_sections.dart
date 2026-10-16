/// ============================================================
/// VAULT SETTINGS SECTIONS — UNLOCK + PROTECTION cards of screen 33
/// ============================================================
///
/// UNLOCK: Face ID / Fingerprint, Change master PIN, Auto-lock vault, Lock
/// when app goes to background. PROTECTION: Clear copied passwords, Block
/// screenshots in Vault, Breach monitoring (k-anonymity), Wipe vault after
/// 10 failed attempts, Ask for PIN to reveal. Every value reads
/// [settingsProvider] live; every change first asks for the PIN or
/// biometrics ([withVaultReauth]) and then writes through
/// [VaultSecuritySettingsController].
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/crypto/pin_attempt_guard.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_security_settings_controller.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';
import 'package:focusflow/features/vault/presentation/widgets/settings/vault_settings_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_reauth_sheet.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

const _reason = 'Confirm to change Vault security settings';

class VaultUnlockSection extends ConsumerWidget {
  const VaultUnlockSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(vaultSecuritySettingsControllerProvider);
    return FFGroupedList(
      label: 'UNLOCK',
      children: [
        FFListRow.toggle(
          leading: const VaultSettingsTile(
            FontAwesomeIcons.solidFaceSmile,
            VaultSettingsTints.emerald,
          ),
          title: 'Face ID / Fingerprint',
          value: s.vaultBiometrics,
          onChanged: (on) => unawaited(_setBiometrics(context, ref, on)),
        ),
        FFListRow(
          leading: const VaultSettingsTile(
            FontAwesomeIcons.key,
            VaultSettingsTints.amber,
          ),
          title: 'Change master PIN',
          value: '6 digits',
          onTap: () => unawaited(_changePin(context)),
        ),
        FFListRow(
          leading: const VaultSettingsTile(
            FontAwesomeIcons.solidHourglassHalf,
            VaultSettingsTints.indigo,
          ),
          title: 'Auto-lock vault',
          value: VaultSettingsLabels.autoLock(s.vaultAutoLockMinutes),
          onTap: () async {
            final v = await showVaultSettingsOptionSheet<int>(
              context,
              title: 'Auto-lock vault',
              subtitle: 'Locks after this long without vault activity',
              selected: s.vaultAutoLockMinutes,
              options: [
                for (final m in VaultSettingsLabels.autoLockMinutes)
                  (m, VaultSettingsLabels.autoLockOption(m)),
              ],
            );
            if (v == null || v == s.vaultAutoLockMinutes) return;
            if (!context.mounted) return;
            await withVaultReauth(
              context,
              ref,
              _reason,
              () => c.setAutoLockMinutes(v),
            );
          },
        ),
        FFListRow.toggle(
          leading: const VaultSettingsTile(
            FontAwesomeIcons.mobileScreenButton,
            VaultSettingsTints.slate,
          ),
          title: 'Lock when app goes to background',
          value: s.vaultLockOnBackground,
          onChanged: (on) => runWithVaultReauth(
            context,
            ref,
            _reason,
            () => c.setLockOnBackground(on),
          ),
        ),
      ],
    );
  }

  Future<void> _setBiometrics(
    BuildContext context,
    WidgetRef ref,
    bool on,
  ) async {
    final c = ref.read(vaultSecuritySettingsControllerProvider);
    if (on && !await c.biometricsAvailable()) {
      if (context.mounted) {
        showFFToast(context, 'Set up Face ID or a fingerprint on this device');
      }
      return;
    }
    if (!context.mounted) return;
    // Turning it on stores the OS-protected biometric copy of the open
    // vault key (the system may ask for the fingerprint / face once).
    await withVaultReauth(context, ref, _reason, () async {
      if (!await c.setBiometrics(on) && context.mounted) {
        showFFToast(
          context,
          "Biometric unlock couldn't be turned on · use your PIN",
        );
      }
    }, needsKey: on);
  }

  Future<void> _changePin(BuildContext context) async {
    // The new PIN re-wraps the open data key: unlock first, then the sheet
    // asks for the current PIN, the new one and its confirmation.
    if (!await ensureVaultUnlocked(context) || !context.mounted) return;
    if (await showVaultReauthSheet(context, changePin: true) &&
        context.mounted) {
      showFFToast(context, 'Master PIN changed');
    }
  }
}

class VaultProtectionSection extends ConsumerWidget {
  const VaultProtectionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(vaultSecuritySettingsControllerProvider);
    return FFGroupedList(
      label: 'PROTECTION',
      children: [
        FFListRow(
          leading: const VaultSettingsTile(
            FontAwesomeIcons.solidPaste,
            VaultSettingsTints.sky,
          ),
          title: 'Clear copied passwords',
          value: VaultSettingsLabels.clipboard(s.clipboardClearSeconds),
          onTap: () async {
            final v = await showVaultSettingsOptionSheet<int>(
              context,
              title: 'Clear copied passwords',
              subtitle: 'Copied secrets are wiped from the clipboard',
              selected: s.clipboardClearSeconds,
              options: [
                for (final sec in VaultSettingsLabels.clipboardSeconds)
                  (sec, VaultSettingsLabels.clipboardOption(sec)),
              ],
            );
            if (v == null || v == s.clipboardClearSeconds) return;
            if (!context.mounted) return;
            await withVaultReauth(
              context,
              ref,
              _reason,
              () => c.setClipboardClearSeconds(v),
            );
          },
        ),
        FFListRow.toggle(
          leading: const VaultSettingsTile(
            FontAwesomeIcons.camera,
            VaultSettingsTints.red,
          ),
          title: 'Block screenshots in Vault',
          value: s.vaultBlockScreenshots,
          onChanged: (on) => runWithVaultReauth(
            context,
            ref,
            _reason,
            () => c.setBlockScreenshots(on),
          ),
        ),
        FFListRow.toggle(
          leading: const VaultSettingsTile(
            FontAwesomeIcons.userSecret,
            VaultSettingsTints.violet,
          ),
          title: 'Breach monitoring',
          subtitle: 'Checks hashed prefixes only (k-anonymity)',
          value: s.breachMonitoring,
          onChanged: (on) => runWithVaultReauth(
            context,
            ref,
            _reason,
            () => c.setBreachMonitoring(on),
          ),
        ),
        FFListRow.toggle(
          leading: const VaultSettingsTile(
            FontAwesomeIcons.triangleExclamation,
            VaultSettingsTints.rose,
          ),
          title:
              'Wipe vault after ${PinAttemptGuard.wipeThreshold} failed '
              'attempts',
          value: s.wipeAfterFailedAttempts,
          onChanged: (on) => runWithVaultReauth(
            context,
            ref,
            _reason,
            () => c.setWipeAfterFailedAttempts(on),
          ),
        ),
        FFListRow.toggle(
          leading: const VaultSettingsTile(
            FontAwesomeIcons.solidEye,
            VaultSettingsTints.teal,
          ),
          title: 'Ask for PIN to reveal passwords',
          value: s.vaultReauthToReveal,
          onChanged: (on) => runWithVaultReauth(
            context,
            ref,
            _reason,
            () => c.setReauthToReveal(on),
          ),
        ),
      ],
    );
  }
}

/// Single-choice sheet (light, app-styled) for the value rows; returns the
/// picked value or null when dismissed.
Future<T?> showVaultSettingsOptionSheet<T>(
  BuildContext context, {
  required String title,
  required T selected,
  required List<(T, String)> options,
  String? subtitle,
}) => showFFBottomSheet<T>(
  context,
  builder: (sheetContext) {
    final ff = sheetContext.ff;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: sheetContext.text.sectionTitle),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: sheetContext.text.meta.copyWith(color: ff.inkMuted),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FFGroupedList(
          children: [
            for (final (value, label) in options)
              Semantics(
                selected: value == selected,
                child: FFListRow(
                  title: label,
                  chevron: false,
                  trailing: value == selected
                      ? Icon(
                          FontAwesomeIcons.check,
                          size: AppSizes.tileGlyph,
                          color: ff.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(value),
                ),
              ),
          ],
        ),
      ],
    );
  },
);
