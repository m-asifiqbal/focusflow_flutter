/// Leaving the vault must not clear the app-wide privacy flag: on Android
/// "screenshot off" and "Hide content in app switcher" are both FLAG_SECURE.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/vault/data/datasource/screen_protection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('screen_protector');
  final calls = <String>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (c) async {
          calls.add(c.method);
          return true;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('Android keeps FLAG_SECURE when the app-level privacy is on', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var hide = true;
    final p = PluginScreenProtection(keepWindowSecure: () => hide);
    await p.enable();
    await p.disable();
    expect(calls, ['preventScreenshotOn']);

    hide = false;
    calls.clear();
    await p.disable();
    expect(calls, ['preventScreenshotOff']);
  });

  test('iOS always removes the vault layers', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final p = PluginScreenProtection(keepWindowSecure: () => true);
    await p.disable();
    expect(calls, ['preventScreenshotOff', 'protectDataLeakageWithBlurOff']);
  });
}
