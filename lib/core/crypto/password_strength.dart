/// ============================================================
/// PASSWORD STRENGTH — zxcvbn-style estimate: score 0–4 + time to crack
/// ============================================================
///
/// There is no maintained Dart port of zxcvbn, so this is a compact
/// estimator in the same spirit: instead of trusting `length × log2(pool)`
/// it looks for the patterns people actually use and charges them what an
/// attacker would pay to guess them:
///
/// * common passwords (embedded top list, also with digits/symbols tacked
///   on and simple l33t substitutions) → a few bits;
/// * runs of one character (`aaaa`), sequences (`abcd`, `4321`) and
///   keyboard walks (`qwerty`, `asdf`) → length-of-run bits only;
/// * 4-digit years (`1987`, `2024`) → ~8 bits;
/// * everything else → `log2(character pool)` per character.
///
/// Score thresholds (bits): <28 very weak · <40 weak · <60 fair ·
/// <80 strong · ≥80 very strong. Crack time assumes an offline attacker at
/// 10^10 guesses/s (fast-hash GPU rig) finding it after half the space.
/// Pure Dart, synchronous, and it never stores or logs the password.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/crypto/password_strength_tables.dart';
import 'package:focusflow/core/l10n/tr.dart';

@immutable
class PasswordStrength {
  const PasswordStrength({
    required this.score,
    required this.bits,
    required this.length,
    required this.hasLower,
    required this.hasUpper,
    required this.hasDigit,
    required this.hasSymbol,
    this.isCommon = false,
  });

  static const PasswordStrength empty = PasswordStrength(
    score: 0,
    bits: 0,
    length: 0,
    hasLower: false,
    hasUpper: false,
    hasDigit: false,
    hasSymbol: false,
  );

  /// 0 very weak · 1 weak · 2 fair · 3 strong · 4 very strong.
  final int score;

  /// Estimated guesses as bits (log2).
  final double bits;
  final int length;
  final bool hasLower;
  final bool hasUpper;
  final bool hasDigit;
  final bool hasSymbol;

  /// Found in (or derived from) the common-password list.
  final bool isCommon;

  /// "Very weak" … "Very strong" for [score], in the active language.
  String get label => switch (score) {
    0 => tr('Very weak'),
    1 => tr('Weak'),
    2 => tr('Fair'),
    3 => tr('Strong'),
    _ => tr('Very strong'),
  };

  /// Seconds an offline attacker needs on average.
  double get crackSeconds => math.pow(2, bits) / 2 / 1e10;

  /// Whether [crackTimeLabel] is "instantly". Test this, never the text
  /// (it is translated).
  bool get crackedInstantly => crackSeconds < 1;

  /// "instantly", "3 hours", "centuries".
  String get crackTimeLabel => crackTimeText(crackSeconds);

  /// "Very strong · would take centuries to crack".
  String get summary => length == 0
      ? tr('Enter a password')
      : crackedInstantly
      ? tr('{label} · could be cracked instantly', {'label': label})
      : tr('{label} · would take {time} to crack', {
          'label': label,
          'time': crackTimeLabel,
        });

  /// Short reason for weak passwords: "Only 8 characters, no symbols".
  String get weakReason {
    if (length == 0) return tr('No password set');
    if (isCommon) return tr('A commonly used password');
    final parts = <String>[];
    if (length < 12) parts.add(tr('Only {n} characters', {'n': length}));
    final missing = _missingText();
    if (missing != null) parts.add(missing);
    if (parts.isEmpty) return tr('Easy to guess pattern');
    final text = parts.length == 1
        ? parts.first
        : tr('{first}, {second}', {'first': parts[0], 'second': parts[1]});
    return text[0].toUpperCase() + text.substring(1);
  }

  /// "no symbols or numbers" — one text per combination, because the way
  /// a list is joined ("or") differs between languages.
  String? _missingText() {
    final symbols = !hasSymbol;
    final numbers = !hasDigit;
    final letters = !hasUpper && !hasLower;
    if (symbols && numbers && letters) {
      return tr('no symbols or numbers or letters');
    }
    if (symbols && numbers) return tr('no symbols or numbers');
    if (symbols && letters) return tr('no symbols or letters');
    if (numbers && letters) return tr('no numbers or letters');
    if (symbols) return tr('no symbols');
    if (numbers) return tr('no numbers');
    if (letters) return tr('no letters');
    return null;
  }

  static String crackTimeText(double seconds) {
    if (seconds < 1) return tr('instantly');
    const minute = 60.0, hour = 3600.0, day = 86400.0;
    const month = day * 31, year = day * 365;

    if (seconds < minute) {
      return tr('{count, plural, one {# second} other {# seconds}}', {
        'count': seconds.floor(),
      });
    }
    if (seconds < hour) {
      return tr('{count, plural, one {# minute} other {# minutes}}', {
        'count': (seconds / minute).floor(),
      });
    }
    if (seconds < day) {
      return tr('{count, plural, one {# hour} other {# hours}}', {
        'count': (seconds / hour).floor(),
      });
    }
    if (seconds < month) {
      return tr('{count, plural, one {# day} other {# days}}', {
        'count': (seconds / day).floor(),
      });
    }
    if (seconds < year) {
      return tr('{count, plural, one {# month} other {# months}}', {
        'count': (seconds / month).floor(),
      });
    }
    if (seconds < year * 100) {
      return tr('{count, plural, one {# year} other {# years}}', {
        'count': (seconds / year).floor(),
      });
    }
    return tr('centuries');
  }

  /// Score for a known entropy (generator output).
  static int scoreForBits(double bits) {
    if (bits < 28) return 0;
    if (bits < 40) return 1;
    if (bits < 60) return 2;
    if (bits < 80) return 3;
    return 4;
  }
}

abstract final class PasswordStrengthEstimator {
  static const String symbols = r'''!@#$%^&*()-_=+[]{};:'",.<>/?\|`~''';

  static PasswordStrength estimate(String password) {
    if (password.isEmpty) return PasswordStrength.empty;
    final chars = password.runes.map(String.fromCharCode).toList();
    final hasLower = chars.any((c) => _lower.hasMatch(c));
    final hasUpper = chars.any((c) => _upper.hasMatch(c));
    final hasDigit = chars.any((c) => _digit.hasMatch(c));
    final hasSymbol = chars.any((c) => symbols.contains(c));
    final hasOther = chars.any(
      (c) =>
          !_lower.hasMatch(c) &&
          !_upper.hasMatch(c) &&
          !_digit.hasMatch(c) &&
          !symbols.contains(c),
    );
    final pool =
        (hasLower ? 26 : 0) +
        (hasUpper ? 26 : 0) +
        (hasDigit ? 10 : 0) +
        (hasSymbol ? 33 : 0) +
        (hasOther ? 100 : 0);
    final perChar = _log2(math.max(pool, 2));

    final common = _commonBits(password);
    var bits = _patternBits(chars, perChar);
    if (common != null && common < bits) bits = common;

    return PasswordStrength(
      score: PasswordStrength.scoreForBits(bits),
      bits: bits,
      length: chars.length,
      hasLower: hasLower,
      hasUpper: hasUpper,
      hasDigit: hasDigit,
      hasSymbol: hasSymbol,
      isCommon: common != null && common <= bits,
    );
  }

  static final RegExp _lower = RegExp('[a-z]');
  static final RegExp _upper = RegExp('[A-Z]');
  static final RegExp _digit = RegExp('[0-9]');

  static double _log2(num x) => math.log(x) / math.ln2;

  /// Walks the password, charging pattern runs instead of raw characters.
  static double _patternBits(List<String> chars, double perChar) {
    var bits = 0.0;
    var i = 0;
    while (i < chars.length) {
      final run = _runLength(chars, i);
      if (run >= 3) {
        bits += perChar + _log2(run);
        i += run;
        continue;
      }
      final seq = _sequenceLength(chars, i);
      if (seq >= 3) {
        bits += perChar + _log2(seq) + 1;
        i += seq;
        continue;
      }
      final walk = _keyboardWalkLength(chars, i);
      if (walk >= 4) {
        bits += 6 + _log2(walk);
        i += walk;
        continue;
      }
      if (_isYearAt(chars, i)) {
        bits += 8;
        i += 4;
        continue;
      }
      bits += perChar;
      i++;
    }
    return bits;
  }

  static int _runLength(List<String> c, int start) {
    var n = 1;
    while (start + n < c.length && c[start + n] == c[start]) {
      n++;
    }
    return n;
  }

  static int _sequenceLength(List<String> c, int start) {
    if (start + 1 >= c.length) return 1;
    final a = c[start].codeUnitAt(0), b = c[start + 1].codeUnitAt(0);
    final step = b - a;
    if (step != 1 && step != -1) return 1;
    if (!_sameClass(c[start], c[start + 1])) return 1;
    var n = 2;
    while (start + n < c.length &&
        c[start + n].codeUnitAt(0) - c[start + n - 1].codeUnitAt(0) == step &&
        _sameClass(c[start + n], c[start])) {
      n++;
    }
    return n;
  }

  static bool _sameClass(String a, String b) =>
      (_lower.hasMatch(a) && _lower.hasMatch(b)) ||
      (_upper.hasMatch(a) && _upper.hasMatch(b)) ||
      (_digit.hasMatch(a) && _digit.hasMatch(b));

  static int _keyboardWalkLength(List<String> c, int start) {
    var best = 1;
    final rest = c.sublist(start).join().toLowerCase();
    for (final row in PasswordPatternTables.keyboardRows) {
      for (final r in [row, row.split('').reversed.join()]) {
        for (var len = math.min(rest.length, r.length); len >= 4; len--) {
          if (r.contains(rest.substring(0, len))) {
            if (len > best) best = len;
            break;
          }
        }
      }
    }
    return best;
  }

  static bool _isYearAt(List<String> c, int start) {
    if (start + 4 > c.length) return false;
    final s = c.sublist(start, start + 4).join();
    final y = int.tryParse(s);
    return y != null && y >= 1900 && y <= 2099;
  }

  /// Bits when [password] is (a decorated form of) a common password.
  static double? _commonBits(String password) {
    final lower = password.toLowerCase();
    final unleet = lower
        .replaceAll('@', 'a')
        .replaceAll('4', 'a')
        .replaceAll('3', 'e')
        .replaceAll('1', 'i')
        .replaceAll('!', 'i')
        .replaceAll('0', 'o')
        .replaceAll('\$', 's')
        .replaceAll('5', 's')
        .replaceAll('7', 't');
    final stripped = lower.replaceAll(RegExp(r'[\d\W_]+$'), '');
    final suffix = lower.length - stripped.length;
    for (final (candidate, extra) in [
      (lower, 0.0),
      (unleet, 2.0),
      (stripped, suffix * 3.3 + 1),
    ]) {
      final rank = PasswordPatternTables.commonPasswords.indexOf(candidate);
      if (rank >= 0 && candidate.isNotEmpty) {
        final upperBonus = password != password.toLowerCase() ? 1.0 : 0.0;
        return _log2(rank + 2) + extra + upperBonus;
      }
    }
    return null;
  }
}
