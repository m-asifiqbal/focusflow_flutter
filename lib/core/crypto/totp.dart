/// ============================================================
/// TOTP — RFC 6238 one-time codes for vault logins (package:otp)
/// ============================================================
///
/// A login's TOTP secret lives only inside its encrypted payload. This
/// file turns that secret (raw base32 or an `otpauth://totp/…` URI as
/// shown by a QR code) into a [TotpConfig] and computes the current code
/// plus the seconds left in the period for the ring on screen 19.
/// Defaults follow Google Authenticator: SHA-1, 6 digits, 30 s.
/// Nothing here logs the secret; [TotpConfig.toString] is redacted.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/crypto/crypto_bytes.dart';
import 'package:otp/otp.dart';

enum TotpAlgorithm { sha1, sha256, sha512 }

@immutable
class TotpConfig {
  const TotpConfig({
    required this.secret,
    this.digits = 6,
    this.period = 30,
    this.algorithm = TotpAlgorithm.sha1,
    this.issuer,
    this.account,
  });

  /// Normalised base32 secret (upper-case, no spaces or padding).
  final String secret;
  final int digits;
  final int period;
  final TotpAlgorithm algorithm;
  final String? issuer;
  final String? account;

  /// Parses a base32 secret or an `otpauth://totp/Issuer:acct?secret=…`
  /// URI. Returns null when [input] is not a usable TOTP secret.
  static TotpConfig? parse(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    if (text.toLowerCase().startsWith('otpauth://')) return _parseUri(text);
    final secret = normaliseSecret(text);
    return secret == null ? null : TotpConfig(secret: secret);
  }

  static TotpConfig? _parseUri(String text) {
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.toLowerCase() != 'totp') return null;
    final q = uri.queryParameters;
    final secret = normaliseSecret(q['secret'] ?? '');
    if (secret == null) return null;
    final label = Uri.decodeComponent(
      uri.path.startsWith('/') ? uri.path.substring(1) : uri.path,
    );
    final colon = label.indexOf(':');
    final digits = int.tryParse(q['digits'] ?? '') ?? 6;
    final period = int.tryParse(q['period'] ?? '') ?? 30;
    return TotpConfig(
      secret: secret,
      // RFC 6238 allows 6–8 digits (7 is used by e.g. some banks).
      digits: digits >= 6 && digits <= 8 ? digits : 6,
      period: period > 0 && period <= 300 ? period : 30,
      algorithm: switch ((q['algorithm'] ?? '').toUpperCase()) {
        'SHA256' => TotpAlgorithm.sha256,
        'SHA512' => TotpAlgorithm.sha512,
        _ => TotpAlgorithm.sha1,
      },
      issuer: q['issuer'] ?? (colon > 0 ? label.substring(0, colon) : null),
      account: colon > 0 ? label.substring(colon + 1).trim() : label,
    );
  }

  /// Upper-cases and strips spaces / dashes / padding; null when [raw] is
  /// not base32 or decodes to fewer than 10 bytes (80 bits, RFC 4226 min).
  static String? normaliseSecret(String raw) {
    final clean = raw.toUpperCase().replaceAll(RegExp(r'[\s\-=]'), '');
    if (clean.isEmpty) return null;
    try {
      if (CryptoBytes.fromBase32(clean).length < 10) return null;
    } on FormatException {
      return null;
    }
    return clean;
  }

  /// The code valid at [now] (zero-padded to [digits]).
  String codeAt(DateTime now) => OTP.generateTOTPCodeString(
    secret,
    now.millisecondsSinceEpoch,
    length: digits,
    interval: period,
    algorithm: switch (algorithm) {
      TotpAlgorithm.sha1 => Algorithm.SHA1,
      TotpAlgorithm.sha256 => Algorithm.SHA256,
      TotpAlgorithm.sha512 => Algorithm.SHA512,
    },
    isGoogle: true,
  );

  /// Whole seconds until the code changes (1…[period]).
  int secondsRemaining(DateTime now) =>
      period - (now.millisecondsSinceEpoch ~/ 1000) % period;

  /// "123 456" / "123 4567" / "1234 5678" — the grouping shown in the UI.
  static String format(String code) => switch (code.length) {
    6 || 7 => '${code.substring(0, 3)} ${code.substring(3)}',
    8 => '${code.substring(0, 4)} ${code.substring(4)}',
    _ => code,
  };

  @override
  bool operator ==(Object other) =>
      other is TotpConfig &&
      other.secret == secret &&
      other.digits == digits &&
      other.period == period &&
      other.algorithm == algorithm;

  @override
  int get hashCode => Object.hash(secret, digits, period, algorithm);

  @override
  String toString() => 'TotpConfig(<redacted>, $digits digits, ${period}s)';
}
