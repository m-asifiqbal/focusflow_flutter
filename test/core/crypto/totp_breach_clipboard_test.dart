/// TOTP (RFC 6238 vectors, otpauth URIs), the HIBP k-anonymity check
/// (only the 5-char SHA-1 prefix leaves the device) and SecureClipboard.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/crypto/breach_check.dart';
import 'package:focusflow/core/crypto/crypto_bytes.dart';
import 'package:focusflow/core/crypto/secure_clipboard.dart';
import 'package:focusflow/core/crypto/totp.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('TOTP', () {
    String b32(String ascii) => CryptoBytes.toBase32(utf8.encode(ascii));
    DateTime at(int seconds) =>
        DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

    test('RFC 6238 test vectors (8 digits)', () {
      final sha1 = TotpConfig(secret: b32('12345678901234567890'), digits: 8);
      final sha256 = TotpConfig(
        secret: b32('12345678901234567890123456789012'),
        digits: 8,
        algorithm: TotpAlgorithm.sha256,
      );
      final sha512 = TotpConfig(
        secret: b32(
          '1234567890123456789012345678901234567890123456789012345678901234',
        ),
        digits: 8,
        algorithm: TotpAlgorithm.sha512,
      );
      expect(sha1.codeAt(at(59)), '94287082');
      expect(sha1.codeAt(at(1111111109)), '07081804');
      expect(sha1.codeAt(at(20000000000)), '65353130');
      expect(sha256.codeAt(at(59)), '46119246');
      expect(sha512.codeAt(at(59)), '90693936');
    });

    test('6-digit default and seconds remaining', () {
      final c = TotpConfig.parse('GEZD GNBV GY3T QOJQ GEZD GNBV GY3T QOJQ')!;
      expect(c.codeAt(at(59)), '287082');
      expect(c.secondsRemaining(at(59)), 1);
      expect(c.secondsRemaining(at(60)), 30);
      expect(TotpConfig.format('287082'), '287 082');
      expect(c.toString(), isNot(contains(c.secret)));
    });

    test('otpauth URIs', () {
      final c = TotpConfig.parse(
        'otpauth://totp/GitHub:ada%40example.com?secret=JBSWY3DPEHPK3PXP'
        '&issuer=GitHub&digits=8&period=60&algorithm=SHA256',
      )!;
      expect(c.secret, 'JBSWY3DPEHPK3PXP');
      expect(c.issuer, 'GitHub');
      expect(c.account, 'ada@example.com');
      expect(c.digits, 8);
      expect(c.period, 60);
      expect(c.algorithm, TotpAlgorithm.sha256);
      expect(
        TotpConfig.parse('otpauth://hotp/x?secret=JBSWY3DPEHPK3PXP'),
        isNull,
      );
    });

    test('rejects non-base32 and too-short secrets', () {
      expect(TotpConfig.parse(''), isNull);
      expect(TotpConfig.parse('not a secret!'), isNull);
      expect(TotpConfig.parse('JBSWY3DP'), isNull);
      expect(
        TotpConfig.normaliseSecret('jbsw y3dp ehpk 3pxp'),
        'JBSWY3DPEHPK3PXP',
      );
    });
  });

  group('BreachChecker', () {
    // SHA-1("password") = 5BAA6 1E4C9B93F3F0682250B6CF8331B7EE68FD8
    test(
      'sends only the 5-char prefix and matches the suffix locally',
      () async {
        final requests = <http.Request>[];
        final checker = BreachChecker(
          client: MockClient((req) async {
            requests.add(req);
            return http.Response(
              '0018A45C4D1DEF81644B54AB7F969B88D65:1\r\n'
              '1E4C9B93F3F0682250B6CF8331B7EE68FD8:9659365\r\n'
              '011053FD0102E94D6AE2F8B83D76FAF94F6:0\r\n',
              200,
            );
          }),
        );
        expect(BreachChecker.prefixOf('password'), '5BAA6');
        expect(await checker.breachCount('password'), 9659365);
        final req = requests.single;
        expect(
          req.url.toString(),
          'https://api.pwnedpasswords.com/range/5BAA6',
        );
        expect(req.headers['Add-Padding'], 'true');
        expect(req.body, isEmpty);
        expect(req.url.toString(), isNot(contains('1E4C9B93')));
      },
    );

    test('not found → 0; errors throw instead of claiming "safe"', () async {
      final ok = BreachChecker(
        client: MockClient((_) async => http.Response('ABC:2\n', 200)),
      );
      expect(await ok.breachCount('correct horse battery staple'), 0);
      expect(await ok.breachCount(''), 0);

      final down = BreachChecker(
        client: MockClient((_) async => http.Response('', 503)),
      );
      await expectLater(
        down.breachCount('x'),
        throwsA(isA<BreachCheckException>()),
      );
      final offline = BreachChecker(
        client: MockClient((_) async => throw const SocketLikeError()),
      );
      await expectLater(
        offline.breachCount('x'),
        throwsA(isA<BreachCheckException>()),
      );
    });
  });

  group('SecureClipboard', () {
    testWidgets('clears after the delay; a newer copy restarts it', (
      tester,
    ) async {
      final writes = <String>[];
      final clip = SecureClipboard(writer: (t) async => writes.add(t));
      await clip.copy('s3cret', clearAfter: const Duration(seconds: 30));
      expect(clip.hasPendingClear, isTrue);
      await tester.pump(const Duration(seconds: 20));
      await clip.copy('other', clearAfter: const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 20));
      expect(writes, ['s3cret', 'other']);
      await tester.pump(const Duration(seconds: 11));
      expect(writes, ['s3cret', 'other', '']);
      expect(clip.hasPendingClear, isFalse);
    });

    testWidgets('clearNow only clears a pending secret; 0 = never', (
      tester,
    ) async {
      final writes = <String>[];
      final clip = SecureClipboard(writer: (t) async => writes.add(t));
      await clip.copy('a', clearAfter: Duration.zero);
      await clip.clearNow();
      expect(writes, ['a']);
      await clip.copy('b', clearAfter: const Duration(seconds: 5));
      await clip.clearNow();
      expect(writes, ['a', 'b', '']);
      await tester.pump(const Duration(seconds: 10));
      expect(writes, ['a', 'b', '']);
    });

    test('clearIfExpired clears only once the deadline has passed', () async {
      final writes = <String>[];
      var now = DateTime(2026, 6, 13, 9);
      final clip = SecureClipboard(
        writer: (t) async => writes.add(t),
        now: () => now,
      );
      await clip.copy('pw', clearAfter: const Duration(seconds: 30));
      await clip.clearIfExpired();
      expect(writes, ['pw']);
      now = now.add(const Duration(seconds: 31));
      await clip.clearIfExpired();
      expect(writes, ['pw', '']);
      expect(clip.clearDeadline, isNull);
      await clip.clearIfExpired();
      expect(writes, ['pw', '']);
      clip.dispose();
    });
  });
}

class SocketLikeError implements Exception {
  const SocketLikeError();
}
