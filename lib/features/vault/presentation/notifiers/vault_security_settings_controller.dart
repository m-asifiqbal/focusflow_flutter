/// ============================================================
/// VAULT SECURITY SETTINGS CONTROLLER — writes of screen 33
/// ============================================================
///
/// Typed setters over [settingsProvider] for Settings › Vault security
/// (the session, clipboard, screen guard and breach scanner all watch the
/// settings, so a change applies immediately) and the two-phase Recovery
/// Kit flow: a PREPARED recovery code → PDF → share sheet (vault kept open
/// while the sheet backgrounds the app) → the screen asks whether the kit
/// was saved → [commitRecoveryKit] replaces the old code, or
/// [discardRecoveryKit] keeps it. Turning biometrics on first writes the
/// OS-protected key copy and only then flips the setting. The
/// re-auth before each call is the screen's job (vaultReauthenticate);
/// nothing here logs.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/features/vault/data/datasource/recovery_kit_pdf.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class VaultSecuritySettingsController {
  const VaultSecuritySettingsController(this._ref);

  final Ref _ref;

  Future<void> _set(AppSettings Function(AppSettings s) change) =>
      _ref.read(settingsProvider.notifier).update(change);

  /// Turning it on first stores the OS-protected biometric copy of the key
  /// (vault unlocked; may show the system prompt) — false, with the setting
  /// unchanged, when the OS refused. Turning it off deletes the copy (via
  /// the session's settings listener).
  Future<bool> setBiometrics(bool on) async {
    if (on &&
        !await _ref.read(vaultSessionProvider.notifier).enableBiometricCopy()) {
      return false;
    }
    await _set((s) => s.copyWith(vaultBiometrics: on));
    return true;
  }

  Future<void> setAutoLockMinutes(int minutes) =>
      _set((s) => s.copyWith(vaultAutoLockMinutes: minutes < 0 ? 0 : minutes));

  Future<void> setLockOnBackground(bool on) =>
      _set((s) => s.copyWith(vaultLockOnBackground: on));

  Future<void> setClipboardClearSeconds(int seconds) =>
      _set((s) => s.copyWith(clipboardClearSeconds: seconds < 0 ? 0 : seconds));

  Future<void> setBlockScreenshots(bool on) =>
      _set((s) => s.copyWith(vaultBlockScreenshots: on));

  Future<void> setReauthToReveal(bool on) =>
      _set((s) => s.copyWith(vaultReauthToReveal: on));

  Future<void> setBreachMonitoring(bool on) =>
      _set((s) => s.copyWith(breachMonitoring: on));

  Future<void> setWipeAfterFailedAttempts(bool on) =>
      _set((s) => s.copyWith(wipeAfterFailedAttempts: on));

  /// Whether the device has enrolled biometrics.
  Future<bool> biometricsAvailable() async {
    try {
      return await _ref.read(biometricAuthProvider).isAvailable();
    } on Object {
      return false;
    }
  }

  /// Phase 1: prepares a new recovery code (NOT yet active — the previous
  /// kit keeps working), renders the PDF and opens the share sheet. Needs
  /// the unlocked vault. False when the share sheet was dismissed.
  Future<bool> shareRecoveryKit() async {
    final session = _ref.read(vaultSessionProvider.notifier);
    final share = _ref.read(recoveryKitShareProvider);
    final now = _ref.read(clockProvider).now();
    return session.keepUnlockedDuring(() async {
      final code = await session.prepareRecoveryCode();
      final pdf = await RecoveryKitPdf.build(code: code, createdAt: now);
      return share.share(pdf, fileName: RecoveryKitPdf.fileName(now));
    });
  }

  /// Phase 2: the user saved the kit — the new code replaces the old one.
  Future<bool> commitRecoveryKit() =>
      _ref.read(vaultSessionProvider.notifier).commitRecoveryCode();

  /// The kit was not saved: the old code stays valid.
  void discardRecoveryKit() =>
      _ref.read(vaultSessionProvider.notifier).discardRecoveryCode();
}

final vaultSecuritySettingsControllerProvider =
    Provider<VaultSecuritySettingsController>(
      VaultSecuritySettingsController.new,
    );

/// Share-sheet hand-off of the Recovery Kit (overridden in tests).
final recoveryKitShareProvider = Provider<RecoveryKitShare>(
  (ref) => const RecoveryKitShare(),
);
