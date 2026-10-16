/// ============================================================
/// APP LOCK SETTINGS — Settings › App lock (`/settings/app-lock`)
/// ============================================================
///
/// What: hero ("Lock FocusFlow") · APP LOCK — "Require Face ID" switch
/// (biometric name from the device; passcode fallback) · PRIVACY — "Hide
/// content in app switcher" · VAULT — link to Vault security (the vault
/// keeps its own PIN on top of App lock).
/// Why: the switch goes through [AppLockController.setEnabled], which asks
/// the OS first, so nobody can lock themselves out or turn the lock off
/// on a borrowed phone. AppLockGate reads the same settings live.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/settings/domain/services/device_authenticator.dart';
import 'package:focusflow/features/settings/presentation/notifiers/settings_editor.dart';
import 'package:focusflow/features/settings/presentation/providers/app_lock_providers.dart';
import 'package:focusflow/features/settings/presentation/settings_style.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_sections.dart';
import 'package:focusflow/features/settings/presentation/widgets/settings_hero.dart';
import 'package:focusflow/features/settings/presentation/widgets/settings_page.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

class AppLockSettingsScreen extends ConsumerWidget {
  const AppLockSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final kind =
        ref.watch(appLockBiometricProvider).valueOrNull ?? BiometricKind.none;
    final busy = ref.watch(
      appLockControllerProvider.select((l) => l.authenticating),
    );
    final method = kind == BiometricKind.none
        ? 'device passcode'
        : '${kind.label} or passcode';
    final grace = AppLockController.grace.inSeconds;

    return SettingsPage(
      title: 'App lock',
      children: [
        SettingsHero(
          icon: FontAwesomeIcons.shieldHalved,
          title: 'Lock ${AppInfo.name}',
          body:
              'Ask for your $method whenever ${AppInfo.name} opens. '
              'Your data stays encrypted on this device either way.',
        ),
        FFGroupedList(
          label: 'App lock',
          footer:
              'Locks on launch and after $grace seconds in the background. '
              'Uses the screen lock you already have — ${AppInfo.name} never '
              'sees it.',
          children: [
            FFListRow.toggle(
              leading: settingsTile(
                kind == BiometricKind.faceId || kind == BiometricKind.face
                    ? FontAwesomeIcons.solidFaceSmile
                    : kind == BiometricKind.none
                    ? FontAwesomeIcons.lock
                    : FontAwesomeIcons.fingerprint,
                SettingsTints.emeraldDeep,
              ),
              title: kind == BiometricKind.none
                  ? 'Require passcode'
                  : 'Require ${kind.label}',
              value: s.appLockEnabled,
              enabled: !busy,
              onChanged: (on) => _toggle(context, ref, on),
            ),
          ],
        ),
        FFGroupedList(
          label: 'Privacy',
          footer:
              'Shows a blank screen in the app switcher. On Android this '
              'also blocks screenshots.',
          children: [
            FFListRow.toggle(
              leading: settingsTile(
                FontAwesomeIcons.solidEyeSlash,
                SettingsTints.slateDeep,
              ),
              title: 'Hide content in app switcher',
              value: s.hideInAppSwitcher,
              onChanged: ref.read(settingsEditorProvider).setHideInAppSwitcher,
            ),
          ],
        ),
        FFGroupedList(
          label: 'Vault',
          children: [
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.shieldHalved,
                SettingsTints.amber,
              ),
              title: 'Vault security',
              subtitle: 'The vault keeps its own PIN on top of App lock',
              onTap: () => context.push(AppRoutes.settingsVaultSecurity),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool on) async {
    final result = await ref
        .read(appLockControllerProvider.notifier)
        .setEnabled(on);
    if (!context.mounted) return;
    final text = switch (result) {
      DeviceAuthResult.success => on ? 'App lock is on' : 'App lock is off',
      DeviceAuthResult.unavailable =>
        'Set up a screen lock on this device first',
      DeviceAuthResult.lockedOut =>
        'Too many attempts. Unlock your device, then try again.',
      DeviceAuthResult.cancelled => null,
      DeviceAuthResult.failed => 'Couldn’t verify it’s you',
    };
    if (text != null) {
      showFFToast(
        context,
        text,
        icon: on ? FontAwesomeIcons.lock : FontAwesomeIcons.lockOpen,
      );
    }
  }
}
