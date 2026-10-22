/// ============================================================
/// VAULT ITEM PROVIDERS — one item, decrypted on demand (screens 19 / 20)
/// ============================================================
///
/// * [vaultItemServiceProvider]  — seal + metadata + history on save.
/// * [vaultItemRecordProvider]   — the live ciphertext record (any state).
/// * [vaultItemPayloadProvider]  — its payload decrypted in memory with the
///   open session key; null while locked (re-runs on unlock / edit).
/// * [vaultHistoryProvider]      — previous passwords (still encrypted).
/// * [vaultItemHealthProvider]   — the "Security health" card.
/// * [vaultTotpConfigProvider]   — the item's 2FA secret, parsed
///   ([VaultTotpCode.at] gives the code + seconds left at a time).
/// * [vaultRevealProvider]       — which secret fields are unmasked (4 s).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/crypto/totp.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';
import 'package:focusflow/features/vault/domain/services/vault_health.dart';
import 'package:focusflow/features/vault/domain/services/vault_item_service.dart';
import 'package:focusflow/features/vault/domain/services/vault_payload_codec.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_list_providers.dart';
import 'package:focusflow/features/vault/presentation/vault_auto_hide.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

final vaultItemServiceProvider = Provider<VaultItemService>((ref) {
  final clock = ref.watch(clockProvider);
  return VaultItemService(ref.watch(vaultRepositoryProvider), clock.now);
});

/// The stored record (null once it is gone for good).
final vaultItemRecordProvider = StreamProvider.autoDispose
    .family<VaultItemRecord?, String>(
      (ref, id) => ref.watch(vaultRepositoryProvider).watchItem(id),
    );

/// [id]'s payload, decrypted with the open key. Null while the vault is
/// locked, when the item is gone or when the blob cannot be opened.
final vaultItemPayloadProvider = FutureProvider.autoDispose
    .family<VaultPayload?, String>((ref, id) async {
      final key = ref.watch(vaultSessionProvider.select((s) => s.key));
      final blob = ref.watch(
        vaultItemRecordProvider(
          id,
        ).select((r) => r.valueOrNull?.encryptedPayload),
      );
      if (key == null || key.isDestroyed || blob == null) return null;
      try {
        return await VaultPayloadCodec.open(key, blob, itemId: id);
      } on Object {
        return null;
      }
    });

/// Previous passwords of [id], newest first (encrypted).
final vaultHistoryProvider = StreamProvider.autoDispose
    .family<List<VaultHistoryEntry>, String>(
      (ref, id) => ref.watch(vaultRepositoryProvider).watchHistory(id),
    );

/// Security health of [id]'s password (null: no password / locked).
final vaultItemHealthProvider = Provider.autoDispose
    .family<VaultHealth?, String>((ref, id) {
      final record = ref.watch(vaultItemRecordProvider(id)).valueOrNull;
      final payload = ref.watch(vaultItemPayloadProvider(id)).valueOrNull;
      if (record == null || payload == null || payload.password.isEmpty) {
        return null;
      }
      final reused = ref.watch(vaultReusedFingerprintsProvider);
      // The ratings are worded here: recompute on a language switch.
      ref.watch(settingsProvider.select((s) => s.languageCode));
      return VaultHealth.of(
        password: payload.password,
        breachCount: record.breachCount,
        reused: reused.contains(record.passwordFingerprint),
        hasTotp: record.hasTotp,
      );
    });

/// The current one-time code.
@immutable
class VaultTotpCode {
  const VaultTotpCode({
    required this.code,
    required this.secondsLeft,
    required this.period,
  });

  /// Grouped for display ("482 913").
  final String code;
  final int secondsLeft;
  final int period;

  /// The code valid at [now].
  factory VaultTotpCode.at(TotpConfig config, DateTime now) => VaultTotpCode(
    code: TotpConfig.format(config.codeAt(now)),
    secondsLeft: config.secondsRemaining(now),
    period: config.period,
  );

  /// The raw digits (what gets copied).
  String get digits => code.replaceAll(' ', '');

  @override
  bool operator ==(Object other) =>
      other is VaultTotpCode &&
      other.code == code &&
      other.secondsLeft == secondsLeft &&
      other.period == period;

  @override
  int get hashCode => Object.hash(code, secondsLeft, period);
}

/// [id]'s 2FA configuration (null: no / invalid secret). The detail row
/// re-computes the code every second with [VaultTotpCode.at].
final vaultTotpConfigProvider = Provider.autoDispose
    .family<TotpConfig?, String>((ref, id) {
      final secret = ref.watch(
        vaultItemPayloadProvider(id).select((p) => p.valueOrNull?.totpSecret),
      );
      return secret == null ? null : TotpConfig.parse(secret);
    });

/// Fields of one item that are currently unmasked ("password", "cvv",
/// "pin", "cf3" …). Each hides itself again after
/// [VaultAutoHide.defaultDuration] (4 s); all clear when the vault locks.
class VaultRevealController
    extends AutoDisposeFamilyNotifier<Set<String>, String> {
  late VaultAutoHide<String> _auto;

  @override
  Set<String> build(String id) {
    ref.watch(vaultSessionProvider.select((s) => s.isUnlocked));
    // A fresh helper per build: a lock / unlock rebuilds this notifier, and
    // the old timers must not hide (or notify) anything afterwards.
    _auto = VaultAutoHide<String>(onChanged: () => state = _auto.shown);
    ref.onDispose(_auto.dispose);
    return const {};
  }

  bool isShown(String field) => state.contains(field);

  /// How often [field] was revealed — restarts the eye's countdown ring.
  int cycleOf(String field) => _auto.cycleOf(field);

  void toggle(String field) => _auto.toggle(field);

  void hideAll() => _auto.hideAll();
}

final vaultRevealProvider = NotifierProvider.autoDispose
    .family<VaultRevealController, Set<String>, String>(
      VaultRevealController.new,
    );
