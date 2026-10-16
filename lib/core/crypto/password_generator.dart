/// ============================================================
/// PASSWORD GENERATOR — passwords, EFF passphrases and PINs (screen 21)
/// ============================================================
///
/// Every character / word / digit is drawn from [Random.secure] (the
/// platform CSPRNG). `Random.nextInt` is unbiased, so each symbol of the
/// pool is equally likely and the entropy is exactly
/// `count × log2(pool size)`:
///
/// * Password — length 8–64 over the enabled classes (upper, lower,
///   digits, symbols), optionally without look-alikes (`Il1O0o` …). The
///   result always contains at least one character of every enabled class
///   (re-drawn until it does — rejection sampling keeps the remaining
///   strings uniformly likely; the entropy figure ignores the tiny loss).
/// * Passphrase — 3–10 words from the EFF large wordlist (7,776 words =
///   12.9 bits each), a separator, optional capitalisation and an optional
///   random digit appended to one word (+ log2(10 × words) bits).
/// * PIN — 4–12 random digits (3.32 bits each).
///
/// Generated values are never logged or stored here; the generator
/// history (vault feature) keeps them encrypted.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

enum GeneratorMode { password, passphrase, pin }

@immutable
class PasswordOptions {
  const PasswordOptions({
    this.length = 20,
    this.upper = true,
    this.lower = true,
    this.digits = true,
    this.symbols = true,
    this.avoidAmbiguous = false,
  });

  static const int minLength = 8;
  static const int maxLength = 64;

  final int length;
  final bool upper;
  final bool lower;
  final bool digits;
  final bool symbols;
  final bool avoidAmbiguous;

  PasswordOptions copyWith({
    int? length,
    bool? upper,
    bool? lower,
    bool? digits,
    bool? symbols,
    bool? avoidAmbiguous,
  }) => PasswordOptions(
    length: length ?? this.length,
    upper: upper ?? this.upper,
    lower: lower ?? this.lower,
    digits: digits ?? this.digits,
    symbols: symbols ?? this.symbols,
    avoidAmbiguous: avoidAmbiguous ?? this.avoidAmbiguous,
  );

  @override
  bool operator ==(Object other) =>
      other is PasswordOptions &&
      other.length == length &&
      other.upper == upper &&
      other.lower == lower &&
      other.digits == digits &&
      other.symbols == symbols &&
      other.avoidAmbiguous == avoidAmbiguous;

  @override
  int get hashCode =>
      Object.hash(length, upper, lower, digits, symbols, avoidAmbiguous);
}

@immutable
class PassphraseOptions {
  const PassphraseOptions({
    this.words = 5,
    this.separator = '-',
    this.capitalize = true,
    this.includeNumber = true,
  });

  static const int minWords = 3;
  static const int maxWords = 10;

  final int words;
  final String separator;
  final bool capitalize;
  final bool includeNumber;

  PassphraseOptions copyWith({
    int? words,
    String? separator,
    bool? capitalize,
    bool? includeNumber,
  }) => PassphraseOptions(
    words: words ?? this.words,
    separator: separator ?? this.separator,
    capitalize: capitalize ?? this.capitalize,
    includeNumber: includeNumber ?? this.includeNumber,
  );

  @override
  bool operator ==(Object other) =>
      other is PassphraseOptions &&
      other.words == words &&
      other.separator == separator &&
      other.capitalize == capitalize &&
      other.includeNumber == includeNumber;

  @override
  int get hashCode => Object.hash(words, separator, capitalize, includeNumber);
}

/// A generated value and its exact entropy.
@immutable
class GeneratedValue {
  const GeneratedValue(this.value, this.entropyBits, this.mode);

  final String value;
  final double entropyBits;
  final GeneratorMode mode;

  @override
  String toString() => 'GeneratedValue(<redacted>, $entropyBits bits)';
}

/// The EFF large wordlist (`assets/wordlists/eff_large_wordlist.txt`,
/// lines `11111<TAB>abacus`).
class EffWordlist {
  EffWordlist(List<String> words) : words = List.unmodifiable(words);

  static const String assetPath = 'assets/wordlists/eff_large_wordlist.txt';

  final List<String> words;

  /// Parses the dice-numbered file format (plain one-word lines work too).
  static EffWordlist parse(String text) => EffWordlist([
    for (final line in text.split('\n'))
      if (line.trim().isNotEmpty) line.trim().split(RegExp(r'\s+')).last,
  ]);

  static Future<EffWordlist>? _cached;

  /// Loads (once) from the asset bundle.
  static Future<EffWordlist> load() =>
      _cached ??= rootBundle.loadString(assetPath).then(parse);
}

class PasswordGenerator {
  PasswordGenerator([math.Random? random])
    : _rng = random ?? math.Random.secure();

  final math.Random _rng;

  static const String upperChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String lowerChars = 'abcdefghijklmnopqrstuvwxyz';
  static const String digitChars = '0123456789';
  static const String symbolChars = r'!@#$%^&*()-_=+[]{};:,.<>/?~';

  /// Look-alikes removed by "Avoid ambiguous".
  static const String ambiguousChars =
      r'Il1O0o|`'
      "'"
      '"';

  static String _strip(String pool, bool avoid) => avoid
      ? pool.split('').where((c) => !ambiguousChars.contains(c)).join()
      : pool;

  static List<String> _classes(PasswordOptions o) => [
    if (o.upper) _strip(upperChars, o.avoidAmbiguous),
    if (o.lower) _strip(lowerChars, o.avoidAmbiguous),
    if (o.digits) _strip(digitChars, o.avoidAmbiguous),
    if (o.symbols) _strip(symbolChars, o.avoidAmbiguous),
  ];

  /// Entropy of a password with [o] (0 when no class is enabled).
  static double passwordEntropy(PasswordOptions o) {
    final pool = _classes(o).fold<int>(0, (n, c) => n + c.length);
    return pool == 0 ? 0 : o.length * math.log(pool) / math.ln2;
  }

  /// Entropy of a passphrase with [o] over a list of [listSize] words.
  static double passphraseEntropy(PassphraseOptions o, int listSize) {
    var bits = o.words * math.log(listSize) / math.ln2;
    if (o.includeNumber) bits += math.log(10 * o.words) / math.ln2;
    return bits;
  }

  static double pinEntropy(int digits) => digits * math.log(10) / math.ln2;

  /// A random password. Falls back to lower-case when every class is off.
  GeneratedValue password(PasswordOptions options) {
    var o = options;
    if (!o.upper && !o.lower && !o.digits && !o.symbols) {
      o = o.copyWith(lower: true);
    }
    final length = o.length.clamp(
      PasswordOptions.minLength,
      PasswordOptions.maxLength,
    );
    final classes = _classes(o);
    final pool = classes.join();
    String value;
    do {
      final sb = StringBuffer();
      for (var i = 0; i < length; i++) {
        sb.write(pool[_rng.nextInt(pool.length)]);
      }
      value = sb.toString();
    } while (!classes.every((c) => value.split('').any(c.contains)));
    return GeneratedValue(
      value,
      passwordEntropy(o.copyWith(length: length)),
      GeneratorMode.password,
    );
  }

  /// A random passphrase from [list].
  GeneratedValue passphrase(PassphraseOptions o, EffWordlist list) {
    final n = o.words.clamp(
      PassphraseOptions.minWords,
      PassphraseOptions.maxWords,
    );
    final words = <String>[
      for (var i = 0; i < n; i++) list.words[_rng.nextInt(list.words.length)],
    ];
    if (o.capitalize) {
      for (var i = 0; i < n; i++) {
        words[i] = words[i][0].toUpperCase() + words[i].substring(1);
      }
    }
    if (o.includeNumber) {
      final at = _rng.nextInt(n);
      words[at] = '${words[at]}${_rng.nextInt(10)}';
    }
    return GeneratedValue(
      words.join(o.separator),
      passphraseEntropy(o.copyWith(words: n), list.words.length),
      GeneratorMode.passphrase,
    );
  }

  /// A random numeric PIN of [digits] digits (4–12).
  GeneratedValue pin(int digits) {
    final n = digits.clamp(4, 12);
    final sb = StringBuffer();
    for (var i = 0; i < n; i++) {
      sb.write(_rng.nextInt(10));
    }
    return GeneratedValue(sb.toString(), pinEntropy(n), GeneratorMode.pin);
  }
}
