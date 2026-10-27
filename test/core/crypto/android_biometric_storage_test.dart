/// The Android biometric key copy (native BiometricVault over a channel):
/// what the Dart side turns each native answer into, and that nothing can
/// leave a call unanswered or throw anything but BiometricReadException.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/crypto/vault_secret_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(AndroidBiometricVaultStorage.channelName);
  final calls = <MethodCall>[];

  void native(Future<Object?> Function(MethodCall call) handler) {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call);
          return handler(call);
        });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  final storage = AndroidBiometricVaultStorage();

  test(
    'reads the secret after the prompt and sends the prompt texts',
    () async {
      native((_) async => 'c2VjcmV0');
      expect(await storage.read('vault.bio.dek'), 'c2VjcmV0');
      final args = calls.single.arguments as Map;
      expect(calls.single.method, 'read');
      expect(args['key'], 'vault.bio.dek');
      expect(args['title'], isNotEmpty);
      expect(args['negative'], isNotEmpty);
    },
  );

  test('no copy / invalidated copy reads as null (not an error)', () async {
    native((_) async => null);
    expect(await storage.read('k'), isNull);
  });

  for (final code in ['cancelled', 'busy', 'unavailable', 'error']) {
    test('native "$code" is a BiometricReadException on read and write', () {
      native((_) async => throw PlatformException(code: code));
      expect(storage.read('k'), throwsA(isA<BiometricReadException>()));
      expect(storage.write('k', 'v'), throwsA(isA<BiometricReadException>()));
    });
  }

  test('write succeeds only on a true answer', () async {
    native((_) async => true);
    await storage.write('k', 'v');
    expect((calls.single.arguments as Map)['value'], 'v');

    native((_) async => false);
    expect(storage.write('k', 'v'), throwsA(isA<BiometricReadException>()));
    native((_) async => null);
    expect(storage.write('k', 'v'), throwsA(isA<BiometricReadException>()));
  });

  test('a missing native side is a cancelled read, never another error', () {
    // No handler registered at all.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    expect(storage.read('k'), throwsA(isA<BiometricReadException>()));
  });

  test('delete never prompts and never throws', () async {
    native((_) async => throw PlatformException(code: 'error'));
    await storage.delete('k');
    expect(calls.single.method, 'delete');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await storage.delete('k');
  });

  testWidgets('a prompt that never answers is cancelled at the ceiling', (
    tester,
  ) async {
    native(
      (c) => c.method == 'read' ? Completer<Object?>().future : Future.value(),
    );
    Object? error;
    storage.read('k').then<void>((_) {}, onError: (Object e) => error = e);
    await tester.pump(
      AndroidBiometricVaultStorage.ceiling - const Duration(seconds: 1),
    );
    expect(error, isNull);
    await tester.pump(const Duration(seconds: 2));
    expect(error, isA<BiometricReadException>());
    expect(calls.map((c) => c.method), contains('cancel'));
  });
}
