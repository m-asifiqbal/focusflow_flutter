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
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';

enum VaultIssueKind {
  breached,
  reused,
  weak,
  old;

  /// The tag on an issue row ("BREACHED" …), in the active language.
  String get label => switch (this) {
    breached => tr('BREACHED'),
    reused => tr('REUSED'),
    weak => tr('WEAK'),
    old => tr('OLD'),
  };
}

/// One "Needs attention" row.
///
/// [title] and [reason] are getters over plain data (not stored text): the
/// report may be computed in a background isolate, where `tr` has no language
/// pack, so the wording is only produced when the row is shown.
@immutable
class VaultIssue {
  const VaultIssue({
    required this.kind,
    required this.itemIds,
    required this.name,
    this.more = 0,
    this.count = 0,
    this.detail,
  });

  final VaultIssueKind kind;

  /// The item(s) concerned; the first is the one the fix opens.
  final List<String> itemIds;

  /// The (first) item's own title, e.g. "LinkedIn".
  final String name;

  /// How many more items share this row (reuse group), 0 for a single one.
  final int more;

  /// Times seen in breaches · sites sharing the password · days unchanged.
  final int count;

  /// A weak password's own explanation ("Only 8 characters"), already
  /// worded by [describeWeakPassword]; null = the generic reason.
  final String? detail;

  /// "LinkedIn" · "Netflix + 2 more".
  String get title =>
      more == 0 ? name : tr('{title} + {v} more', {'title': name, 'v': more});

  /// "Found in a data breach" · "Same password on 3 sites" …
  String get reason => switch (kind) {
    VaultIssueKind.breached => VaultSecurityReport.breachReason(count),
    VaultIssueKind.reused => tr('Same password on {n} sites', {'n': count}),
    VaultIssueKind.weak => detail ?? tr('Easy to guess'),
    VaultIssueKind.old => tr('Not changed in {n} days', {'n': count}),
  };

  String get itemId => itemIds.first;

  @override
  bool operator ==(Object other) =>
      other is VaultIssue &&
      other.kind == kind &&
      listEquals(other.itemIds, itemIds) &&
      other.name == name &&
      other.more == more &&
      other.count == count &&
      other.detail == detail;

  @override
  int get hashCode =>
      Object.hash(kind, Object.hashAll(itemIds), name, more, count, detail);
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
            name: r.title,
            count: r.breachCount!,
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
            name: r.title,
            detail: weakReasons[r.id],
          ),
        );
      } else {
        strong++;
        if (isOld) {
          oldIssues.add(
            VaultIssue(
              kind: VaultIssueKind.old,
              itemIds: [r.id],
              name: r.title,
              count: age,
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
          name: rest.first.title,
          more: g.length - 1,
          count: g.length,
        ),
      );
    }
    reuseIssues.sort((a, b) {
      final byName = a.name.compareTo(b.name);
      return byName != 0 ? byName : a.more.compareTo(b.more);
    });

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

  static String breachReason(int count) => tr(
    '{count, plural, one {Found in a data breach} other {Seen # times in data breaches}}',
    {'count': count},
  );

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
  if (s.isCommon) return tr('A common password');
  final missing = [
    if (!s.hasSymbol) tr('no symbols'),
    if (!s.hasDigit) tr('no numbers'),
    if (!s.hasUpper && !s.hasLower) tr('no letters'),
  ];
  final parts = [
    if (s.length < 12) tr('Only {n} characters', {'n': s.length}),
    if (missing.isNotEmpty) missing.first,
  ];
  if (parts.isEmpty) return tr('Easy to guess');
  final text = parts.join(', ');
  return text[0].toUpperCase() + text.substring(1);
}
