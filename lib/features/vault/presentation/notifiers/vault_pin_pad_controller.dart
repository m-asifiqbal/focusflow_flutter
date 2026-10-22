/// ============================================================
/// VAULT PIN PAD — entry logic of the 6-digit master PIN (17 + unlock sheet)
/// ============================================================
///
/// Shared by the lock screen, the unlock sheet and the Vault security
/// re-auth sheet. Collects digits; on the sixth digit it either unlocks
/// (existing vault), runs the first-time set-up (enter → confirm →
/// VaultSessionController.setUp), checks the PIN without unlocking
/// (re-auth, [startReauth]) or sets a new one after that check (change
/// PIN: verify → new → confirm → resetPin, which re-wraps the data key)
/// or — after a recovery-code unlock — collects the new PIN directly
/// ([startNewPin] → VaultSessionController.completePinReset). Trivially
/// guessable PINs (VaultKeyManager.weakPinReason) are refused whenever a
/// PIN is CHOSEN, never when one is entered to unlock. Wrong PINs bump
/// [VaultPinPadState.errorTick] so the dots shake; lock-outs come from the
/// session's persisted attempt counter. The digits live only in this
/// state and are cleared after every attempt; nothing is logged.
/// Whatever happens to a check — an exception, a stalled key store, a phone
/// too slow for the stored KDF cost — the pad leaves "busy" and says so
/// ([UnlockResult.failed]); it never stays on "Checking…" for ever.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/crypto/pin_attempt_guard.dart';
import 'package:focusflow/core/crypto/vault_key_manager.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/state/vault_session_state.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// What the pad is collecting.
enum VaultPadStep {
  /// Existing vault: the master PIN.
  unlock,

  /// First run: choose a PIN.
  create,

  /// First run: repeat it.
  confirm,

  /// Re-auth: the current PIN, checked without unlocking.
  verify,

  /// Change PIN: the new PIN.
  changeNew,

  /// Change PIN: the new PIN again.
  changeConfirm,
}

@immutable
class VaultPinPadState {
  const VaultPinPadState({
    required this.step,
    this.length = 0,
    this.busy = false,
    this.errorTick = 0,
    this.message,
    this.done = false,
  });

  static const int pinLength = 6;

  final VaultPadStep step;

  /// Digits entered so far (the digits themselves stay in the controller).
  final int length;

  /// Argon2id is running.
  final bool busy;

  /// Incremented on every rejected PIN (drives the shake).
  final int errorTick;

  /// Error / hint line under the dots ("Wrong PIN", "PINs don't match").
  final String? message;

  /// Re-auth / change PIN finished successfully.
  final bool done;

  VaultPinPadState copyWith({
    VaultPadStep? step,
    int? length,
    bool? busy,
    int? errorTick,
    String? message,
    bool clearMessage = false,
    bool? done,
  }) => VaultPinPadState(
    step: step ?? this.step,
    length: length ?? this.length,
    busy: busy ?? this.busy,
    errorTick: errorTick ?? this.errorTick,
    message: clearMessage ? null : (message ?? this.message),
    done: done ?? this.done,
  );

  @override
  String toString() => 'VaultPinPadState($step, $length/6, busy: $busy)';
}

class VaultPinPadController extends AutoDisposeNotifier<VaultPinPadState> {
  final StringBuffer _digits = StringBuffer();
  String? _firstPin;
  bool _changePin = false;
  bool _resetMode = false;

  VaultSessionController get _session =>
      ref.read(vaultSessionProvider.notifier);

  @override
  VaultPinPadState build() {
    final notSetUp = ref.watch(
      vaultSessionProvider.select((s) => s.phase == VaultPhase.notSetUp),
    );
    _digits.clear();
    _firstPin = null;
    _changePin = false;
    _resetMode = false;
    return VaultPinPadState(
      step: notSetUp ? VaultPadStep.create : VaultPadStep.unlock,
    );
  }

  /// The back-off deadline when the pad is locked out right now.
  DateTime? get lockedUntil {
    final attempts = ref.read(vaultSessionProvider).attempts;
    final now = ref.read(clockProvider).now();
    return attempts.isLockedOut(now) ? attempts.lockedUntil : null;
  }

  /// Switches the pad to re-auth: the current PIN is checked without
  /// unlocking; with [changePin] a new PIN is then chosen and confirmed.
  void startReauth({bool changePin = false}) {
    _digits.clear();
    _firstPin = null;
    _changePin = changePin;
    _resetMode = false;
    state = const VaultPinPadState(step: VaultPadStep.verify);
  }

  /// Forgotten PIN (after a recovery-code unlock): choose and confirm a new
  /// PIN without the old one; finishing prepares a new recovery code.
  void startNewPin() {
    _digits.clear();
    _firstPin = null;
    _changePin = false;
    _resetMode = true;
    state = const VaultPinPadState(step: VaultPadStep.changeNew);
  }

  /// Rejects a guessable new PIN (true = rejected, message shown).
  bool _rejectWeak(String pin, VaultPadStep stayOn) {
    final reason = VaultKeyManager.weakPinReason(pin);
    if (reason == null) return false;
    state = VaultPinPadState(
      step: stayOn,
      errorTick: state.errorTick + 1,
      message: tr('{reason} · choose another PIN', {'reason': reason}),
    );
    return true;
  }

  /// Whether the step checks a PIN against the stored one (back-off
  /// applies).
  static bool checksPin(VaultPadStep step) =>
      step == VaultPadStep.unlock || step == VaultPadStep.verify;

  /// Adds one digit (ignored while busy, full, done or locked out).
  Future<void> input(String digit) async {
    if (state.busy || state.done) return;
    if (_digits.length >= VaultPinPadState.pinLength) return;
    if (checksPin(state.step) && lockedUntil != null) return;
    _digits.write(digit);
    state = state.copyWith(length: _digits.length, clearMessage: true);
    if (_digits.length == VaultPinPadState.pinLength) await _submit();
  }

  void backspace() {
    if (state.busy || state.done || _digits.isEmpty) return;
    final s = _digits.toString();
    _digits
      ..clear()
      ..write(s.substring(0, s.length - 1));
    state = state.copyWith(length: _digits.length);
  }

  /// Back to "Choose a PIN" from the confirm step (set-up or change PIN).
  void restartSetup() {
    _digits.clear();
    _firstPin = null;
    state = VaultPinPadState(
      step: state.step == VaultPadStep.changeConfirm
          ? VaultPadStep.changeNew
          : VaultPadStep.create,
    );
  }

  Future<void> _submit() async {
    final pin = _digits.toString();
    _digits.clear();
    switch (state.step) {
      case VaultPadStep.create:
        if (_rejectWeak(pin, VaultPadStep.create)) return;
        _firstPin = pin;
        state = state.copyWith(
          step: VaultPadStep.confirm,
          length: 0,
          clearMessage: true,
        );
      case VaultPadStep.confirm:
        if (pin != _firstPin) {
          _firstPin = null;
          state = VaultPinPadState(
            step: VaultPadStep.create,
            errorTick: state.errorTick + 1,
            message: tr('PINs didn\'t match · try again'),
          );
          return;
        }
        state = state.copyWith(busy: true, length: VaultPinPadState.pinLength);
        try {
          await _session.setUp(pin);
        } on Object {
          _firstPin = null;
          state = VaultPinPadState(
            step: VaultPadStep.create,
            errorTick: state.errorTick + 1,
            message: tr('Couldn\'t set up the vault · try again'),
          );
          return;
        }
        _firstPin = null;
      case VaultPadStep.verify:
        state = state.copyWith(busy: true);
        // Changing the PIN needs the key: if the vault locked meanwhile,
        // entering the current PIN unlocks it again.
        final locked = !ref.read(vaultSessionProvider).isUnlocked;
        final result = await _checked(
          () => _changePin && locked
              ? _session.unlockWithPin(pin)
              : _session.verifyPin(pin),
        );
        if (result == UnlockResult.success) {
          state = _changePin
              ? const VaultPinPadState(step: VaultPadStep.changeNew)
              : state.copyWith(busy: false, done: true);
          return;
        }
        _reject(result);
      case VaultPadStep.changeNew:
        if (_rejectWeak(pin, VaultPadStep.changeNew)) return;
        _firstPin = pin;
        state = state.copyWith(
          step: VaultPadStep.changeConfirm,
          length: 0,
          clearMessage: true,
        );
      case VaultPadStep.changeConfirm:
        if (pin != _firstPin) {
          _firstPin = null;
          state = VaultPinPadState(
            step: VaultPadStep.changeNew,
            errorTick: state.errorTick + 1,
            message: tr('PINs didn\'t match · try again'),
          );
          return;
        }
        state = state.copyWith(busy: true, length: VaultPinPadState.pinLength);
        _firstPin = null;
        try {
          if (_resetMode) {
            await _session.completePinReset(pin);
          } else {
            await _session.resetPin(pin);
          }
        } on Object catch (e) {
          if (e is! VaultLockedException) {
            state = VaultPinPadState(
              step: _resetMode ? VaultPadStep.changeNew : VaultPadStep.verify,
              errorTick: state.errorTick + 1,
              message: tr('Couldn\'t change the PIN · try again'),
            );
            return;
          }
          if (_resetMode) {
            // Locked meanwhile: the recovery code is needed again.
            state = VaultPinPadState(
              step: VaultPadStep.changeNew,
              errorTick: state.errorTick + 1,
              message: tr('The vault locked · unlock again'),
            );
            return;
          }
          // Auto-locked / background-locked between steps: start over.
          state = VaultPinPadState(
            step: VaultPadStep.verify,
            errorTick: state.errorTick + 1,
            message: tr('The vault locked · try again'),
          );
          return;
        }
        state = state.copyWith(busy: false, done: true);
      case VaultPadStep.unlock:
        state = state.copyWith(busy: true);
        final result = await _checked(() => _session.unlockWithPin(pin));
        if (result == UnlockResult.success) return; // view switches / closes
        _reject(result);
    }
  }

  /// The longest a PIN check may keep the pad busy. The KDF has its own,
  /// shorter limit; this one also covers a stalled key store.
  static const Duration checkCeiling = Duration(seconds: 75);

  /// Runs a PIN check so that it always ends: an exception or the ceiling
  /// become [UnlockResult.failed] instead of leaving the pad busy.
  Future<UnlockResult> _checked(Future<UnlockResult> Function() check) async {
    try {
      return await check().timeout(
        checkCeiling,
        onTimeout: () => UnlockResult.failed,
      );
    } on Object {
      return UnlockResult.failed;
    }
  }

  void _reject(UnlockResult result) {
    state = state.copyWith(
      busy: false,
      length: 0,
      errorTick: state.errorTick + 1,
      message: _failureMessage(result),
    );
  }

  String? _failureMessage(UnlockResult result) {
    final failed = ref.read(vaultSessionProvider).attempts.failed;
    final wipe = ref.read(settingsProvider).wipeAfterFailedAttempts;
    return switch (result) {
      UnlockResult.wiped => tr('Too many attempts · the vault was erased'),
      UnlockResult.lockedOut => null, // the lock-out line takes over
      UnlockResult.failed => tr(
        "Couldn't check the PIN on this phone · close other apps and try again",
      ),
      _ when wipe && failed >= PinAttemptGuard.wipeThreshold - 3 => tr(
        '{count, plural, one {Wrong PIN · # try before the vault is erased} other {Wrong PIN · # tries before the vault is erased}}',
        {'count': PinAttemptGuard.wipeThreshold - failed},
      ),
      _ when failed >= PinAttemptGuard.freeAttempts => null,
      _ => tr(
        '{count, plural, one {Wrong PIN · # try left} other {Wrong PIN · # tries left}}',
        {'count': PinAttemptGuard.freeAttempts - failed},
      ),
    };
  }
}

/// PIN pad state for the lock screen / unlock sheet (one pad at a time).
final vaultPinPadProvider =
    NotifierProvider.autoDispose<VaultPinPadController, VaultPinPadState>(
      VaultPinPadController.new,
    );
