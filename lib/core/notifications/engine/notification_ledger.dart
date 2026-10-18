/// ============================================================
/// NOTIFICATION LEDGER — what the engine handed to the OS
/// ============================================================
///
/// What: one [LedgerEntry] per notification currently scheduled with the
/// OS: its id, plan key, fire time, content fingerprint and the inbox entry
/// it becomes once delivered.
///
/// Why: the OS cannot tell us that a scheduled notification was delivered
/// while the app was not running. On every reconcile, entries whose fire
/// time has passed are "delivered": they become inbox entries (screen 27)
/// and stamp the reminder's `lastFiredAt`. The fingerprint lets the
/// reconciler skip unchanged notifications instead of re-scheduling 60
/// requests on every edit.
///
/// Storage: the ledger holds reminder / habit titles, so it lives in the
/// Keychain / Keystore ([SecureStore]), never in plain preferences. The
/// Keychain survives an iOS reinstall, so the ledger is stamped with the
/// per-install device id (kept in preferences, which do not survive) and a
/// ledger of another install is ignored — its entries would otherwise be
/// "delivered" into the fresh database's inbox.
///
/// Two isolates write it (the app and the background action / maintenance
/// isolate) and there is no cross-isolate lock, so writes are merges, not
/// blind overwrites: [LedgerStore.claimDeliveries] re-reads the ledger and
/// records each delivery once by `key@fireAt` (a delivery claimed by the
/// other isolate is skipped — no duplicate inbox entry), and
/// [LedgerStore.commit] keeps entries the other isolate added since this
/// pass loaded the ledger instead of dropping them.
/// ============================================================
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/storage/secure_store.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';

@immutable
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.key,
    required this.fireAt,
    required this.fingerprint,
    required this.kind,
    required this.title,
    this.body = '',
    this.ref,
    this.actions = const [],
    this.reminderId,
    this.exact = true,
  });

  /// [variant] = delivery options that change the OS copy or its timing
  /// (lock-screen mode, exact vs inexact): part of the fingerprint, so a
  /// settings / permission change re-schedules. [exact] = scheduled as an
  /// exact alarm (Android drops those when the grant is revoked).
  factory LedgerEntry.of(
    PlannedNotification n, {
    String variant = '',
    bool exact = true,
  }) => LedgerEntry(
    id: n.id,
    key: n.key,
    fireAt: n.fireAt,
    fingerprint: variant.isEmpty ? n.fingerprint : '${n.fingerprint}.$variant',
    kind: n.inboxKind,
    title: n.title,
    body: n.body,
    ref: n.inboxRef,
    actions: n.inboxActions,
    reminderId: n.reminderId,
    exact: exact,
  );

  final int id;
  final String key;
  final DateTime fireAt;
  final String fingerprint;

  // The inbox entry it becomes once delivered.
  final InboxKind kind;
  final String title;
  final String body;
  final ItemRef? ref;
  final List<String> actions;
  final String? reminderId;

  /// Scheduled as an exact alarm.
  final bool exact;

  /// Identity of one delivery (a snoozed reminder reuses its key).
  String get deliveryKey => '$key@${fireAt.millisecondsSinceEpoch}';

  Map<String, Object?> toJson() => {
    'i': id,
    'k': key,
    't': fireAt.millisecondsSinceEpoch,
    'f': fingerprint,
    'n': kind.name,
    'ti': title,
    if (body.isNotEmpty) 'b': body,
    if (ref != null) 'r': '${ref!.type.key}/${ref!.id}',
    if (actions.isNotEmpty) 'a': actions,
    if (reminderId != null) 'm': reminderId,
    if (!exact) 'x': 0,
  };

  static LedgerEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['i'], key = j['k'], t = j['t'], f = j['f'], title = j['ti'];
    if (id is! int || key is! String || t is! int || f is! String) {
      return null;
    }
    ItemRef? ref;
    final r = j['r'];
    if (r is String && r.contains('/')) {
      final i = r.indexOf('/');
      final type = ItemType.fromKey(r.substring(0, i));
      if (type != null) ref = ItemRef(type, r.substring(i + 1));
    }
    final a = j['a'];
    return LedgerEntry(
      id: id,
      key: key,
      fireAt: DateTime.fromMillisecondsSinceEpoch(t),
      fingerprint: f,
      kind: InboxKind.fromName(j['n'] as String?),
      title: title is String ? title : '',
      body: j['b'] is String ? j['b'] as String : '',
      ref: ref,
      actions: a is List ? a.whereType<String>().toList() : const [],
      reminderId: j['m'] is String ? j['m'] as String : null,
      exact: j['x'] != 0,
    );
  }
}

/// Everything persisted: the scheduled entries and the recent deliveries
/// (`key@fireAt`, so a delivery is recorded once across isolates).
@immutable
class LedgerState {
  const LedgerState({this.entries = const [], this.delivered = const {}});

  final List<LedgerEntry> entries;
  final Set<String> delivered;
}

/// Persistence of the ledger (Keychain in the app, memory in tests).
abstract class LedgerStore {
  Future<LedgerState> loadState();
  Future<void> saveState(LedgerState state);

  /// Delivery markers older than this (by fire time) are forgotten.
  static const Duration deliveredRetention = Duration(days: 3);

  Future<List<LedgerEntry>> load() async => (await loadState()).entries;

  /// Replaces the entries (keeps the delivery markers).
  Future<void> save(List<LedgerEntry> entries) async {
    final st = await loadState();
    await saveState(LedgerState(entries: entries, delivered: st.delivered));
  }

  /// Takes [shown] out of the ledger and marks them delivered, re-reading
  /// the stored state first. Returns the ones not already claimed (by the
  /// other isolate) — only those may become inbox entries.
  Future<List<LedgerEntry>> claimDeliveries(
    List<LedgerEntry> shown, {
    required DateTime now,
  }) async {
    if (shown.isEmpty) return const [];
    final st = await loadState();
    final claimed = [
      for (final e in shown)
        if (!st.delivered.contains(e.deliveryKey)) e,
    ];
    final gone = {for (final e in shown) e.id};
    final delivered = {
      ..._recent(st.delivered, now),
      for (final e in shown) e.deliveryKey,
    };
    await saveState(
      LedgerState(
        entries: [
          for (final e in st.entries)
            if (!gone.contains(e.id)) e,
        ],
        delivered: delivered,
      ),
    );
    return claimed;
  }

  /// Writes [next] as the ledger after a pass that started from [base]:
  /// entries another isolate added meanwhile (ids in neither list) are
  /// kept, and nothing already delivered is written back.
  Future<void> commit(
    List<LedgerEntry> base,
    List<LedgerEntry> next, {
    required DateTime now,
  }) async {
    final st = await loadState();
    final known = {for (final e in base) e.id, for (final e in next) e.id};
    bool fresh(LedgerEntry e) => !st.delivered.contains(e.deliveryKey);
    await saveState(
      LedgerState(
        entries: [
          for (final e in next)
            if (fresh(e)) e,
          for (final e in st.entries)
            if (!known.contains(e.id) && fresh(e)) e,
        ],
        delivered: _recent(st.delivered, now),
      ),
    );
  }

  static Set<String> _recent(Set<String> delivered, DateTime now) {
    final cutoff = now.subtract(deliveredRetention).millisecondsSinceEpoch;
    return {
      for (final d in delivered)
        if ((int.tryParse(d.substring(d.lastIndexOf('@') + 1)) ?? 0) >= cutoff)
          d,
    };
  }
}

class SecureLedgerStore extends LedgerStore {
  /// [owner] = the per-install device id (null: accept any ledger).
  SecureLedgerStore(this._store, {this.owner});

  static const String storageKey = 'notifications.ledger.v1';

  final SecureStore _store;
  final String? owner;

  /// What the keychain held when this store last read or wrote it. Every
  /// save follows a load (see [LedgerStore.commit] / `claimDeliveries`), so
  /// an unchanged ledger — the common case on a quiet pass — is not
  /// written (and encrypted by the keystore) again.
  String? _lastRaw;

  @override
  Future<LedgerState> loadState() async {
    final raw = await _store.read(storageKey);
    _lastRaw = raw;
    return decodeState(raw, owner: owner);
  }

  @override
  Future<void> saveState(LedgerState state) async {
    final raw = encode(state.entries, owner: owner, delivered: state.delivered);
    if (raw == _lastRaw) return;
    await _store.write(storageKey, raw);
    _lastRaw = raw;
  }

  /// `{"o": owner, "e": [entries], "d": [delivery keys]}`.
  static String encode(
    List<LedgerEntry> entries, {
    String? owner,
    Set<String> delivered = const {},
  }) => jsonEncode({
    'o': ?owner,
    'e': [for (final e in entries) e.toJson()],
    if (delivered.isNotEmpty) 'd': delivered.toList(),
  });

  /// Entries of [raw]; empty when it belongs to another [owner] (a
  /// reinstall) or is malformed. A bare list (first format) is accepted.
  static List<LedgerEntry> decode(String? raw, {String? owner}) =>
      decodeState(raw, owner: owner).entries;

  static LedgerState decodeState(String? raw, {String? owner}) {
    if (raw == null || raw.isEmpty) return const LedgerState();
    try {
      var list = jsonDecode(raw);
      var delivered = const <String>{};
      if (list is Map) {
        final stamp = list['o'];
        if (owner != null && stamp != owner) return const LedgerState();
        final d = list['d'];
        if (d is List) delivered = d.whereType<String>().toSet();
        list = list['e'];
      }
      if (list is! List) return const LedgerState();
      return LedgerState(
        entries: list.map(LedgerEntry.fromJson).nonNulls.toList(),
        delivered: delivered,
      );
    } on FormatException {
      return const LedgerState();
    }
  }
}

class MemoryLedgerStore extends LedgerStore {
  List<LedgerEntry> entries = const [];
  Set<String> delivered = const {};

  @override
  Future<LedgerState> loadState() async =>
      LedgerState(entries: entries, delivered: delivered);

  @override
  Future<void> saveState(LedgerState state) async {
    entries = List.unmodifiable(state.entries);
    delivered = Set.unmodifiable(state.delivered);
  }
}
