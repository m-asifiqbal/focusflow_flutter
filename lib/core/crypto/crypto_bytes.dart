/// ============================================================
/// CRYPTO BYTES — secure randomness, encodings, constant-time compare
/// ============================================================
///
/// Tiny helpers shared by the vault crypto. Everything random comes from
/// [Random.secure] (the platform CSPRNG). Nothing here logs.
/// ============================================================
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

abstract final class CryptoBytes {
  static final Random _rng = Random.secure();

  /// [length] bytes from the platform CSPRNG.
  static Uint8List random(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _rng.nextInt(256);
    }
    return out;
  }

  /// Standard base64 (with padding).
  static String toBase64(List<int> bytes) => base64Encode(bytes);

  static Uint8List fromBase64(String text) => base64Decode(text);

  /// Lower-case hex.
  static String toHex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  /// UTF-8 bytes of [text].
  static Uint8List utf8Bytes(String text) =>
      Uint8List.fromList(utf8.encode(text));

  /// Compares two byte lists in time independent of where they differ.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Best-effort zeroing of key material we own (Dart may have copied it;
  /// this only shortens the window in which the bytes sit in memory).
  static void wipe(List<int>? bytes) {
    if (bytes == null) return;
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }

  // ── RFC 4648 base32 (recovery codes, TOTP secrets) ──

  static const String _b32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Base32 without padding.
  static String toBase32(List<int> bytes) {
    final sb = StringBuffer();
    var buffer = 0, bits = 0;
    for (final b in bytes) {
      buffer = (buffer << 8) | b;
      bits += 8;
      while (bits >= 5) {
        sb.write(_b32[(buffer >> (bits - 5)) & 31]);
        bits -= 5;
      }
    }
    if (bits > 0) sb.write(_b32[(buffer << (5 - bits)) & 31]);
    return sb.toString();
  }

  /// Decodes base32 (case-insensitive; spaces, dashes and `=` ignored).
  /// Throws [FormatException] on other characters.
  static Uint8List fromBase32(String text) {
    final clean = text.toUpperCase().replaceAll(RegExp(r'[\s\-=]'), '');
    final out = <int>[];
    var buffer = 0, bits = 0;
    for (final ch in clean.split('')) {
      final v = _b32.indexOf(ch);
      if (v < 0) throw const FormatException('Not a base32 string');
      buffer = (buffer << 5) | v;
      bits += 5;
      if (bits >= 8) {
        out.add((buffer >> (bits - 8)) & 0xFF);
        bits -= 8;
      }
    }
    return Uint8List.fromList(out);
  }
}
