/// ============================================================
/// VAULT SECURITY PROVIDERS — Security dashboard data (screen 22)
/// ============================================================
///
/// * [vaultActiveRecordsProvider] — every active vault item (live).
/// * [securityReportProvider]     — the report: tiles, score, issues. Weak
///   items are decrypted in memory only to say *why* they are weak; the
///   rest is metadata. Large vaults are scored in a background isolate.
/// * [vaultSecurityStoreProvider] — last scan time + score snapshots.
/// * [vaultScanProvider]          — rescans (local + opt-in HIBP range
///   checks: only 5-char SHA-1 prefixes leave the device), the "Last scan"
///   time and the weekly score delta.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/crypto/breach_check.dart';
import 'package:focusflow/features/vault/data/datasource/vault_security_store.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/repository/vault_repository.dart';
import 'package:focusflow/features/vault/domain/services/vault_payload_codec.dart';
import 'package:focusflow/features/vault/domain/services/vault_security_report.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

final vaultActiveRecordsProvider =
    StreamProvider.autoDispose<List<VaultItemRecord>>(
      (ref) =>
          ref.watch(vaultRepositoryProvider).watchItems(const VaultQuery()),
    );

/// Vaults larger than this are scored off the UI isolate.
const int _isolateThreshold = 300;

final securityReportProvider = FutureProvider.autoDispose<VaultSecurityReport>((
  ref,
) async {
  final records = await ref.watch(vaultActiveRecordsProvider.future);
  final key = ref.watch(vaultSessionProvider.select((s) => s.key));
  // The weak-password reasons are worded here: recompute on a language switch.
  ref.watch(settingsProvider.select((s) => s.languageCode));
  final now = ref.read(clockProvider).now();
  final reasons = <String, String>{};
  if (key != null && !key.isDestroyed) {
    for (final r in records) {
      if (!r.isWeak || r.isBreached) continue;
      try {
        final p = await VaultPayloadCodec.open(
          key,
          r.encryptedPayload,
          itemId: r.id,
        );
        if (p.password.isNotEmpty) {
          reasons[r.id] = describeWeakPassword(p.password);
        }
      } on Object {
        // Undecryptable — the generic reason is used.
      }
    }
  }
  if (records.length < _isolateThreshold) {
    return VaultSecurityReport.compute(records, now, weakReasons: reasons);
  }
  return compute(
    (_) => VaultSecurityReport.compute(records, now, weakReasons: reasons),
    null,
  );
});

final vaultSecurityStoreProvider = Provider<VaultSecurityStore>(
  (ref) => VaultSecurityStore(ref.watch(sharedPreferencesProvider)),
);

/// Dashboard scan status.
@immutable
class VaultScanState {
  const VaultScanState({
    this.lastScanAt,
    this.scanning = false,
    this.weekAgoScore,
  });

  final DateTime? lastScanAt;
  final bool scanning;

  /// Score snapshot from a week or more ago (for "+6 since last week").
  final int? weekAgoScore;

  VaultScanState copyWith({
    DateTime? lastScanAt,
    bool? scanning,
    int? weekAgoScore,
  }) => VaultScanState(
    lastScanAt: lastScanAt ?? this.lastScanAt,
    scanning: scanning ?? this.scanning,
    weekAgoScore: weekAgoScore ?? this.weekAgoScore,
  );
}

/// Result of a rescan.
enum VaultScanResult { done, offline, locked }

class VaultScanController extends AutoDisposeNotifier<VaultScanState> {
  VaultSecurityStore get _store => ref.read(vaultSecurityStoreProvider);
  DateTime _now() => ref.read(clockProvider).now();

  @override
  VaultScanState build() {
    // Every computed score becomes today's snapshot.
    ref.listen(securityReportProvider, (_, next) {
      final report = next.valueOrNull;
      if (report != null && !report.isEmpty) {
        unawaited(_store.recordScore(_now(), report.score));
      }
    });
    return VaultScanState(
      lastScanAt: _store.lastScanAt,
      weekAgoScore: _store.scoreWeekBefore(_now()),
    );
  }

  /// Rescans when the last scan is older than [maxAge] (dashboard open).
  Future<void> scanIfDue({Duration maxAge = const Duration(hours: 24)}) async {
    final last = state.lastScanAt;
    if (last != null && _now().difference(last) < maxAge) return;
    await rescan();
  }

  /// Re-reads the report and, with breach monitoring on, checks every
  /// password against HIBP (k-anonymity). Stops at the first network
  /// error (→ [VaultScanResult.offline]); cached results stay.
  Future<VaultScanResult> rescan() async {
    if (state.scanning) return VaultScanResult.done;
    final session = ref.read(vaultSessionProvider);
    final key = session.key;
    if (key == null || key.isDestroyed) return VaultScanResult.locked;
    state = state.copyWith(scanning: true);
    var result = VaultScanResult.done;
    try {
      if (ref.read(settingsProvider).breachMonitoring) {
        result = await _checkBreaches();
      }
      final at = _now();
      await _store.setLastScanAt(at);
      ref.invalidate(securityReportProvider);
      state = state.copyWith(lastScanAt: at, scanning: false);
    } on Object {
      state = state.copyWith(scanning: false);
      rethrow;
    }
    return result;
  }

  Future<VaultScanResult> _checkBreaches() async {
    final repo = ref.read(vaultRepositoryProvider);
    final checker = ref.read(breachCheckerProvider);
    final records = await repo.watchItems(const VaultQuery()).first;
    // Reused passwords share a fingerprint: ask HIBP once per distinct one.
    // (No session.touch() here — a background scan is not user activity.)
    final counts = <String, int>{};
    for (final r in records) {
      if (r.passwordStrength == null) continue;
      final fp = r.passwordFingerprint;
      final cached = fp == null ? null : counts[fp];
      if (cached != null) {
        await repo.updateBreachResult(r.id, cached, _now());
        continue;
      }
      final key = ref.read(vaultSessionProvider).key;
      if (key == null || key.isDestroyed) return VaultScanResult.locked;
      final String password;
      try {
        password = (await VaultPayloadCodec.open(
          key,
          r.encryptedPayload,
          itemId: r.id,
        )).password;
      } on Object {
        continue;
      }
      if (password.isEmpty) continue;
      try {
        final count = await checker.breachCount(password);
        if (fp != null) counts[fp] = count;
        await repo.updateBreachResult(r.id, count, _now());
      } on BreachCheckException {
        return VaultScanResult.offline;
      }
    }
    return VaultScanResult.done;
  }
}

final vaultScanProvider =
    NotifierProvider.autoDispose<VaultScanController, VaultScanState>(
      VaultScanController.new,
    );
