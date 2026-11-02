/// ============================================================
/// VAULT LIST PROVIDERS — live list data for screens 17 / 18
/// ============================================================
///
/// * [vaultQueryProvider]   — the list's filter (type tile, folder chip,
///   favourites, search text, sort).
/// * [vaultRecordsProvider] — live ciphertext records from the repository.
/// * [vaultListProvider]    — rows for the list: the record + its
///   decrypted *subtitle and expiry date only* (username / masked card /
///   SSID; the earliest document date) + status badge. Passwords are
///   decrypted on demand by the copy action, never here. Watches the session
///   key, so locking drops every plaintext.
/// * [vaultCountsProvider], [vaultFoldersProvider], [vaultBreachedProvider],
///   [vaultReusedFingerprintsProvider] — header / tiles / banner / badges.
/// * [vaultAutoLockRemainingProvider] — the "auto-locks in 4:59" countdown.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/crypto/vault_key.dart';
import 'package:focusflow/core/items/folder.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_schema.dart';
import 'package:focusflow/features/vault/domain/entities/vault_payload.dart';
import 'package:focusflow/features/vault/domain/repository/vault_repository.dart';
import 'package:focusflow/features/vault/domain/services/vault_payload_codec.dart';
import 'package:focusflow/features/vault/domain/services/vault_validators.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Status badge of a list row (screen 18).
enum VaultBadge { strong, fair, weak, reused, breached, expired, expiring }

/// One row of the vault list.
@immutable
class VaultListEntry {
  const VaultListEntry({
    required this.record,
    required this.subtitle,
    this.badge,
    this.expiry,
  });

  final VaultItemRecord record;

  /// Username / masked card number / network name — never a secret.
  final String subtitle;
  final VaultBadge? badge;

  /// The earliest document / card date (`yyyy-MM-dd`), null when none.
  final String? expiry;

  @override
  String toString() => 'VaultListEntry(${record.id})';
}

/// Badge for [record]: breached > expired > reused > expiring > weak / fair /
/// strong; null when the item has no password and nothing to flag (notes,
/// a card that is not near its date). [expiry] is the status of its
/// earliest document date.
VaultBadge? vaultBadgeFor(
  VaultItemRecord record,
  Set<String> reused, {
  VaultExpiryStatus? expiry,
}) {
  if (record.isBreached) return VaultBadge.breached;
  if (expiry == VaultExpiryStatus.expired) return VaultBadge.expired;
  final fp = record.passwordFingerprint;
  if (fp != null && reused.contains(fp)) return VaultBadge.reused;
  if (expiry == VaultExpiryStatus.soon) return VaultBadge.expiring;
  final s = record.passwordStrength;
  if (s == null) return null;
  if (s <= 1) return VaultBadge.weak;
  if (s == 2) return VaultBadge.fair;
  return VaultBadge.strong;
}

// ───────────────────────────── Filter ─────────────────────────────

class VaultQueryController extends AutoDisposeNotifier<VaultQuery> {
  @override
  VaultQuery build() => const VaultQuery();

  VaultQuery _with({
    Object? type = _keep,
    Object? folderId = _keep,
    bool? favouritesOnly,
    String? text,
    VaultSort? sort,
  }) => VaultQuery(
    type: identical(type, _keep) ? state.type : type as VaultItemType?,
    folderId: identical(folderId, _keep) ? state.folderId : folderId as String?,
    favouritesOnly: favouritesOnly ?? state.favouritesOnly,
    text: text ?? state.text,
    sort: sort ?? state.sort,
  );

  void setText(String text) => state = _with(text: text.trim());

  /// Category tile: selects [type], or clears it when already selected.
  void toggleType(VaultItemType type) =>
      state = _with(type: state.type == type ? null : type);

  /// "All" chip: clears folder + favourites (keeps type / text / sort).
  void showAll() => state = _with(folderId: null, favouritesOnly: false);

  void showFavourites() => state = _with(folderId: null, favouritesOnly: true);

  void showFolder(String folderId) =>
      state = _with(folderId: folderId, favouritesOnly: false);

  void setSort(VaultSort sort) => state = _with(sort: sort);

  void toggleSort() =>
      setSort(state.sort == VaultSort.az ? VaultSort.recent : VaultSort.az);
}

const Object _keep = Object();

/// Filter of the Vault tab's list.
final vaultQueryProvider =
    NotifierProvider.autoDispose<VaultQueryController, VaultQuery>(
      VaultQueryController.new,
    );

// ───────────────────────────── Data ─────────────────────────────

/// Live records for [query] (ciphertext; titles are plaintext).
final vaultRecordsProvider = StreamProvider.autoDispose
    .family<List<VaultItemRecord>, VaultQuery>(
      (ref, query) => ref.watch(vaultRepositoryProvider).watchItems(query),
    );

/// Vault totals (header "24 items", tiles, "All 24", breach banner).
final vaultCountsProvider = StreamProvider.autoDispose<VaultCounts>(
  (ref) => ref.watch(vaultRepositoryProvider).watchCounts(),
);

/// Vault folders (Work · Personal · Finance chips).
final vaultFoldersProvider = StreamProvider.autoDispose<List<Folder>>(
  (ref) => ref.watch(foldersRepositoryProvider).watchFolders(ItemType.vault),
);

/// Fingerprints used by more than one active item (REUSED badge).
final vaultReusedFingerprintsProvider = Provider.autoDispose<Set<String>>((
  ref,
) {
  final all = ref.watch(vaultRecordsProvider(const VaultQuery())).valueOrNull;
  if (all == null) return const {};
  final seen = <String>{};
  final reused = <String>{};
  for (final r in all) {
    final fp = r.passwordFingerprint;
    if (fp == null || fp.isEmpty) continue;
    if (!seen.add(fp)) reused.add(fp);
  }
  return reused;
});

/// Active items with a known breach (banner "Fix now").
final vaultBreachedProvider = Provider.autoDispose<List<VaultItemRecord>>((
  ref,
) {
  final all = ref.watch(vaultRecordsProvider(const VaultQuery())).valueOrNull;
  return [...?all?.where((r) => r.isBreached)];
});

/// Per-session cache of decrypted subtitles, keyed by item id and checked
/// against the exact ciphertext. Rebuilt (emptied) when the key changes,
/// i.e. on every lock / unlock.
/// The two faded tiles under the lock card (screen 17): favourites first,
/// then A–Z. Titles only — nothing is decrypted while locked.
final vaultLockedPreviewProvider = Provider.autoDispose<List<VaultItemRecord>>((
  ref,
) {
  final all = ref.watch(vaultRecordsProvider(const VaultQuery())).valueOrNull;
  if (all == null || all.isEmpty) return const [];
  return [
    ...all.where((r) => r.isFavorite),
    ...all.where((r) => !r.isFavorite),
  ].take(2).toList();
});

/// What a list row shows from the decrypted payload: never a secret.
typedef _RowInfo = ({String subtitle, String? expiry});

/// The earliest date of [p] that can expire: the expiry-flagged fields of a
/// schema type, or the end of a card's MM/YY month. `yyyy-MM-dd` or null.
String? _earliestExpiry(VaultItemRecord r, VaultPayload p) {
  final dates = <DateTime>[];
  if (r.type == VaultItemType.card) {
    final end = VaultDates.cardExpiryEnd(p.cardExpiry);
    if (end != null) dates.add(end);
  } else {
    for (final k in r.type.expiryKeys) {
      final d = VaultDates.tryParse(p.field(k));
      if (d != null) dates.add(d);
    }
  }
  if (dates.isEmpty) return null;
  dates.sort();
  return VaultDates.key(dates.first);
}

class _SubtitleCache {
  final Map<String, (Uint8List, _RowInfo)> _entries = {};

  Future<_RowInfo> info(VaultKey key, VaultItemRecord r) async {
    final hit = _entries[r.id];
    if (hit != null && listEquals(hit.$1, r.encryptedPayload)) return hit.$2;
    _RowInfo value;
    try {
      final payload = await VaultPayloadCodec.open(
        key,
        r.encryptedPayload,
        itemId: r.id,
      );
      value = (
        subtitle: payload.subtitle(r.type),
        expiry: _earliestExpiry(r, payload),
      );
    } on Object {
      // Unreadable blob (other vault / corrupted): show no line.
      value = (subtitle: '', expiry: null);
    }
    _entries[r.id] = (r.encryptedPayload, value);
    return value;
  }
}

final _subtitleCacheProvider = Provider.autoDispose<_SubtitleCache>((ref) {
  ref.watch(vaultSessionProvider.select((s) => s.key));
  return _SubtitleCache();
});

/// Rows of the vault list for [query]; empty while locked.
final vaultListProvider = FutureProvider.autoDispose
    .family<List<VaultListEntry>, VaultQuery>((ref, query) async {
      final key = ref.watch(vaultSessionProvider.select((s) => s.key));
      // Search also matches the shown subtitle (username / SSID), which
      // only exists decrypted: fetch without the SQL title filter and
      // match title + subtitle here. Secrets are still never searched.
      final needle = query.text.trim().toLowerCase();
      final records = await ref.watch(
        vaultRecordsProvider(
          needle.isEmpty
              ? query
              : VaultQuery(
                  type: query.type,
                  folderId: query.folderId,
                  favouritesOnly: query.favouritesOnly,
                  sort: query.sort,
                ),
        ).future,
      );
      if (key == null || key.isDestroyed) return const [];
      final reused = ref.watch(vaultReusedFingerprintsProvider);
      final cache = ref.watch(_subtitleCacheProvider);
      final now = ref.watch(clockProvider).now();
      final entries = <VaultListEntry>[];
      for (final r in records) {
        final info = await cache.info(key, r);
        final subtitle = info.subtitle;
        if (needle.isNotEmpty &&
            !r.title.toLowerCase().contains(needle) &&
            !subtitle.toLowerCase().contains(needle)) {
          continue;
        }
        final expiry = info.expiry;
        entries.add(
          VaultListEntry(
            record: r,
            subtitle: subtitle,
            expiry: expiry,
            badge: vaultBadgeFor(
              r,
              reused,
              expiry: expiry == null ? null : VaultDates.status(expiry, now),
            ),
          ),
        );
      }
      return entries;
    });

// ───────────────────────────── Auto-lock ─────────────────────────────

/// Time left before the idle auto-lock, ticking every second (null = the
/// vault is locked or auto-lock is off). Activity resets it because the
/// session's deadline moves on every touch.
final vaultAutoLockRemainingProvider = StreamProvider.autoDispose<Duration?>((
  ref,
) {
  ref.watch(vaultSessionProvider.select((s) => s.isUnlocked));
  ref.watch(settingsProvider.select((s) => s.vaultAutoLockMinutes));
  final session = ref.watch(vaultSessionProvider.notifier);
  final clock = ref.watch(clockProvider);

  Duration? remaining() {
    final deadline = session.autoLockDeadline;
    if (deadline == null) return null;
    final left = deadline.difference(clock.now());
    return left.isNegative ? Duration.zero : left;
  }

  return Stream<Duration?>.multi((sink) {
    sink.add(remaining());
    final timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => sink.add(remaining()),
    );
    sink.onCancel = timer.cancel;
  });
});

/// "4:59" (m:ss).
String formatCountdown(Duration d) {
  final total = d.inSeconds;
  final m = total ~/ 60;
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
