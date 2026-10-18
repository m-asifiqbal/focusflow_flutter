/// ============================================================
/// VAULT SESSION — unlock / lock, auto-lock, back-off, biometrics, wipe
/// ============================================================
///
/// The single owner of the vault's data key while the app runs:
///
/// * The key exists in memory only between a successful unlock (PIN,
///   biometrics, recovery code) and [VaultSessionController.lock]. Locking
///   zeroes it and publishes a key-less state, so every provider that
///   decrypted something from it is rebuilt without plaintext.
/// * Auto-lock: after `AppSettings.vaultAutoLockMinutes` without
///   [VaultSessionController.touch] (0 = only when leaving the app), and
///   when the app goes to the background if `vaultLockOnBackground`
///   (`hidden` / `paused`, not `inactive` — Face ID and Control Center
///   only make the app inactive). [keepUnlockedDuring] suspends the
///   background lock for system pickers / share sheets.
/// * PIN checks go through [PinAttemptGuard] (5 free, then exponential
///   back-off, persisted, monotonic — see pin_attempt_guard.dart). Every
///   attempt is counted BEFORE the PIN is checked and reset on success;
///   unlock / verify run one at a time ([_exclusive]) so concurrent checks
///   can neither skip the back-off nor lose a count. With
///   `wipeAfterFailedAttempts` the 10th
///   consecutive failure erases the vault: key material, every vault item
///   (any lifecycle state, incl. history) and the generator history —
///   on this device only (no sync tombstones; the backup keeps its copy).
/// * Locking also clears a still-pending copied secret from the clipboard;
///   starting the session clears one that expired while the app was dead.
/// * Biometric copy: written only while the setting is on (and deleted —
///   with any legacy copy — whenever it is off); OS-gated reads skip the
///   app's own local_auth prompt. See VaultKeyManager.
/// * Key bundle unreadable, or items without a key → [VaultPhase.unreadable]
///   (recovery code or explicit erase only — never a silent set-up).
/// * Recovery-code unlock forces a new PIN ([completePinReset]) and a new
///   recovery code; Recovery Kit codes are two-phase (prepare → user saved
///   it → commit). Changing the PIN re-keys the backup encryption key.
///
/// Nothing here logs PINs, keys or secrets.
/// ============================================================
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/crypto/biometric_auth.dart';
import 'package:focusflow/core/crypto/pin_attempt_guard.dart';
import 'package:focusflow/core/crypto/vault_key.dart';
import 'package:focusflow/core/crypto/vault_key_manager.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/features/vault/data/datasource/recovery_kit_pdf.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/features/vault/presentation/state/vault_session_state.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

final vaultSessionProvider =
    NotifierProvider<VaultSessionController, VaultSessionState>(
      VaultSessionController.new,
    );

class VaultSessionController extends Notifier<VaultSessionState> {
  Timer? _autoLockTimer;
  AppLifecycleListener? _lifecycle;
  DateTime? _lastActivity;
  int _holds = 0;
  bool _disposed = false;
  bool _busy = false;
  bool _pinBusy = false;
  final Queue<Completer<void>> _pinWaiters = Queue();
  bool _autoEnrollTried = false;
  PendingRecoveryCode? _pendingCode;
  Future<void>? _loading;

  VaultKeyManager get _keys => ref.read(vaultKeyManagerProvider);
  PinAttemptGuard get _guard => ref.read(pinAttemptGuardProvider);
  BiometricAuth get _bio => ref.read(biometricAuthProvider);
  DateTime _now() => ref.read(clockProvider).now();

  @override
  VaultSessionState build() {
    ref.onDispose(() {
      _disposed = true;
      _stopTimers();
      state.key?.destroy();
    });
    ref.listen(
      settingsProvider.select((s) => s.vaultAutoLockMinutes),
      (_, _) => _scheduleAutoLock(),
    );
    ref.listen(
      settingsProvider.select((s) => s.vaultBiometrics),
      (_, enabled) => unawaited(_onBiometricSetting(enabled)),
    );
    _loading = Future<void>.microtask(() async {
      // Cold start: a copied secret whose clear was due while the app was
      // not running is removed now; stale Recovery Kit PDFs too.
      try {
        await ref.read(secureClipboardProvider).restorePending();
      } on Object {
        // Clipboard / keychain unavailable or slow (tests, previews).
      }
      unawaited(RecoveryKitShare.cleanUpStale());
      await refresh();
    });
    return VaultSessionState.loading;
  }

  /// Runs PIN checks one at a time (a `_busy` guard that queues instead
  /// of rejecting, so no attempt is lost or skips the back-off). No future
  /// is kept between calls: an idle lock never awaits anything.
  Future<T> _exclusive<T>(Future<T> Function() action) async {
    while (_pinBusy) {
      final turn = Completer<void>();
      _pinWaiters.add(turn);
      await turn.future;
    }
    _pinBusy = true;
    try {
      return await action();
    } finally {
      _pinBusy = false;
      if (_pinWaiters.isNotEmpty) _pinWaiters.removeFirst().complete();
    }
  }

  /// Longest the initial key-store reads may take (see [ready]).
  static const Duration loadTimeout = Duration(seconds: 6);

  void _giveUpLoading() {
    if (!_disposed && state.phase == VaultPhase.loading) {
      state = state.copyWith(phase: VaultPhase.locked);
    }
  }

  /// Completes once the initial load (vault set up? attempts?) is done —
  /// at the latest after [loadTimeout].
  ///
  /// Bounded because the first read of the key store after the phone sat
  /// idle (or an OEM task killer froze the app) can stall, and everything
  /// that waits here — Quick Add › Password, a locked note, opening a vault
  /// item — would then show its progress indicator for ever and end in an
  /// ANR. After the wait the vault is treated as locked: the PIN pad then
  /// does its own, visible work, and a late answer still updates the state.
  Future<void> get ready => (_loading ?? Future<void>.value()).timeout(
    loadTimeout,
    onTimeout: _giveUpLoading,
  );

  /// Re-reads set-up status, the attempt counter and biometric readiness.
  /// Never throws (secure storage may be missing in tests / previews).
  Future<void> refresh() async {
    try {
      final status = await _keys.status();
      final attempts = await _guard.load(_now());
      final setUp = status == VaultKeyStatus.ready;
      if (!ref.read(settingsProvider).vaultBiometrics) {
        await _keys.disableBiometrics(); // never keep a copy while off
      }
      final (ready, kind) = await _biometrics(setUp);
      final orphanItems =
          status == VaultKeyStatus.absent && await _hasVaultItems();
      if (_disposed) return;
      final phase = state.isUnlocked
          ? VaultPhase.unlocked
          : switch (status) {
              VaultKeyStatus.ready => VaultPhase.locked,
              VaultKeyStatus.unreadable => VaultPhase.unreadable,
              VaultKeyStatus.absent when orphanItems => VaultPhase.unreadable,
              VaultKeyStatus.absent => VaultPhase.notSetUp,
            };
      state = VaultSessionState(
        phase: phase,
        key: phase == VaultPhase.unlocked ? state.key : null,
        attempts: attempts,
        biometricsReady: ready,
        biometricKind: kind,
        unlockedAt: state.unlockedAt,
        pinResetRequired:
            phase == VaultPhase.unlocked && state.pinResetRequired,
      );
    } on Object {
      if (!_disposed && state.phase == VaultPhase.loading) {
        state = state.copyWith(phase: VaultPhase.locked);
      }
    }
  }

  Future<bool> _hasVaultItems() async {
    try {
      return (await ref.read(vaultRepositoryProvider).allItemIds()).isNotEmpty;
    } on Object {
      return false;
    }
  }

  Future<(bool, BiometricKind)> _biometrics(bool setUp) async {
    final kind = await _bio.kind();
    if (!setUp || !ref.read(settingsProvider).vaultBiometrics) {
      return (false, kind);
    }
    final ready = await _bio.isAvailable() && await _keys.hasBiometricCopy();
    return (ready, kind);
  }

  // ─────────────────────────────── Unlock ───────────────────────────────

  /// First-time set-up: creates the data key wrapped by [pin] and opens
  /// the session. Adds the biometric copy when the setting is on and the
  /// device supports it. Refused (StateError) when any key bundle exists —
  /// also an unreadable one — or vault items exist without a key.
  Future<void> setUp(String pin) async {
    if (await _keys.status() != VaultKeyStatus.absent ||
        await _hasVaultItems()) {
      throw StateError('A vault already exists on this device');
    }
    final key = await _keys.setUp(pin);
    await _guard.reset();
    await _open(key);
  }

  /// Unlocks with the 6-digit master PIN.
  Future<UnlockResult> unlockWithPin(String pin) => _exclusive(() async {
    if (state.isUnlocked) return UnlockResult.success;
    final now = _now();
    final before = await _guard.load(now);
    if (before.isLockedOut(now)) {
      state = state.copyWith(attempts: before);
      return UnlockResult.lockedOut;
    }
    // Counted before the (slow) check: killing the app mid-check costs
    // the attempt anyway.
    final attempts = await _guard.recordAttempt(now);
    final VaultKey? key;
    try {
      key = await _keys.unlockWithPin(pin);
    } on VaultKeyUnreadableException {
      await _guard.reset(); // not the user's fault
      if (!_disposed) state = state.copyWith(phase: VaultPhase.unreadable);
      return UnlockResult.unavailable;
    }
    if (key == null) return _failed(attempts);
    await _guard.reset();
    await _open(key);
    return UnlockResult.success;
  });

  /// Checks [pin] without changing the session (re-auth before Vault
  /// security changes). Counts towards the same back-off.
  Future<UnlockResult> verifyPin(String pin) => _exclusive(() async {
    final now = _now();
    final before = await _guard.load(now);
    if (before.isLockedOut(now)) {
      state = state.copyWith(attempts: before);
      return UnlockResult.lockedOut;
    }
    final attempts = await _guard.recordAttempt(now);
    final bool ok;
    try {
      ok = await _keys.verifyPin(pin);
    } on VaultKeyUnreadableException {
      await _guard.reset();
      return UnlockResult.unavailable;
    }
    if (!ok) return _failed(attempts);
    await _guard.reset();
    state = state.copyWith(attempts: PinAttemptState.initial);
    return UnlockResult.success;
  });

  /// The attempt (already counted) failed.
  Future<UnlockResult> _failed(PinAttemptState attempts) async {
    if (ref.read(settingsProvider).wipeAfterFailedAttempts &&
        attempts.failed >= PinAttemptGuard.wipeThreshold) {
      await wipe();
      return UnlockResult.wiped;
    }
    state = state.copyWith(attempts: attempts);
    return UnlockResult.wrongPin;
  }

  /// Face ID / fingerprint → biometric key copy. For the OS-gated copy the
  /// read itself shows the system prompt; a legacy (app-gated) copy is
  /// only read after local_auth and is migrated by [_open].
  Future<UnlockResult> unlockWithBiometrics({
    String reason = 'Unlock your vault',
  }) async {
    if (state.isUnlocked) return UnlockResult.success;
    if (!state.biometricsReady || _busy) return UnlockResult.unavailable;
    if (!ref.read(settingsProvider).vaultBiometrics) {
      return UnlockResult.unavailable;
    }
    _busy = true;
    try {
      if (await _keys.biometricReadNeedsAppGate() &&
          !await _bio.authenticate(reason)) {
        return UnlockResult.cancelled;
      }
      final read = await _keys.readBiometricCopy();
      switch (read.status) {
        case BiometricCopyStatus.cancelled:
          return UnlockResult.cancelled;
        case BiometricCopyStatus.missing:
          // Gone / invalidated (biometrics re-enrolled): PIN from now on.
          await _keys.disableBiometrics();
          state = state.copyWith(biometricsReady: false);
          return UnlockResult.unavailable;
        case BiometricCopyStatus.unlocked:
          await _guard.reset();
          await _open(read.key!);
          return UnlockResult.success;
      }
    } finally {
      _busy = false;
    }
  }

  /// Forgotten PIN: unlock with the Recovery Kit code. The session is then
  /// flagged [VaultSessionState.pinResetRequired] until [completePinReset].
  Future<UnlockResult> unlockWithRecoveryCode(String code) async {
    final key = await _keys.unlockWithRecoveryCode(code);
    if (key == null) return UnlockResult.wrongPin;
    await _guard.reset();
    await _open(key, pinReset: true);
    return UnlockResult.success;
  }

  /// After a recovery-code unlock: re-wraps the data key under [newPin]
  /// (also repairs an unreadable bundle), re-keys backup encryption and
  /// prepares a NEW recovery code (the used one stays valid until the user
  /// confirms the new one is saved — [commitRecoveryCode]). Returns it.
  Future<String> completePinReset(String newPin) async {
    final key = state.requireKey();
    await _keys.resetPin(key, newPin);
    await _rekeyBackups(newPin);
    if (!_disposed) {
      state = state.copyWith(
        phase: VaultPhase.unlocked,
        pinResetRequired: false,
      );
    }
    return prepareRecoveryCode();
  }

  Future<void> _open(VaultKey key, {bool pinReset = false}) async {
    if (_disposed) {
      key.destroy();
      return;
    }
    final settings = ref.read(settingsProvider);
    var bioReady = false;
    try {
      if (settings.vaultBiometrics && await _bio.isAvailable()) {
        if (await _keys.hasLegacyBiometricCopy() ||
            (!await _keys.hasBiometricCopy() && !_autoEnrollTried)) {
          // Missing copy / migration of the legacy app-gated copy. On
          // Android the OS-gated write prompts: try once per app run.
          _autoEnrollTried = true;
          await _keys.enableBiometrics(key);
          await _keys.disableLegacyBiometrics();
        }
        bioReady = await _keys.hasBiometricCopy();
      } else {
        await _keys.disableBiometrics();
      }
    } on Object {
      bioReady = false;
    }
    state.key?.destroy();
    state = VaultSessionState(
      phase: VaultPhase.unlocked,
      key: key,
      biometricsReady: bioReady,
      biometricKind: await _bio.kind(),
      unlockedAt: _now(),
      pinResetRequired: pinReset,
    );
    _lastActivity = _now();
    _lifecycle ??= AppLifecycleListener(onStateChange: _onLifecycle);
    _scheduleAutoLock();
  }

  // ──────────────────────────────── Lock ────────────────────────────────

  /// Locks now: zeroes the key and, unless [clearClipboard] is false,
  /// clears a pending copied secret. The background lock keeps the copied
  /// secret (the user is switching apps to paste it); its own timer / the
  /// resume check still clears it on schedule.
  Future<void> lock({bool clearClipboard = true}) async {
    _stopTimers();
    final key = state.key;
    if (state.isUnlocked) state = state.locked();
    key?.destroy();
    if (clearClipboard) await ref.read(secureClipboardProvider).clearNow();
  }

  /// Records user activity inside the vault (restarts the auto-lock timer).
  void touch() {
    if (!state.isUnlocked) return;
    _lastActivity = _now();
    _scheduleAutoLock();
  }

  /// Runs [action] (file picker, share sheet …) without the background lock
  /// kicking in while the system UI is in front.
  Future<T> keepUnlockedDuring<T>(Future<T> Function() action) async {
    _holds++;
    try {
      return await action();
    } finally {
      _holds--;
    }
  }

  /// When the vault auto-locks if nothing else happens (null = locked or
  /// no idle timeout). Polled by the list header's countdown.
  DateTime? get autoLockDeadline {
    final after = _autoLockAfter;
    if (!state.isUnlocked || after == null) return null;
    return (_lastActivity ?? _now()).add(after);
  }

  Duration? get _autoLockAfter {
    final minutes = ref.read(settingsProvider).vaultAutoLockMinutes;
    return minutes > 0 ? Duration(minutes: minutes) : null;
  }

  void _scheduleAutoLock() {
    _autoLockTimer?.cancel();
    _autoLockTimer = null;
    final after = _autoLockAfter;
    if (!state.isUnlocked || after == null) return;
    final idle = _now().difference(_lastActivity ?? _now());
    final wait = after - idle;
    _autoLockTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      unawaited(checkAutoLock());
    });
  }

  /// Locks when the auto-lock delay has passed since the last activity
  /// (timer callback, and on resume — timers do not run while suspended).
  Future<void> checkAutoLock() async {
    final after = _autoLockAfter;
    if (!state.isUnlocked || after == null) return;
    if (_now().difference(_lastActivity ?? _now()) >= after) {
      await lock();
    } else {
      _scheduleAutoLock();
    }
  }

  void _onLifecycle(AppLifecycleState s) {
    if (!state.isUnlocked) return;
    switch (s) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        if (_holds == 0 && ref.read(settingsProvider).vaultLockOnBackground) {
          unawaited(lock(clearClipboard: false));
        }
      case AppLifecycleState.resumed:
        unawaited(checkAutoLock());
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  void _stopTimers() {
    _autoLockTimer?.cancel();
    _autoLockTimer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  /// Whether an auto-lock timer is pending (tests / debug UI).
  @visibleForTesting
  bool get autoLockScheduled => _autoLockTimer?.isActive ?? false;

  // ─────────────────────────── Settings actions ──────────────────────────

  /// Re-wraps the data key under [newPin] (items are not re-encrypted).
  /// Requires the unlocked vault and the current PIN.
  Future<UnlockResult> changePin(String currentPin, String newPin) async {
    state.requireKey();
    final check = await verifyPin(currentPin);
    if (check != UnlockResult.success) return check;
    await _keys.changePin(state.requireKey(), newPin);
    await _rekeyBackups(newPin);
    return UnlockResult.success;
  }

  /// Sets a new PIN on the unlocked vault (after the pad verified the
  /// current one, or after a recovery-code unlock).
  Future<void> resetPin(String newPin) async {
    await _keys.resetPin(state.requireKey(), newPin);
    await _rekeyBackups(newPin);
    if (!_disposed && state.pinResetRequired) {
      state = state.copyWith(pinResetRequired: false);
    }
  }

  /// New backups must open with the new PIN (older ones keep the PIN they
  /// were made with). Best effort: the PIN change itself already happened.
  Future<void> _rekeyBackups(String newPin) async {
    try {
      await ref.read(backupKeyStoreProvider).rekey(newPin);
    } on Object {
      // Keychain unavailable; "Encrypt backups" can be re-enabled.
    }
  }

  /// First recovery code (set-up follow-up): stored right away — there is
  /// no older code that could be lost. Unlocked only.
  Future<String> createRecoveryCode() =>
      _keys.createRecoveryCode(state.requireKey());

  /// Step 1 of a NEW recovery code: generated and kept in memory; the old
  /// code still works until [commitRecoveryCode].
  Future<String> prepareRecoveryCode() async {
    final pending = await _keys.prepareRecoveryCode(state.requireKey());
    _pendingCode = pending;
    return pending.code;
  }

  /// Step 2: the user confirmed the new code is saved — it replaces the
  /// old one. False when nothing was pending.
  Future<bool> commitRecoveryCode() async {
    final pending = _pendingCode;
    if (pending == null) return false;
    await _keys.commitRecoveryCode(pending);
    _pendingCode = null;
    return true;
  }

  /// The prepared, not yet committed code (shown by the new-kit sheet).
  String? get pendingRecoveryCode => _pendingCode?.code;

  /// Drops a prepared code (the old one stays valid).
  void discardRecoveryCode() => _pendingCode = null;

  /// Writes the biometric copy of the open key now (Settings toggle). May
  /// show the system prompt (Android). False when the OS refused / the
  /// vault is locked.
  Future<bool> enableBiometricCopy() async {
    final key = state.key;
    if (!state.isUnlocked || key == null) return false;
    try {
      if (!await _bio.isAvailable()) return false;
      if (!await _keys.hasBiometricCopy() ||
          await _keys.hasLegacyBiometricCopy()) {
        if (!await _keys.enableBiometrics(key)) return false;
      }
    } on Object {
      return false;
    }
    if (!_disposed) state = state.copyWith(biometricsReady: true);
    return true;
  }

  Future<void> _onBiometricSetting(bool enabled) async {
    try {
      if (!enabled) {
        await _keys.disableBiometrics();
      } else if (state.isUnlocked &&
          await _bio.isAvailable() &&
          !await _keys.hasBiometricCopy()) {
        if (!await _keys.enableBiometrics(state.requireKey())) {
          // The OS refused (no strong biometrics / cancelled): show the
          // switch as it really is.
          await ref
              .read(settingsProvider.notifier)
              .update((s) => s.copyWith(vaultBiometrics: false));
        }
      }
      if (!_disposed) {
        state = state.copyWith(
          biometricsReady: (await _biometrics(
            state.phase != VaultPhase.notSetUp,
          )).$1,
        );
      }
    } on Object {
      // Storage unavailable — readiness is re-read on the next refresh.
    }
  }

  /// Erases the vault on this device: key material (PIN wrap, recovery
  /// wrap, biometric copy, attempt counter), every vault item in any state
  /// (+ password history) and the generator history.
  Future<void> wipe() async {
    _pendingCode = null;
    await lock();
    await _keys.wipe();
    await _guard.reset();
    final vault = ref.read(vaultRepositoryProvider);
    final ids = await vault.allItemIds();
    if (ids.isNotEmpty) {
      // Local only: no tombstones, so the next sync can't erase the backup.
      final items = ref.read(itemsRepositoryProvider);
      await vault.deleteLocallyOnly(
        ids,
        () => items.deleteForever([
          for (final id in ids) ItemRef(ItemType.vault, id),
        ]),
      );
    }
    await vault.clearGeneratorHistory();
    if (!_disposed) {
      state = const VaultSessionState(phase: VaultPhase.notSetUp);
    }
  }
}
