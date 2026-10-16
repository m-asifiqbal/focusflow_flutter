/// ============================================================
/// VAULT GENERATOR CONTROLLER — `generatorControllerProvider` (screen 21)
/// ============================================================
///
/// Owns the Generator tab: mode, options and the current value, which is
/// re-drawn from Random.secure() on every option change. Copy goes through
/// SecureClipboard (cleared after Settings › Clipboard clear and on lock)
/// and lands in the encrypted "Recently generated" history (last 10,
/// sealed with the vault key, AAD `generator`). "Save to new vault item"
/// hands the value to the editor through [vaultEditorPrefillProvider] —
/// in memory, never through a URL. Kept alive across tab switches; the
/// value is dropped when the vault locks. Nothing here logs.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/crypto/password_generator.dart';
import 'package:focusflow/core/crypto/vault_cipher.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/features/vault/presentation/state/vault_generator_state.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class VaultGeneratorController extends Notifier<VaultGeneratorState> {
  PasswordGenerator get _gen => ref.read(passwordGeneratorProvider);

  @override
  VaultGeneratorState build() {
    ref.listen(vaultSessionProvider.select((s) => s.isUnlocked), (_, open) {
      state = open ? _withValue(state) : state.copyWith(clearValue: true);
    });
    ref.listen(effWordlistProvider, (_, next) {
      if (next.hasValue && state.mode == GeneratorMode.passphrase) {
        state = _withValue(state);
      }
    });
    final open = ref.read(vaultSessionProvider).isUnlocked;
    const initial = VaultGeneratorState();
    return open ? _withValue(initial) : initial;
  }

  /// [s] with a freshly generated value (none while the wordlist loads).
  VaultGeneratorState _withValue(VaultGeneratorState s) {
    final GeneratedValue? v = switch (s.mode) {
      GeneratorMode.password => _gen.password(s.password),
      GeneratorMode.pin => _gen.pin(s.pinLength),
      GeneratorMode.passphrase => switch (ref.read(effWordlistProvider)) {
        AsyncData(:final value) => _gen.passphrase(s.passphrase, value),
        _ => null,
      },
    };
    return v == null ? s.copyWith(clearValue: true) : s.copyWith(value: v);
  }

  void _apply(VaultGeneratorState next) {
    ref.read(vaultSessionProvider.notifier).touch();
    state = _withValue(next);
  }

  void setMode(GeneratorMode mode) => _apply(state.copyWith(mode: mode));

  /// Ignored when it would turn every character set off.
  void setPasswordOptions(PasswordOptions o) {
    if (!o.upper && !o.lower && !o.digits && !o.symbols) return;
    _apply(state.copyWith(password: o));
  }

  void setPassphraseOptions(PassphraseOptions o) =>
      _apply(state.copyWith(passphrase: o));

  void setPinLength(int digits) => _apply(
    state.copyWith(
      pinLength: digits.clamp(
        VaultGeneratorState.minPin,
        VaultGeneratorState.maxPin,
      ),
    ),
  );

  void regenerate() => _apply(state);

  /// Copies [text] (or the current value) with auto-clear. Returns the
  /// clear delay in seconds (0 = never), or null when nothing was copied.
  Future<int?> copy([String? text]) async {
    final value = text ?? state.value?.value;
    if (value == null || value.isEmpty) return null;
    final seconds = ref.read(settingsProvider).clipboardClearSeconds;
    await ref
        .read(secureClipboardProvider)
        .copy(
          value,
          clearAfter: seconds > 0 ? Duration(seconds: seconds) : null,
        );
    ref.read(vaultSessionProvider.notifier).touch();
    if (text == null) await remember();
    return seconds;
  }

  /// Seals the current value into the history (skips a repeat of the
  /// newest entry). No-op while locked.
  Future<void> remember() async {
    final v = state.value;
    final key = ref.read(vaultSessionProvider).key;
    if (v == null || key == null || key.isDestroyed) return;
    final repo = ref.read(vaultRepositoryProvider);
    final latest = await repo.watchGeneratorHistory().first;
    if (latest.isNotEmpty) {
      try {
        final last = await VaultCipher.openString(
          key.secretKey,
          latest.first.encryptedValue,
          aad: VaultAad.generator,
        );
        if (last == v.value) return;
      } on Object {
        // Unreadable entry (other key) — just add the new one.
      }
    }
    final blob = await VaultCipher.sealString(
      key.secretKey,
      v.value,
      aad: VaultAad.generator,
    );
    await repo.addGeneratorEntry(
      blob,
      mode: v.mode.name,
      entropyBits: v.entropyBits.round(),
    );
  }

  /// Remembers the value and parks it for the new-item editor. Returns
  /// false when there is nothing to save.
  Future<bool> prepareNewItem() async {
    final v = state.value;
    if (v == null) return false;
    await remember();
    ref.read(vaultEditorPrefillProvider.notifier).set(v.value);
    return true;
  }

  Future<void> clearHistory() =>
      ref.read(vaultRepositoryProvider).clearGeneratorHistory();
}

final generatorControllerProvider =
    NotifierProvider<VaultGeneratorController, VaultGeneratorState>(
      VaultGeneratorController.new,
    );

/// A generated password waiting for the next new-item editor (in memory
/// only; taken once, dropped on lock).
class VaultEditorPrefill extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(vaultSessionProvider.select((s) => s.isUnlocked));
    return null;
  }

  void set(String password) => state = password;

  /// The parked password, cleared as it is read.
  String? take() {
    final v = state;
    state = null;
    return v;
  }
}

final vaultEditorPrefillProvider =
    NotifierProvider<VaultEditorPrefill, String?>(VaultEditorPrefill.new);
