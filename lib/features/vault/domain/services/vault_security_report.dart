/// ============================================================
/// VAULT SECURITY REPORT — the Security dashboard's numbers (screen 22)
/// ============================================================
///
/// Pure Dart over the cached metadata of every active vault item (no
/// plaintext): HIBP result, cached 0–4 strength, HMAC fingerprint (reuse)
/// and password age. Each item with a password is put in exactly one tile:
/// breached > reused > weak (strength ≤ 1) > strong. Issues are listed
/// once per item (reuse once per group of items sharing a password), most
/// severe first; "old" = not changed in a year (or past the item's own
/// expiry). Health score = mean over items of
/// strength 40 % · uniqueness 25 % · not breached 25 % · age 10 %
/// (age fades from full at 1 year to zero at 2 years).
/// [describeWeakPassword] builds "Only 8 characters, no symbols" from a
/// password the caller decrypted in memory.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/crypto/password_strength.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';

enum VaultIssueKind { breached, reused, weak, old }

/// One "Needs attention" row.
@immutable
class VaultIssue {
  const VaultIssue({
    required this.kind,
    required this.itemIds,
    required this.title,
    required this.reason,
  });

  final VaultIssueKind kind;

  /// The item(s) concerned; the first is the one the fix opens.
  final List<String> itemIds;

  /// "LinkedIn" · "Netflix + 2 more".
  final String title;

  /// "Found in a data breach" · "Same password on 3 sites" …
  final String reason;

  String get itemId => itemIds.first;

  @override
  bool operator ==(Object other) =>
      other is VaultIssue &&
      other.kind == kind &&
      listEquals(other.itemIds, itemIds) &&
      other.title == title &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(kind, Object.hashAll(itemIds), title, reason);
}

@immutable
class VaultSecurityReport {
  const VaultSecurityReport({
    required this.score,
    required this.breached,
    required this.reused,
    required this.weak,
    required this.strong,
    required this.passwordItems,
    required this.logins,
    required this.loginsWithTotp,
    required this.issues,
  });

  /// Days after which a password counts as old (unless the item sets its
  /// own expiry).
  static const int oldAfterDays = 365;

  /// 0–100 (100 when there is nothing to rate).
  final int score;
  final int breached;
  final int reused;
  final int weak;
  final int strong;

  /// Items with a password (the tiles add up to this).
  final int passwordItems;

  /// 2FA coverage: logins with a one-time code / all logins.
  final int logins;
  final int loginsWithTotp;
  final List<VaultIssue> issues;

  bool get isEmpty => passwordItems == 0;
  bool get allGood => issues.isEmpty;

  /// Builds the report from active [records] at [now]. [weakReasons]
  /// (item id → text) overrides the generic weak-password reason.
  static VaultSecurityReport compute(
    List<VaultItemRecord> records,
    DateTime now, {
    Map<String, String> weakReasons = const {},
  }) {
    final active = [
      for (final r in records)
        if (r.isActive) r,
    ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final withPassword = [
      for (final r in active)
        if (r.passwordStrength != null) r,
    ];

    // Reuse groups: fingerprints shared by ≥ 2 items.
    final groups = <String, List<VaultItemRecord>>{};
    for (final r in withPassword) {
      final fp = r.passwordFingerprint;
      if (fp != null) (groups[fp] ??= []).add(r);
    }
    groups.removeWhere((_, items) => items.length < 2);
    final reusedIds = {
      for (final g in groups.values)
        for (final r in g) r.id,
    };

    var breached = 0, reused = 0, weak = 0, strong = 0;
    var total = 0.0;
    final breachIssues = <VaultIssue>[];
    final weakIssues = <VaultIssue>[];
    final oldIssues = <VaultIssue>[];
    for (final r in withPassword) {
      final isReused = reusedIds.contains(r.id);
      final age = r.passwordUpdatedAt == null
          ? 0
          : now.difference(r.passwordUpdatedAt!).inDays;
      final isOld =
          r.isExpired(now) || (r.expiryDays == null && age >= oldAfterDays);
      if (r.isBreached) {
        breached++;
        breachIssues.add(
          VaultIssue(
            kind: VaultIssueKind.breached,
            itemIds: [r.id],
            title: r.title,
            reason: breachReason(r.breachCount!),
          ),
        );
      } else if (isReused) {
        reused++;
      } else if (r.isWeak) {
        weak++;
        weakIssues.add(
          VaultIssue(
            kind: VaultIssueKind.weak,
            itemIds: [r.id],
            title: r.title,
            reason: weakReasons[r.id] ?? 'Easy to guess',
          ),
        );
      } else {
        strong++;
        if (isOld) {
          oldIssues.add(
            VaultIssue(
              kind: VaultIssueKind.old,
              itemIds: [r.id],
              title: r.title,
              reason: 'Not changed in $age days',
            ),
          );
        }
      }
      final ageScore = age <= oldAfterDays
          ? 1.0
          : math.max(0, 1 - (age - oldAfterDays) / oldAfterDays);
      total +=
          0.40 * (r.passwordStrength!.clamp(0, 4) / 4) +
          0.25 * (isReused ? 0 : 1) +
          0.25 * (r.isBreached ? 0 : 1) +
          0.10 * ageScore;
    }

    final reuseIssues = <VaultIssue>[];
    for (final g in groups.values) {
      // Breached members are already listed on their own.
      final rest = [
        for (final r in g)
          if (!r.isBreached) r,
      ];
      if (rest.isEmpty) continue;
      reuseIssues.add(
        VaultIssue(
          kind: VaultIssueKind.reused,
          itemIds: [for (final r in rest) r.id],
          title: g.length == 1
              ? rest.first.title
              : '${rest.first.title} + ${g.length - 1} more',
          reason: 'Same password on ${g.length} sites',
        ),
      );
    }
    reuseIssues.sort((a, b) => a.title.compareTo(b.title));

    final logins = [
      for (final r in active)
        if (r.type == VaultItemType.login) r,
    ];
    return VaultSecurityReport(
      score: withPassword.isEmpty
          ? 100
          : (100 * total / withPassword.length).round().clamp(0, 100),
      breached: breached,
      reused: reused,
      weak: weak,
      strong: strong,
      passwordItems: withPassword.length,
      logins: logins.length,
      loginsWithTotp: logins.where((r) => r.hasTotp).length,
      issues: [...breachIssues, ...reuseIssues, ...weakIssues, ...oldIssues],
    );
  }

  static String breachReason(int count) => count == 1
      ? 'Found in a data breach'
      : 'Seen $count times in data breaches';

  @override
  bool operator ==(Object other) =>
      other is VaultSecurityReport &&
      other.score == score &&
      other.breached == breached &&
      other.reused == reused &&
      other.weak == weak &&
      other.strong == strong &&
      other.passwordItems == passwordItems &&
      other.logins == logins &&
      other.loginsWithTotp == loginsWithTotp &&
      listEquals(other.issues, issues);

  @override
  int get hashCode => Object.hash(
    score,
    breached,
    reused,
    weak,
    strong,
    passwordItems,
    logins,
    loginsWithTotp,
    Object.hashAll(issues),
  );
}

/// "Only 8 characters, no symbols" / "A common password" for a weak
/// [password] (measured in memory, never kept).
String describeWeakPassword(String password) {
  final s = PasswordStrengthEstimator.estimate(password);
  if (s.isCommon) return 'A common password';
  final missing = [
    if (!s.hasSymbol) 'no symbols',
    if (!s.hasDigit) 'no numbers',
    if (!s.hasUpper && !s.hasLower) 'no letters',
  ];
  final parts = [
    if (s.length < 12) 'Only ${s.length} characters',
    if (missing.isNotEmpty) missing.first,
  ];
  if (parts.isEmpty) return 'Easy to guess';
  final text = parts.join(', ');
  return text[0].toUpperCase() + text.substring(1);
}
