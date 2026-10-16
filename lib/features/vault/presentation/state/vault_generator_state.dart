/// ============================================================
/// VAULT GENERATOR STATE — options + current value of screen 21
/// ============================================================
///
/// What the Generator tab shows: the mode (password / passphrase / PIN),
/// each mode's options and the value generated from them. The value is a
/// secret held in memory only while the vault is unlocked; [toString]
/// never prints it. [GeneratorStrength] maps entropy bits to the meter.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/crypto/password_generator.dart';

@immutable
class VaultGeneratorState {
  const VaultGeneratorState({
    this.mode = GeneratorMode.password,
    this.password = const PasswordOptions(length: 16),
    this.passphrase = const PassphraseOptions(words: 4),
    this.pinLength = 6,
    this.value,
  });

  static const int minPin = 4;
  static const int maxPin = 12;

  final GeneratorMode mode;
  final PasswordOptions password;
  final PassphraseOptions passphrase;
  final int pinLength;

  /// The current value (null while the wordlist loads or the vault is
  /// locked).
  final GeneratedValue? value;

  VaultGeneratorState copyWith({
    GeneratorMode? mode,
    PasswordOptions? password,
    PassphraseOptions? passphrase,
    int? pinLength,
    GeneratedValue? value,
    bool clearValue = false,
  }) => VaultGeneratorState(
    mode: mode ?? this.mode,
    password: password ?? this.password,
    passphrase: passphrase ?? this.passphrase,
    pinLength: pinLength ?? this.pinLength,
    value: clearValue ? null : (value ?? this.value),
  );

  @override
  bool operator ==(Object other) =>
      other is VaultGeneratorState &&
      other.mode == mode &&
      other.password == password &&
      other.passphrase == passphrase &&
      other.pinLength == pinLength &&
      other.value?.value == value?.value;

  @override
  int get hashCode =>
      Object.hash(mode, password, passphrase, pinLength, value?.value);

  @override
  String toString() => 'VaultGeneratorState($mode, value: <redacted>)';
}

/// Meter level (1–4 bars) and label for an entropy figure.
enum GeneratorStrength {
  weak('Weak', 1),
  fair('Fair', 2),
  strong('Strong', 3),
  veryStrong('Very strong', 4);

  const GeneratorStrength(this.label, this.bars);

  final String label;
  final int bars;

  /// < 40 bits weak · < 60 fair · < 80 strong · ≥ 80 very strong
  /// (offline-attack thresholds for a random secret).
  static GeneratorStrength of(double bits) => bits < 40
      ? weak
      : bits < 60
      ? fair
      : bits < 80
      ? strong
      : veryStrong;
}
