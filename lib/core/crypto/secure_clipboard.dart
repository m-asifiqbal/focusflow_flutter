/// ============================================================
/// SECURE CLIPBOARD — copy a secret, clear it again after N seconds
/// ============================================================
///
/// Settings › Vault security › "Clear copied passwords" (default 30 s,
/// 0 = never). [SecureClipboard.copy] puts the text on the system
/// clipboard and schedules a clear; a newer copy replaces the pending one.
///
/// * The pending clear is PERSISTED (deadline + SHA-256 of the copied
///   text, in the Keychain/Keystore-backed vault store — a hash of a
///   password must not sit in plain preferences), so a cold start after
///   the app was killed still clears an expired secret
///   ([SecureClipboard.restorePending], run when the vault session starts).
/// * A manual or idle lock clears now ([SecureClipboard.clearNow]). The
///   background lock deliberately does NOT: the user is usually switching
///   apps to paste. The window stays bounded by the deadline — the Dart
///   timer, the resume check ([SecureClipboard.clearIfExpired]), the
///   cold-start check, and on iOS the pasteboard's own expiration date.
/// * Copies go through the platform channel `focusflow/secure_clipboard`
///   ([SensitiveClipboardChannel]) so the OS can treat them as sensitive
///   (Android: ClipDescription.EXTRA_IS_SENSITIVE — hidden from the
///   clipboard preview / keyboard suggestions; iOS: local-only, never on
///   Universal Clipboard, with an expiration date). Without the native
///   side (MissingPluginException) it falls back to Clipboard.setData.
///
/// Trade-off: Dart never *reads* the clipboard to check it still holds our
/// secret (on iOS that shows the "Allow paste" prompt); the native `clear`
/// gets the hash and change token so it can skip clearing something the
/// user copied later. Without the native side the clear is unconditional.
/// ============================================================
library;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';
import 'package:focusflow/core/crypto/vault_secret_storage.dart';

/// Dart side of the `focusflow/secure_clipboard` method channel.
///
/// Contract (native side implemented per platform):
/// * `setSensitive({text: String, expiresInMs: int?})` → null. Puts [text]
///   on the clipboard marked sensitive; iOS also local-only and expiring
///   after `expiresInMs` (when given).
/// * `clear({sha256: String?})` → null. Clears the clipboard if it still
///   holds the text with that SHA-256 (hex, lower-case) / the item set by
///   the last `setSensitive` (iOS: unchanged `changeCount`); clears
///   unconditionally when `sha256` is null.
/// Any MissingPluginException / PlatformException falls back to
/// `Clipboard.setData`.
class SensitiveClipboardChannel {
  const SensitiveClipboardChannel();

  static const MethodChannel channel = MethodChannel(
    'focusflow/secure_clipboard',
  );

  Future<void> setSensitive(String text, {Duration? expiresIn}) async {
    try {
      await channel.invokeMethod<void>('setSensitive', {
        'text': text,
        if (expiresIn != null) 'expiresInMs': expiresIn.inMilliseconds,
      });
    } on MissingPluginException {
      await Clipboard.setData(ClipboardData(text: text));
    } on PlatformException {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  Future<void> clear({String? sha256}) async {
    try {
      await channel.invokeMethod<void>('clear', {'sha256': ?sha256});
    } on MissingPluginException {
      await Clipboard.setData(const ClipboardData(text: ''));
    } on PlatformException {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  }
}

class SecureClipboard {
  /// [writer] replaces the platform channel (tests): called with the text
  /// to copy and with '' to clear. [store] persists the pending clear.
  SecureClipboard({
    Future<void> Function(String text)? writer,
    DateTime Function()? now,
    VaultSecretStorage? store,
    SensitiveClipboardChannel channel = const SensitiveClipboardChannel(),
  }) : _writer = writer, // ignore: prefer_initializing_formals
       _now = now ?? DateTime.now,
       _store = store, // ignore: prefer_initializing_formals
       _channel = channel; // ignore: prefer_initializing_formals

  static const String storageKey = 'vault.clipboard.pending';

  final Future<void> Function(String text)? _writer;
  final DateTime Function() _now;
  final VaultSecretStorage? _store;
  final SensitiveClipboardChannel _channel;
  Timer? _timer;
  DateTime? _deadline;
  String? _hash;

  /// When the pending clear is due (null = nothing pending).
  DateTime? get clearDeadline => _deadline;

  /// True while a copied secret is waiting to be cleared.
  bool get hasPendingClear => _timer?.isActive ?? false;

  static String _sha256(String text) =>
      crypto.sha256.convert(utf8.encode(text)).toString();

  /// Copies [text]; clears after [clearAfter] (null / zero = never).
  Future<void> copy(String text, {Duration? clearAfter}) async {
    _cancel();
    final clears = clearAfter != null && clearAfter > Duration.zero;
    final writer = _writer;
    if (writer != null) {
      await writer(text);
    } else {
      await _channel.setSensitive(text, expiresIn: clears ? clearAfter : null);
    }
    if (!clears) {
      await _forget();
      return;
    }
    _hash = _sha256(text);
    _schedule(_now().add(clearAfter));
    await _persist();
  }

  void _schedule(DateTime due) {
    _timer?.cancel();
    _deadline = due;
    final wait = due.difference(_now());
    _timer = Timer(wait.isNegative ? Duration.zero : wait, () {
      unawaited(_clear());
    });
  }

  /// Cold start: picks up a clear that was pending when the app died —
  /// clears now when it is overdue, otherwise re-arms the timer.
  Future<void> restorePending() async {
    if (_deadline != null) return;
    final pending = await _load();
    if (pending == null) return;
    _hash = pending.$2;
    if (!_now().isBefore(pending.$1)) {
      await _clear();
    } else {
      _schedule(pending.$1);
    }
  }

  /// Clears when the pending deadline has passed (call on app resume: a
  /// suspended app's timer may not have fired yet). [now] defaults to the
  /// injected clock.
  Future<void> clearIfExpired([DateTime? now]) async {
    if (_deadline == null) await restorePending();
    final due = _deadline;
    if (due == null || (now ?? _now()).isBefore(due)) return;
    await _clear();
  }

  /// Clears now if a secret copied by us is still pending.
  Future<void> clearNow() async {
    if (_deadline == null) await restorePending();
    if (!hasPendingClear && _deadline == null) return;
    await _clear();
  }

  Future<void> _clear() async {
    final hash = _hash;
    _cancel();
    final writer = _writer;
    if (writer != null) {
      await writer('');
    } else {
      await _channel.clear(sha256: hash);
    }
    await _forget();
  }

  Future<void> _persist() async {
    final store = _store;
    final due = _deadline;
    if (store == null || due == null) return;
    try {
      await store.write(
        storageKey,
        jsonEncode({'until': due.millisecondsSinceEpoch, 'sha256': _hash}),
      );
    } on Object {
      // Keychain unavailable: the in-memory timer still clears.
    }
  }

  Future<(DateTime, String?)?> _load() async {
    final store = _store;
    if (store == null) return null;
    try {
      final raw = await store.read(storageKey);
      if (raw == null) return null;
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      return (
        DateTime.fromMillisecondsSinceEpoch((j['until']! as num).toInt()),
        j['sha256'] as String?,
      );
    } on Object {
      return null;
    }
  }

  Future<void> _forget() async {
    try {
      await _store?.delete(storageKey);
    } on Object {
      // Best effort.
    }
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    _deadline = null;
    _hash = null;
  }

  void dispose() => _timer?.cancel();
}
