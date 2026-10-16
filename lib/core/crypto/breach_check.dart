/// ============================================================
/// BREACH CHECK — opt-in Have I Been Pwned lookup via k-anonymity
/// ============================================================
///
/// Only runs when the user turns on Settings › Vault security › Breach
/// monitoring (or taps "Check now"). The password never leaves the device:
///
///   1. SHA-1(password) → 40 hex chars, upper-case;
///   2. only the first 5 chars (the "prefix") are sent to
///      `https://api.pwnedpasswords.com/range/<prefix>`;
///   3. the service returns every leaked-hash *suffix* with that prefix
///      (hundreds of them, padded with fake zero-count rows thanks to the
///      `Add-Padding` header so even the response size reveals nothing);
///   4. the suffix is matched locally → how many times it was breached.
///
/// No cookies, no API key, no identifiers. The SHA-1 here is HIBP's lookup
/// key, not a stored password hash: it is computed in memory and dropped.
/// Network errors throw [BreachCheckException] so the UI can show "Try
/// again" instead of a false "not breached".
/// ============================================================
library;

import 'dart:convert';

import 'package:crypto/crypto.dart' as hash;
import 'package:http/http.dart' as http;

class BreachCheckException implements Exception {
  const BreachCheckException(this.message);

  final String message;

  @override
  String toString() => 'BreachCheckException: $message';
}

class BreachChecker {
  BreachChecker({
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  static const String endpoint = 'https://api.pwnedpasswords.com/range/';

  final http.Client _client;
  final Duration timeout;

  /// Upper-case SHA-1 hex of [password].
  static String sha1Hex(String password) =>
      hash.sha1.convert(utf8.encode(password)).toString().toUpperCase();

  /// The 5-char prefix that is the ONLY thing sent over the network.
  static String prefixOf(String password) => sha1Hex(password).substring(0, 5);

  /// Times [password] appears in known breaches (0 = not found).
  Future<int> breachCount(String password) async {
    if (password.isEmpty) return 0;
    final digest = sha1Hex(password);
    final prefix = digest.substring(0, 5);
    final suffix = digest.substring(5);
    final http.Response res;
    try {
      res = await _client
          .get(
            Uri.parse('$endpoint$prefix'),
            headers: const {'Add-Padding': 'true'},
          )
          .timeout(timeout);
    } on Object {
      throw const BreachCheckException('Could not reach the breach service');
    }
    if (res.statusCode != 200) {
      throw BreachCheckException('Breach service error ${res.statusCode}');
    }
    return countInRange(res.body, suffix);
  }

  /// Finds [suffix] in a range response (`SUFFIX:COUNT` lines).
  static int countInRange(String body, String suffix) {
    for (final line in const LineSplitter().convert(body)) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      if (line.substring(0, colon).trim().toUpperCase() == suffix) {
        return int.tryParse(line.substring(colon + 1).trim()) ?? 0;
      }
    }
    return 0;
  }

  void close() => _client.close();
}
